# Whose Line Is It Anyway — a git‑blame party game for dev teams

A tiny Bash game you run inside your repo to celebrate the people behind the code. Each round, the game shows a short code snippet from your latest commit and challenges teams to guess **who wrote the highlighted line**. It’s fast, collaborative, and perfect for shipping‑day gatherings or team offsites.

---

## 🎯 Purpose

**Whose Line Is It Anyway** turns your shared codebase into a light‑hearted trivia board. Play it after a big release or at the end of a sprint to:

* Relive moments from recent commits
* Highlight contributions from different corners of the repo
* Laugh together at weird one‑liners, TODOs, and forgotten comments 😄

---

## 🕹️ How it works

At a high level:

1. The script picks a **random text file** from `HEAD` matching your **allowed** and **excluded** path filters.
2. You see a **5‑line excerpt** (2 lines before/after) with the target line highlighted.
3. You can ask for a **Hint** (file path + author date), then lock in guesses.
4. Reveal the **Answer** (author name + date), enter which team scored, and continue.

### Round flow

* **Teams input**: Enter team names (comma‑separated) once at start (default: `Engineers,Algos`).
* **Repo filters**: Optionally limit to certain subfolders (e.g., `src/`) or exclude generated/build paths.
* **Line selection**: By default, the game skips blanks and comment‑only lines so the line is meaningful code/content.
* **Scoring**: After the reveal, type the exact team name to award a point. Live scores print every round.

### What gets picked?

* Only files from the **latest commit** (`HEAD`). Uncommitted changes are ignored (makes results reproducible during a session).
* Non‑text blobs are skipped (a quick binary sniff protects you from weird output).
* Path filters are simple **prefix matches** (e.g., `src/` matches anything under that folder).

---

## 👀 Example snippets

Here’s what a typical round looks like in your terminal:

```text
Mystery file  Line: 137

  135 |   const id = makeId();
  136 |   if (!user) return null;
> 137 |   return renderProfile(user, id);
  138 | }
```

If you request a hint, you’ll see:

```text
Hint:
File path: src/components/Profile.tsx
Date: 2025-06-03
```

Then the reveal:

```text
Answer: Jane Doe — 2025-06-03
```

Scoring prompt & scoreboard:

```text
Who guessed correctly? Engineers,Algos ?
(type exact team name; Enter for no one)
> Engineers

Scores:
  Engineers: 3
  Algos: 2
```

---

## ⚙️ Configuration at a glance

These defaults are prompted on launch (press **Enter** to accept):

* **Teams**: `Engineers,Algos`
* **Allowed paths**: `src/,lib/,tests/`
* **Excluded paths**: `build/,dist/,tmp/`
* **Line filtering**: skips **blank** lines and, by default, **comment‑only** lines

You can include multiple items, comma‑separated. Matching is prefix‑based—`tests/` includes everything under that folder.

Supported comment styles for skipping include `#` languages (py/sh/yml/etc.) and `// …`, `/* … */` for many C/JS‑like files. You can disable skipping comment‑only lines by toggling the `SKIP_COMMENT_ONLY_LINES` flag in the script if you prefer.

---

## 🚀 Setup & running

### Prerequisites

* **Operating system**: macOS or Linux (Bash environment)
* **Tools**: `bash`, `git`, `awk`, `sed`, `nl`, `grep`, `head`, `wc`
* **Repo**: run inside a **git repository** with at least one commit (the game reads from `HEAD`)

> macOS note: the script auto‑detects GNU/BSD `date` differences and formats the author date correctly.

### Where to put the file

* Save the script as, for example, `scripts/whose-line-is-it.sh` **within the repository you want to play**.
* Make it executable:

```bash
chmod +x scripts/whose-line-is-it.sh
```

### Start the game

From your repo root:

```bash
./scripts/whose-line-is-it.sh
```

Follow the prompts:

1. Enter team names (or press Enter for defaults)
2. Enter allowed/excluded paths (or accept defaults)
3. Play rounds, request hints, award points, and continue until you type `exit`.

---

## 🧩 Git environment expectations

* **Must run inside a git repo**: the script exits with `"Not a git repo here."` if not.
* **Reads only `HEAD`**: the game uses `git ls-tree -r --name-only HEAD` and `git show` to pull exact file contents from the latest commit.
* **Authorship & date**: author info is pulled with `git blame -L <line>,<line>` on the selected file, and dates are rendered as `YYYY‑MM‑DD`.
* **Uncommitted changes**: ignored (keeps rounds deterministic for everyone running the same commit).
* **Binary files**: skipped via a quick `grep -Iq` check on sample bytes.
* **Large repos**: the picker retries up to 1000 candidates to find a valid text line that matches your filters.

---

## 🧪 Tips, tweaks & variations

* **More context**: increase `ctx_before/ctx_after` in the script for bigger excerpts.
* **Different filters**: tighten `ALLOWED_PATHS` to a domain‑specific area during themed rounds (e.g., only `infra/`).
* **Comment‑only rounds**: set `SKIP_COMMENT_ONLY_LINES=false` if you want a “docs & comments” edition.
* **Team names with spaces**: fine—enter exactly and then type the **exact** name when awarding points.
* **Color output**: uses standard ANSI escape codes; most terminals support them.

---

## 🧯 Troubleshooting

* **“Not a git repo here.”** — Run the script from inside a repository (where `.git/` exists).
* **“No files found in the repo.”** — Make at least one commit.
* **“Couldn’t find a file matching the allowed/excluded rules.”** — Broaden `ALLOWED_PATHS` or relax `EXCLUDED_PATHS`.
* **All lines filtered** — If a file is mostly boilerplate/comments, it may get filtered out. Disable `SKIP_COMMENT_ONLY_LINES` or adjust paths.

---

## 📄 License & contributions

Use freely within your team. PRs welcome! Add new comment patterns, improve binary detection, or contribute fun round types.

---

## 🙌 Acknowledgements

Built to celebrate team effort and make code ownership a game, not a blame. Have fun! 🎉

