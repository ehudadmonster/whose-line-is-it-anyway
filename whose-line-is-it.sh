#!/usr/bin/env bash

# --- Configurable defaults (used if you just press Enter at the prompts) ---
DEFAULT_TEAMS="Engineers,Algos"
DEFAULT_ALLOWED_PATHS="src/,lib/,tests/"
DEFAULT_EXCLUDED_PATHS="build/,dist/,tmp/"

# --- Line selection options ---
SKIP_BLANK_LINES=true
SKIP_COMMENT_ONLY_LINES=true   # set to false if you only want to skip blanks

# --- Read user customizations once at start ---
read -p "Enter team names (comma-separated) [${DEFAULT_TEAMS}]: " TEAMS_INPUT
read -p "Enter allowed paths (comma-separated) [${DEFAULT_ALLOWED_PATHS}]: " ALLOWED_INPUT
read -p "Enter EXCLUDED paths (comma-separated) [${DEFAULT_EXCLUDED_PATHS}]: " EXCLUDED_INPUT

IFS=',' read -r -a TEAMS <<< "${TEAMS_INPUT:-$DEFAULT_TEAMS}"
IFS=',' read -r -a ALLOWED_PATHS <<< "${ALLOWED_INPUT:-$DEFAULT_ALLOWED_PATHS}"
IFS=',' read -r -a EXCLUDED_PATHS <<< "${EXCLUDED_INPUT:-$DEFAULT_EXCLUDED_PATHS}"

