# backlog CLI Reference

`backlog` is a terminal task board. Without a subcommand it launches the TUI; all subcommands below work non-interactively and are safe to call from scripts or other agents.

## Setup

```bash
backlog init        # create a .backlog/ directory in the current working directory
backlog             # open the TUI (requires .backlog/ to exist in cwd or any ancestor)
```

## Columns

Tasks live in one of three columns: `backlog`, `wip`, `done`.

## Commands

### create

Create a new task.

```
backlog create --title TITLE [--row COLUMN] [--description TEXT] [-v]
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--title` | `-t` | required | Task title |
| `--row` | `-r` | `backlog` | Starting column (`backlog\|wip\|done`) |
| `--description` | `-d` | `""` | Task description |
| `--verbose` | `-v` | off | Print the generated slug on success |

```bash
backlog create --title "Fix login bug" --row wip -v
backlog create -t "Write docs" -d "Cover the CLI flags" -r backlog
```

### move

Move a task to another column.

```
backlog move TASK --to COLUMN [-v]
```

`TASK` is the task slug or title (matched by slug first, then by `toSlug(title)`).

```bash
backlog move fix-login-bug --to done
backlog move "Fix login bug" --to done -v
```

### update

Edit a task's title, description, or both.

```
backlog update TASK [--title TITLE] [--description TEXT] [-v]
```

At least one of `--title` or `--description` must be provided.

```bash
backlog update fix-login-bug --title "Fix OAuth login bug"
backlog update fix-login-bug --description "Affects Google SSO only"
backlog update fix-login-bug -t "Fix OAuth login bug" -d "Affects Google SSO only" -v
```

### delete

Delete a task. Prompts for confirmation unless `-y` is passed.

```
backlog delete TASK [-y] [-v]
```

```bash
backlog delete fix-login-bug          # prompts "Delete '...'? [y/N]"
backlog delete fix-login-bug -y       # skip prompt (safe for scripts)
backlog delete fix-login-bug -y -v    # skip prompt, print confirmation
```

## Task identity

Tasks are identified by their **slug** — a kebab-case string derived from the title at creation time (e.g. `"Fix login bug"` → `fix-login-bug`). Slugs are stable: renaming a task via `update --title` does not change its slug. All commands that take a `TASK` argument accept either the slug or the original title (the title is converted to slug form for matching).

## Exit codes

All commands exit `0` on success and `1` on error (missing `.backlog/`, task not found, missing required flags). Errors are printed to stderr.

## On-disk format

Each task is a Markdown file at `.backlog/{backlog,wip,done}/<slug>.md`. The H1 heading is the title; everything after it is the description. Editing these files directly is safe.
