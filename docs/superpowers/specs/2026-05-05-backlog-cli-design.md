# backlog CLI — Design Spec

**Date:** 2026-05-05
**Language:** Haskell
**TUI library:** brick

---

## Overview

A terminal Kanban board for tracking a project's backlog. Tasks live as markdown files inside a `.backlog/` directory, which is meant to be committed alongside the project's git repository. The tool is launched as a TUI; all task management happens inside it.

---

## Directory Structure

The `.backlog/` directory lives at the project root. It contains one subdirectory per column:

```
.backlog/
  backlog/
  wip/
  done/
```

Each task is a single `.md` file inside the appropriate column directory. Moving a task between columns moves the file.

---

## File Format

Each task file follows this format:

```markdown
# Task title

Optional description in plain markdown.
```

- The **H1 heading** is the task title.
- Everything after the heading is the description (optional).
- The **filename** is a slug derived from the title at creation time (e.g. `add-authentication.md`) and is never updated afterwards — renaming a task only changes the H1, producing a clean one-line diff.
- On slug collision, append `-2`, `-3`, etc.
- Creation date is not stored in the file; git history is the source of truth for that.

---

## CLI Interface

```
backlog init    Create .backlog/ with empty backlog/, wip/, done/ subdirs in CWD.
                Errors if .backlog/ already exists.

backlog         Launch the TUI. Walks up from CWD to find .backlog/ (same
                discovery behaviour as git). If not found, exits with:
                "no backlog found in this directory or any parent
                 (run 'backlog init' to create one)"
```

No other subcommands. All task operations happen inside the TUI.

---

## TUI Design

### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  backlog  ~/projects/myapp/.backlog                    [?] help │
├───────────────────┬───────────────────┬─────────────────────────┤
│     BACKLOG       │       WIP         │         DONE            │
│                   │                   │                         │
│  ▶ Add auth       │  ● Fix login bug  │  ✓ Setup CI             │
│    Write tests    │                   │  ✓ Init repo            │
│    API docs       │                   │                         │
├───────────────────┴───────────────────┴─────────────────────────┤
│  [n] new  [shift+←/→] move  [enter] open  [d] delete  [q] quit │
└─────────────────────────────────────────────────────────────────┘
```

The status bar at the bottom updates to reflect the keys available in the current context (board, detail panel, or popup).

### Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move between tasks in the current column |
| `←` / `→` | Move focus between columns |
| `enter` | Open detail panel for the selected task |
| `q` | Quit |

### Actions

| Key | Action |
|-----|--------|
| `n` | Open new-task popup; type title, confirm with `enter`, cancel with `esc` |
| `e` | Edit title (on board) or description (in detail panel) |
| `shift+←` / `shift+→` | Move selected task to previous/next column |
| `d` | Delete selected task; shows confirmation prompt before acting |

### Detail Panel

Overlays the board. Shows the full title and description. `e` opens the description for editing, `esc` returns to the board.

---

## Architecture

### Module Layout

```
src/
  Main.hs                 -- entry point, CLI argument dispatch
  Backlog/
    Types.hs              -- Task, Board, Column, AppState
    Discovery.hs          -- walk-up .backlog/ finder
    FileIO.hs             -- read/write/move/delete task files
    Slug.hs               -- title → slug, collision handling
    TUI.hs                -- Brick app wiring, event loop
    Widgets/
      Board.hs            -- three-column layout widget
      TaskDetail.hs       -- detail overlay panel widget
      NewTask.hs          -- new task title input popup widget
      Confirm.hs          -- delete confirmation dialog widget
```

### Key Types

```haskell
data Column = Backlog | WIP | Done

data Task = Task
  { taskSlug        :: Text   -- filename without .md, immutable
  , taskTitle       :: Text   -- H1 content
  , taskDescription :: Text   -- everything after the H1
  , taskColumn      :: Column
  }

type Board = Map Column [Task]

data AppState = AppState
  { board           :: Board
  , focusedColumn   :: Column
  , selectedIndex   :: Int
  , activeWidget    :: ActiveWidget  -- Board | Detail | NewTask | Confirm
  , backlogRoot     :: FilePath      -- path to .backlog/
  }
```

### File I/O Strategy

- On startup: scan all three column directories, parse each `.md` file into a `Task`.
- All mutations (create, rename, move, delete) are written to disk immediately — no in-memory buffering.
- Moving a task between columns = `renameFile` from one column dir to another.
- Errors (permission denied, missing file) surface as a status bar message; the app does not crash.

### Dependencies

| Package | Purpose |
|---------|---------|
| `brick` | TUI framework |
| `vty` | Terminal backend for brick |
| `directory` | File and directory I/O |
| `filepath` | Path manipulation |
| `text` | Text type |
| `containers` | `Map` for board state |
