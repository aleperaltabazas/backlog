# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
stack build               # build library + executable
stack test                # run all tests
stack test --ta '--match "/Slug/"'  # run tests matching a pattern (hspec)
stack run backlog         # run the TUI (requires a .backlog/ dir to exist)
stack run backlog -- init # initialise a new .backlog/ in CWD
```

The executable requires `-threaded` (already set in `package.yaml`) because Brick/vty needs the GHC threaded runtime.

## Architecture

The project is a Haskell TUI (Brick library) with a clean separation between IO, pure logic, and rendering.

**Data flow at startup:** `Main` → `Discovery.findBacklogRoot` (walk-up search for `.backlog/`) → `FileIO.loadBoard` (parse all `.md` files) → `TUI.runTUI` (hand off to Brick event loop).

**On-disk format:** Each task is a `.md` file inside `.backlog/{backlog,wip,done}/`. The H1 heading is the title; everything after it is the description. The filename (without `.md`) is the slug — derived from the title at creation and never updated again, so renaming a task only produces a one-line diff.

**Key types** (`Types.hs`):
- `Task` — slug, title, description, column. Slug is the stable identity.
- `Board = Map Column [Task]` — the raw loaded board; converted to `Map Column (BL.List ResourceName Task)` inside `AppState` for Brick.
- `ResourceName` — must be globally unique across all Brick widgets. All variants live here: `TaskListName Column`, `NewTaskEditorName`, `EditEditorName`.
- `ActiveWidget` — the current modal state (`BoardWidget | DetailWidget | NewTaskWidget | EditWidget | ConfirmWidget`). `TUI.hs` dispatches events based on this.

**TUI module layout:**
- `TUI.hs` — `AppState`, event routing, all `handle*Event` functions, and small helpers (`pickFocus`, `handleListNav`, `shiftTask`).
- `Widgets/Board.hs` — three-column layout; `renderTask` receives `colFocused` and `selected` booleans — the cursor (`> `) only renders when both are true.
- `Widgets/TaskDetail.hs`, `NewTask.hs`, `Confirm.hs` — overlay widgets; rendered as layers on top of the board.

**Brick patterns used:**
- Editor events: `nestEventM' editor (E.handleEditorEvent ev)` — not `zoom`.
- List navigation: `nestEventM' list (BL.handleListEvent vtye)` — not `BL.listMoveUp/Down`.
- All mutations (create, edit title, edit description, move column, delete) are written to disk immediately via `FileIO`; there is no buffered state.