# Scores array sized to number of teams
declare -a SCORES
for ((i=0; i<${#TEAMS[@]}; i++)); do
  SCORES[$i]=0
done

# --- Helpers ---
color_red="\033[1;31m"
color_yellow="\033[1;33m"
color_cyan="\033[1;36m"
color_reset="\033[0m"

format_epoch() {
  # Prints YYYY-MM-DD from epoch, works on GNU (Linux) and BSD/macOS
  if date -d @0 >/dev/null 2>&1; then
    date -d "@$1" "+%Y-%m-%d"
  else
    date -r "$1" "+%Y-%m-%d"
  fi
}

is_in_allowed_paths() {
  local f="$1"
  for p in "${ALLOWED_PATHS[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}" # trim
    [[ -z "$p" ]] && continue
    [[ "$f" == "$p"* ]] && return 0
  done
  return 1
}

is_in_excluded_paths() {
  local f="$1"
  for p in "${EXCLUDED_PATHS[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}" # trim
    [[ -z "$p" ]] && continue
    [[ "$f" == "$p"* ]] && return 0
  done
  return 1
}

is_text_blob() {
  # Return 0 (true) if the file content at commit looks like text
  # We sample some bytes for speed; -I makes grep think binary if NULs found
  if git show "$1":"$2" 2>/dev/null | head -c 32768 | LC_ALL=C grep -Iq .; then
    return 0
  else
    return 1
  fi
}

print_scores() {
  echo -e "${color_cyan}Scores:${color_reset}"
  for ((i=0; i<${#TEAMS[@]}; i++)); do
    echo "  ${TEAMS[$i]}: ${SCORES[$i]}"
  done
}

prompt_winner() {
  local choice teams_csv shown_header=0
  teams_csv=$(IFS=,; echo "${TEAMS[*]}")

  while true; do
    if [[ $shown_header -eq 0 ]]; then
      echo "Who guessed correctly? ${teams_csv} ?"
      echo "(type exact team name; Enter for no one)"
      shown_header=1
    fi

    read -p "> " -r choice

    # No winner
    if [[ -z "$choice" ]]; then
      return
    fi

    # Exact match against team list
    for ((i=0; i<${#TEAMS[@]}; i++)); do
      if [[ "$choice" == "${TEAMS[$i]}" ]]; then
        SCORES[$i]=$(( SCORES[$i] + 1 ))
        return
      fi
    done

    # Invalid input → re-prompt (keep the simple '> ' line)
    echo "Invalid team. Valid options: ${teams_csv}"
  done
}


# Build a list-filter for eligible (non-empty / non-comment) lines
build_line_filter() {
  local file="$1"
  local ext="${file##*.}"
  local comment_regex="^$"  # default to no-op unless toggled

  if [[ "$SKIP_COMMENT_ONLY_LINES" == "true" ]]; then
    case "$ext" in
      py|rb|sh|bash|tf|yaml|yml|toml|ini|cfg|rs|make|mk|dockerfile|env|bzl|bazel|BUILD|WORKSPACE)
        comment_regex='^[[:space:]]*#'
        ;;
      js|ts|tsx|jsx|c|cc|cpp|h|hpp|java|kt|go|swift|scala|php|css|scss|less)
        # rudimentary: skip // lines and lines that start/are a */ token
        comment_regex='^[[:space:]]*//|^[[:space:]]*/\*|^[[:space:]]*\*\/[[:space:]]*$'
        ;;
      *)
        comment_regex='^$'
        ;;
    esac
  fi

  if [[ "$SKIP_BLANK_LINES" == "true" ]]; then
    base_blanks='^[[:space:]]*$'
    if [[ "$SKIP_COMMENT_ONLY_LINES" == "true" ]]; then
      grep -n -Ev "$base_blanks|$comment_regex"
    else
      grep -n -Ev "$base_blanks"
    fi
  else
    if [[ "$SKIP_COMMENT_ONLY_LINES" == "true" ]]; then
      grep -n -Ev "$comment_regex"
    else
      # No filtering
      nl -ba -w1 -s:  # add line numbers in "N:content" style to keep interface consistent
    fi
  fi
}

# --- Game loop ---
while true; do
  latest_commit=$(git rev-parse HEAD 2>/dev/null) || { echo "Not a git repo here."; exit 1; }

  # List files from latest commit
  mapfile -t FILES < <(git ls-tree -r --name-only "$latest_commit")

  [[ ${#FILES[@]} -eq 0 ]] && { echo "No files found in the repo."; exit 1; }

  # Pick a random file that passes allowed/excluded rules
  random_file=""
  for _ in {1..1000}; do
    count=${#FILES[@]}
    idx=$(( RANDOM % count ))   # 0..count-1
    candidate="${FILES[$idx]}"

    is_in_allowed_paths "$candidate" || continue
    is_in_excluded_paths "$candidate" && continue
    is_text_blob "$latest_commit" "$candidate" || continue

    random_file="$candidate"
    break
  done

  if [[ -z "$random_file" ]]; then
    echo "Couldn't find a file matching the allowed/excluded rules. Adjust your filters."
    break
  fi

  # How many lines?
  total_lines=$(git show "$latest_commit":"$random_file" | wc -l | tr -d ' ')
  if [[ "$total_lines" -le 0 ]]; then
    continue
  fi

  # Build eligible line numbers (skip blanks/comments per toggles)
  mapfile -t ELIGIBLE_LINES < <(
    git show "$latest_commit":"$random_file" \
      | build_line_filter "$random_file" \
      | cut -d: -f1
  )

  # If no eligible lines (e.g., file is all blanks/comments), try next loop
  if [[ ${#ELIGIBLE_LINES[@]} -eq 0 ]]; then
    continue
  fi

  # Choose random eligible line
  random_line="${ELIGIBLE_LINES[$(( RANDOM % ${#ELIGIBLE_LINES[@]} ))]}"

  # Clamp context window
  ctx_before=2
  ctx_after=2
  start=$(( random_line - ctx_before ))
  end=$(( random_line + ctx_after ))
  (( start < 1 )) && start=1
  (( end > total_lines )) && end=$total_lines

  # Show excerpt with highlighted target line
  echo -e "\n${color_yellow}Mystery file${color_reset}  ${color_yellow}Line:${color_reset} $random_line\n"
  git show "$latest_commit":"$random_file" | nl -ba -w1 -s' ' | sed -n "${start},${end}p" | awk -v tgt="$random_line" -v R="$color_red" -v Z="$color_reset" '
    {
      line_num=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/,"");
      if (line_num==tgt) {
        print R ">" line_num " | " $0 Z
      } else {
        print " " line_num " | " $0
      }
    }
  '
  

# Pre-compute blame (so we can use the date in the hint and the author in the answer)
blame_info=$(git blame --line-porcelain -L ${random_line},${random_line} "$latest_commit" -- "$random_file")
author=$(awk -F'author ' '/^author /{print $2; exit}' <<< "$blame_info")
epoch=$(awk -F'author-time ' '/^author-time /{print $2; exit}' <<< "$blame_info")
the_date=$(format_epoch "$epoch")

# Ask about hint (keep file hidden until we actually show the hint)
read -p $'\nNeed a hint (yes/no)? ' choice
case "$choice" in
  [Yy]|[Yy][Ee][Ss])
    # Pause BEFORE hint (thinking time)
    read -p "Press Enter to see the hint..."

    # Colored hint: file path + date only (no commit id, no context lines)
    echo -e "\n${color_yellow}Hint:${color_reset}"
    echo "File path: $random_file"
    echo "Date: $the_date"

    # Now give them time to think, then reveal the answer
    echo
    echo "Okay, think about it..."
    read -p "Press Enter to reveal the answer..."

    echo -e "\n${color_cyan}Answer:${color_reset} ${author} — ${the_date}\n"
    ;;

  [Nn]|[Nn][Oo])
    echo "No hint requested."
    echo -e "\n${color_cyan}Answer:${color_reset} ${author} — ${the_date}"
    ;;

  *)
    echo "Got it."
    echo -e "\n${color_cyan}Answer:${color_reset} ${author} — ${the_date}\n"
    ;;
esac



  # Record round outcome
  prompt_winner

  # Show current scores
  echo
  print_scores
  echo

  # Continue?
  read -p "Press Enter to continue or type 'exit' to exit: " cont
  [[ "$cont" == "exit" ]] && break
done

echo -e "\n${color_cyan}Final${color_reset}"
print_scores

