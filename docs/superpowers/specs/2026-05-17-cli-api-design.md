# CLI API Design

## Overview

Add four subcommands to the `backlog` executable for automation use cases: `create`, `move`, `delete`, and `update`. The TUI (`Launch`) remains the default when no subcommand is given. All commands are silent on success by default; each exposes `-v/--verbose` for a one-line confirmation. Errors go to stderr with a non-zero exit code.

## Module Structure

- `app/Main.hs` — extends `Command` with four new variants, adds their `optparse-applicative` parsers, dispatches to `Backlog.CLI`
- `src/Backlog/CLI.hs` — new module; contains `findTask`, one handler per command, and a shared `Column` `ReadM` parser
- `src/Backlog/FileIO.hs` — no changes required

## Command Definitions

### `create`

```
backlog create -t TITLE [-r ROW] [-d DESCRIPTION] [-v]
```

- `-t / --title` — required
- `-r / --row` — `backlog|wip|done`, default `backlog`
- `-d / --description` — optional, default empty string
- `-v / --verbose` — print `"Created task '<slug>'"` on success

Slug is derived via `Slug.toSlug title` and made unique with `Slug.makeUniqueSlug` against existing slugs across all columns.

### `move`

```
backlog move TASK --to DESTINATION [-v]
```

- `TASK` — positional; matched by slug or by `toSlug` of the input (title-style)
- `--to` — `backlog|wip|done`, required
- `-v / --verbose` — print `"Moved '<slug>' to <destination>"` on success

### `delete`

```
backlog delete TASK [-y] [-v]
```

- `TASK` — positional; matched by slug or title
- `-y / --yes` — skip confirmation prompt
- Without `--yes`: prompts `"Delete '<slug>'? [y/N] "` on stdout; aborts unless answer is `y` or `Y`
- `-v / --verbose` — print `"Deleted '<slug>'"` on success (printed after confirmation if applicable)

### `update`

```
backlog update TASK [-t TITLE] [-d DESCRIPTION] [-v]
```

- `TASK` — positional; matched by slug or title
- `-t / --title` — optional
- `-d / --description` — optional
- At least one of `--title` or `--description` must be provided (validated at runtime)
- `-v / --verbose` — print `"Updated '<slug>'"` on success

## Command Type

```haskell
data Command
  = Launch
  | Init
  | Create { title :: Text, row :: Column, description :: Text, verbose :: Bool }
  | Move   { task :: Text, destination :: Column, verbose :: Bool }
  | Delete { task :: Text, yes :: Bool, verbose :: Bool }
  | Update { task :: Text, title :: Maybe Text, description :: Maybe Text, verbose :: Bool }
```

Field names are shared across constructors; partial field accessor warnings are accepted.

## Task Lookup

```haskell
findTask :: Board -> Text -> Maybe Task
findTask board input =
  listToMaybe [ t | col <- [minBound..maxBound]
                  , t   <- Map.findWithDefault [] col board
                  , taskSlug t == input || taskSlug t == toSlug input ]
```

Searches `Backlog → WIP → Done`. Returns the first match. No match yields an error.

## Column Parsing

A shared `ReadM Column` parser in `CLI.hs` accepts `"backlog"`, `"wip"`, `"done"` (case-sensitive). Used by both `--row` (create) and `--to` (move).

## Error Handling

All errors print to stderr and exit with a non-zero code via `exitFailure`:

| Situation | Message |
|---|---|
| No `.backlog/` found | `"no backlog found in this directory or any parent"` |
| Task not found | `"task not found: <input>"` |
| `update` with no flags | `"provide at least --title or --description"` |

FileIO failures (permissions, missing dirs) surface as unhandled Haskell exceptions with their default OS error messages.
