# backlog CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a terminal Kanban board CLI in Haskell that manages tasks as markdown files inside a `.backlog/` directory co-located with a git repo.

**Architecture:** Three-column board (Backlog/WIP/Done) rendered with Brick. Each column is a subdirectory; each task is a `.md` file with an H1 title and optional markdown description. All file mutations happen immediately on disk. The CLI either runs `backlog init` to scaffold the directory or launches the TUI after walking up from CWD to find `.backlog/`.

**Tech Stack:** Haskell, stack, brick >= 2.0, vty, microlens, microlens-mtl, hspec

---

## File Map

| File | Responsibility |
|------|----------------|
| `package.yaml` | Project config and dependencies (hpack) |
| `stack.yaml` | Resolver and package location |
| `app/Main.hs` | Entry point; CLI argument dispatch |
| `src/Backlog/Types.hs` | Core types: `Column`, `Task`, `Board`, `ActiveWidget`, `ResourceName` |
| `src/Backlog/Slug.hs` | Title-to-slug conversion; collision handling |
| `src/Backlog/Discovery.hs` | Walk-up `.backlog/` finder |
| `src/Backlog/FileIO.hs` | Parse, read, write, move, delete task files; `initBacklog` |
| `src/Backlog/TUI.hs` | Brick `App` wiring, `AppState`, `drawUI`, `handleEvent` |
| `src/Backlog/Widgets/Board.hs` | Three-column layout widget |
| `src/Backlog/Widgets/TaskDetail.hs` | Task detail overlay widget |
| `src/Backlog/Widgets/NewTask.hs` | New task title input popup widget |
| `src/Backlog/Widgets/Confirm.hs` | Delete confirmation dialog widget |
| `test/Spec.hs` | Test runner entry point |
| `test/Backlog/SlugSpec.hs` | Tests for `Slug` |
| `test/Backlog/DiscoverySpec.hs` | Tests for `Discovery` |
| `test/Backlog/FileIOSpec.hs` | Tests for `FileIO` parsing and IO operations |

---

### Task 1: Project scaffold

**Files:**
- Create: `package.yaml`
- Create: `stack.yaml`
- Create: `app/Main.hs`
- Create: `src/Backlog/Types.hs`
- Create: `test/Spec.hs`
- Create: `.gitignore`

- [ ] **Step 1: Create `stack.yaml`**

```yaml
resolver: lts-23.17
packages:
  - .
```

- [ ] **Step 2: Create `package.yaml`**

```yaml
name: backlog
version: 0.1.0.0

ghc-options: -Wall

dependencies:
  - base >= 4.7 && < 5

library:
  source-dirs: src
  dependencies:
    - brick >= 2.0
    - vty
    - directory
    - filepath
    - text
    - containers
    - vector
    - microlens
    - microlens-mtl

executables:
  backlog:
    main: Main.hs
    source-dirs: app
    dependencies:
      - backlog

tests:
  backlog-test:
    main: Spec.hs
    source-dirs: test
    dependencies:
      - backlog
      - hspec
      - directory
      - filepath
      - text
      - temporary
```

- [ ] **Step 3: Create stub `app/Main.hs`**

```haskell
module Main where

main :: IO ()
main = putStrLn "backlog"
```

- [ ] **Step 4: Create stub `src/Backlog/Types.hs`**

```haskell
module Backlog.Types where
```

- [ ] **Step 5: Create stub `test/Spec.hs`**

```haskell
module Main where

import Test.Hspec

main :: IO ()
main = hspec $ pure ()
```

- [ ] **Step 6: Create `.gitignore`**

```
.stack-work/
*.o
*.hi
```

- [ ] **Step 7: Verify the project builds**

Run: `stack build`
Expected: exits 0 with no errors

- [ ] **Step 8: Commit**

```bash
git add package.yaml stack.yaml app/Main.hs src/Backlog/Types.hs test/Spec.hs .gitignore
git commit -m "chore: scaffold Haskell project with stack"
```

---

### Task 2: Types module

**Files:**
- Modify: `src/Backlog/Types.hs`

- [ ] **Step 1: Implement `src/Backlog/Types.hs`**

```haskell
module Backlog.Types where

import Data.Map.Strict (Map)
import Data.Text (Text)

data Column = Backlog | WIP | Done
  deriving (Eq, Ord, Show, Enum, Bounded)

data Task = Task
  { taskSlug        :: Text
  , taskTitle       :: Text
  , taskDescription :: Text
  , taskColumn      :: Column
  } deriving (Eq, Show)

type Board = Map Column [Task]

data ActiveWidget
  = BoardWidget
  | DetailWidget
  | NewTaskWidget
  | EditWidget      -- editing an existing task's title (on board) or description (in detail)
  | ConfirmWidget
  deriving (Eq, Show)

data ResourceName
  = TaskListName Column
  | NewTaskEditorName
  deriving (Eq, Ord, Show)

columnName :: Column -> Text
columnName Backlog = "BACKLOG"
columnName WIP     = "WIP"
columnName Done    = "DONE"

columnDirName :: Column -> FilePath
columnDirName Backlog = "backlog"
columnDirName WIP     = "wip"
columnDirName Done    = "done"
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/Types.hs
git commit -m "feat: add core types"
```

---

### Task 3: Slug module

**Files:**
- Create: `src/Backlog/Slug.hs`
- Create: `test/Backlog/SlugSpec.hs`
- Modify: `test/Spec.hs`

- [ ] **Step 1: Write the failing tests — `test/Backlog/SlugSpec.hs`**

```haskell
module Backlog.SlugSpec (spec) where

import Test.Hspec
import Backlog.Slug

spec :: Spec
spec = do
  describe "toSlug" $ do
    it "lowercases and hyphenates words" $
      toSlug "Add authentication" `shouldBe` "add-authentication"
    it "strips non-alphanumeric characters" $
      toSlug "Fix bug (urgent!)" `shouldBe` "fix-bug-urgent"
    it "handles a single word" $
      toSlug "Refactor" `shouldBe` "refactor"

  describe "makeUniqueSlug" $ do
    it "returns the base slug when no collision" $
      makeUniqueSlug [] "add-auth" `shouldBe` "add-auth"
    it "appends -2 on first collision" $
      makeUniqueSlug ["add-auth"] "add-auth" `shouldBe` "add-auth-2"
    it "appends -3 on second collision" $
      makeUniqueSlug ["add-auth", "add-auth-2"] "add-auth" `shouldBe` "add-auth-3"
```

- [ ] **Step 2: Update `test/Spec.hs`**

```haskell
module Main where

import Test.Hspec
import qualified Backlog.SlugSpec

main :: IO ()
main = hspec Backlog.SlugSpec.spec
```

- [ ] **Step 3: Run tests to confirm they fail**

Run: `stack test`
Expected: FAIL with "Variable not in scope: toSlug"

- [ ] **Step 4: Implement `src/Backlog/Slug.hs`**

```haskell
module Backlog.Slug (toSlug, makeUniqueSlug) where

import Data.Char (isAlphaNum, toLower, isSpace)
import Data.Text (Text)
import qualified Data.Text as T

toSlug :: Text -> Text
toSlug = T.intercalate "-"
       . T.words
       . T.map (\c -> if isAlphaNum c then toLower c
                      else if isSpace c then c
                      else ' ')

makeUniqueSlug :: [Text] -> Text -> Text
makeUniqueSlug existing base =
  let candidates = base : map (\n -> base <> "-" <> T.pack (show n)) [2 :: Int ..]
  in head $ filter (`notElem` existing) candidates
```

- [ ] **Step 5: Run tests to confirm they pass**

Run: `stack test`
Expected: all Slug tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/Backlog/Slug.hs test/Backlog/SlugSpec.hs test/Spec.hs
git commit -m "feat: add slug generation with tests"
```

---

### Task 4: Discovery module

**Files:**
- Create: `src/Backlog/Discovery.hs`
- Create: `test/Backlog/DiscoverySpec.hs`
- Modify: `test/Spec.hs`

- [ ] **Step 1: Write the failing tests — `test/Backlog/DiscoverySpec.hs`**

```haskell
module Backlog.DiscoverySpec (spec) where

import Test.Hspec
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))
import System.Directory (createDirectory)
import Backlog.Discovery (findBacklogRootFrom)

spec :: Spec
spec = do
  describe "findBacklogRootFrom" $ do
    it "finds .backlog in the start directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> ".backlog")
        result <- findBacklogRootFrom tmp
        result `shouldBe` Just (tmp </> ".backlog")

    it "finds .backlog in a parent directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> ".backlog")
        createDirectory (tmp </> "src")
        result <- findBacklogRootFrom (tmp </> "src")
        result `shouldBe` Just (tmp </> ".backlog")

    it "returns Nothing when .backlog does not exist" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        result <- findBacklogRootFrom tmp
        result `shouldBe` Nothing
```

- [ ] **Step 2: Update `test/Spec.hs`**

```haskell
module Main where

import Test.Hspec
import qualified Backlog.SlugSpec
import qualified Backlog.DiscoverySpec

main :: IO ()
main = hspec $ do
  Backlog.SlugSpec.spec
  Backlog.DiscoverySpec.spec
```

- [ ] **Step 3: Run tests to confirm they fail**

Run: `stack test`
Expected: FAIL with "Variable not in scope: findBacklogRootFrom"

- [ ] **Step 4: Implement `src/Backlog/Discovery.hs`**

```haskell
module Backlog.Discovery (findBacklogRoot, findBacklogRootFrom) where

import System.Directory (doesDirectoryExist, getCurrentDirectory)
import System.FilePath ((</>), takeDirectory)

findBacklogRoot :: IO (Maybe FilePath)
findBacklogRoot = getCurrentDirectory >>= findBacklogRootFrom

findBacklogRootFrom :: FilePath -> IO (Maybe FilePath)
findBacklogRootFrom start = go start
  where
    go dir = do
      let candidate = dir </> ".backlog"
      exists <- doesDirectoryExist candidate
      if exists
        then return (Just candidate)
        else let parent = takeDirectory dir
             in if parent == dir
                  then return Nothing
                  else go parent
```

- [ ] **Step 5: Run tests to confirm they pass**

Run: `stack test`
Expected: all Discovery tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/Backlog/Discovery.hs test/Backlog/DiscoverySpec.hs test/Spec.hs
git commit -m "feat: add .backlog discovery with tests"
```

---

### Task 5: FileIO — parsing

**Files:**
- Create: `src/Backlog/FileIO.hs`
- Create: `test/Backlog/FileIOSpec.hs`
- Modify: `test/Spec.hs`

- [ ] **Step 1: Write the failing tests — `test/Backlog/FileIOSpec.hs`**

```haskell
module Backlog.FileIOSpec (spec) where

import Test.Hspec
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))
import System.Directory (createDirectory, doesFileExist)
import qualified Data.Map.Strict as Map
import Backlog.Types
import Backlog.FileIO

spec :: Spec
spec = do
  describe "parseTaskFile" $ do
    it "parses the title from the H1 heading" $ do
      let task = parseTaskFile Backlog "add-auth" "# Add authentication\n"
      taskTitle task `shouldBe` "Add authentication"

    it "parses description from content after the blank line" $ do
      let task = parseTaskFile Backlog "add-auth" "# Add authentication\n\nSome description."
      taskDescription task `shouldBe` "Some description."

    it "returns empty description when there is none" $ do
      let task = parseTaskFile Backlog "fix-bug" "# Fix bug\n"
      taskDescription task `shouldBe` ""

    it "sets the slug from the provided argument" $ do
      let task = parseTaskFile WIP "my-slug" "# My task\n"
      taskSlug task `shouldBe` "my-slug"

    it "sets the column from the provided argument" $ do
      let task = parseTaskFile Done "slug" "# Task\n"
      taskColumn task `shouldBe` Done
```

- [ ] **Step 2: Update `test/Spec.hs`**

```haskell
module Main where

import Test.Hspec
import qualified Backlog.SlugSpec
import qualified Backlog.DiscoverySpec
import qualified Backlog.FileIOSpec

main :: IO ()
main = hspec $ do
  Backlog.SlugSpec.spec
  Backlog.DiscoverySpec.spec
  Backlog.FileIOSpec.spec
```

- [ ] **Step 3: Run tests to confirm they fail**

Run: `stack test`
Expected: FAIL with "Variable not in scope: parseTaskFile"

- [ ] **Step 4: Implement parsing in `src/Backlog/FileIO.hs`**

```haskell
module Backlog.FileIO
  ( parseTaskFile
  , serializeTask
  , columnDir
  , loadBoard
  , writeTask
  , deleteTask
  , moveTask
  , initBacklog
  ) where

import Backlog.Types
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory
import System.FilePath
import qualified Data.Map.Strict as Map
import System.IO (hPutStrLn, stderr)
import System.Exit (exitFailure)

columnDir :: FilePath -> Column -> FilePath
columnDir root col = root </> columnDirName col

parseTaskFile :: Column -> Text -> Text -> Task
parseTaskFile col slug content =
  let ls    = T.lines content
      title = case ls of
                (h:_) -> T.strip (T.drop 2 h)
                []    -> slug
      desc  = case ls of
                (_:_:rest) -> T.strip (T.unlines rest)
                _          -> ""
  in Task { taskSlug = slug, taskTitle = title, taskDescription = desc, taskColumn = col }

serializeTask :: Task -> Text
serializeTask task = "# " <> taskTitle task <> "\n\n" <> taskDescription task
```

- [ ] **Step 5: Run tests to confirm they pass**

Run: `stack test`
Expected: all FileIO parsing tests PASS

- [ ] **Step 6: Commit**

```bash
git add src/Backlog/FileIO.hs test/Backlog/FileIOSpec.hs test/Spec.hs
git commit -m "feat: add task file parsing with tests"
```

---

### Task 6: FileIO — IO operations

**Files:**
- Modify: `src/Backlog/FileIO.hs`
- Modify: `test/Backlog/FileIOSpec.hs`

- [ ] **Step 1: Add failing IO tests to `test/Backlog/FileIOSpec.hs`**

Add these `describe` blocks inside `spec`, after the existing `parseTaskFile` block:

```haskell
  describe "loadBoard" $ do
    it "loads tasks from all three column directories" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> "backlog")
        createDirectory (tmp </> "wip")
        createDirectory (tmp </> "done")
        writeFile (tmp </> "backlog" </> "task-one.md") "# Task one\n"
        writeFile (tmp </> "done"    </> "task-two.md") "# Task two\n\nDone."
        board <- loadBoard tmp
        length (board Map.! Backlog) `shouldBe` 1
        length (board Map.! WIP)     `shouldBe` 0
        length (board Map.! Done)    `shouldBe` 1

  describe "writeTask" $ do
    it "creates a file in the correct column directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "Description." Backlog
        writeTask tmp task
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` True)

  describe "moveTask" $ do
    it "moves the file to the new column directory and updates taskColumn" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "" Backlog
        writeTask tmp task
        moved <- moveTask tmp task WIP
        taskColumn moved `shouldBe` WIP
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` False)
        doesFileExist (tmp </> "wip"     </> "my-task.md") >>= (`shouldBe` True)

  describe "deleteTask" $ do
    it "removes the task file from disk" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "" Backlog
        writeTask tmp task
        deleteTask tmp task
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` False)
```

- [ ] **Step 2: Run tests to confirm they fail**

Run: `stack test`
Expected: FAIL with "Variable not in scope: loadBoard"

- [ ] **Step 3: Add IO operations to `src/Backlog/FileIO.hs`**

Append after `serializeTask`:

```haskell
loadBoard :: FilePath -> IO Board
loadBoard root = do
  cols  <- mapM (loadColumn root) [minBound .. maxBound]
  return $ Map.fromList (zip [minBound .. maxBound] cols)

loadColumn :: FilePath -> Column -> IO [Task]
loadColumn root col = do
  let dir = columnDir root col
  entries <- listDirectory dir
  let mdFiles = filter (\f -> takeExtension f == ".md") entries
  mapM (loadTask root col) mdFiles

loadTask :: FilePath -> Column -> FilePath -> IO Task
loadTask root col filename = do
  let slug = T.pack (dropExtension filename)
  content <- TIO.readFile (columnDir root col </> filename)
  return (parseTaskFile col slug content)

writeTask :: FilePath -> Task -> IO ()
writeTask root task =
  TIO.writeFile
    (columnDir root (taskColumn task) </> T.unpack (taskSlug task) <> ".md")
    (serializeTask task)

deleteTask :: FilePath -> Task -> IO ()
deleteTask root task =
  removeFile (columnDir root (taskColumn task) </> T.unpack (taskSlug task) <> ".md")

moveTask :: FilePath -> Task -> Column -> IO Task
moveTask root task newCol = do
  let oldPath = columnDir root (taskColumn task) </> T.unpack (taskSlug task) <> ".md"
      newPath = columnDir root newCol            </> T.unpack (taskSlug task) <> ".md"
  renameFile oldPath newPath
  return task { taskColumn = newCol }

initBacklog :: IO ()
initBacklog = do
  cwd <- getCurrentDirectory
  let root = cwd </> ".backlog"
  exists <- doesDirectoryExist root
  if exists
    then hPutStrLn stderr ".backlog already exists in this directory" >> exitFailure
    else do
      createDirectory root
      mapM_ (createDirectory . columnDir root) [minBound .. maxBound]
      putStrLn ("Initialized empty backlog in " <> root)
```

- [ ] **Step 4: Run tests to confirm they pass**

Run: `stack test`
Expected: all FileIO tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/Backlog/FileIO.hs test/Backlog/FileIOSpec.hs
git commit -m "feat: add FileIO IO operations with tests"
```

---

### Task 7: CLI skeleton

**Files:**
- Modify: `app/Main.hs`

- [ ] **Step 1: Implement argument dispatch in `app/Main.hs`**

```haskell
module Main where

import Backlog.Discovery (findBacklogRoot)
import Backlog.FileIO (loadBoard, initBacklog)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["init"] -> initBacklog
    []       -> launchTUI
    _        -> hPutStrLn stderr "Usage: backlog [init]" >> exitFailure

launchTUI :: IO ()
launchTUI = do
  mRoot <- findBacklogRoot
  case mRoot of
    Nothing   -> do
      hPutStrLn stderr
        "no backlog found in this directory or any parent (run 'backlog init' to create one)"
      exitFailure
    Just root -> do
      _board <- loadBoard root
      putStrLn ("Found backlog at: " <> root)   -- placeholder until TUI is wired
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Manual test — init**

```bash
cd /tmp && mkdir test-project && cd test-project
stack exec backlog -- init
```
Expected output: `Initialized empty backlog in /tmp/test-project/.backlog`

```bash
ls /tmp/test-project/.backlog
```
Expected: `backlog  done  wip`

```bash
stack exec backlog -- init
```
Expected: exits non-zero with `.backlog already exists in this directory`

- [ ] **Step 4: Commit**

```bash
git add app/Main.hs
git commit -m "feat: add CLI init command and argument dispatch"
```

---

### Task 8: Confirm widget

**Files:**
- Create: `src/Backlog/Widgets/Confirm.hs`

- [ ] **Step 1: Create `src/Backlog/Widgets/Confirm.hs`**

```haskell
module Backlog.Widgets.Confirm (renderConfirm) where

import Brick
import Brick.Widgets.Border (borderWithLabel)
import Brick.Widgets.Center (centerLayer)
import Backlog.Types (Task, ResourceName, taskTitle)

renderConfirm :: Task -> Widget ResourceName
renderConfirm task =
  centerLayer $
  borderWithLabel (txt " Confirm delete ") $
  padAll 1 $
  vBox
    [ txt ("Delete \"" <> taskTitle task <> "\"?")
    , txt ""
    , hBox [txt "[y] Yes", txt "   ", txt "[n] No"]
    ]
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/Widgets/Confirm.hs
git commit -m "feat: add Confirm delete widget"
```

---

### Task 9: NewTask widget

**Files:**
- Create: `src/Backlog/Widgets/NewTask.hs`

- [ ] **Step 1: Create `src/Backlog/Widgets/NewTask.hs`**

```haskell
module Backlog.Widgets.NewTask (renderNewTask) where

import Brick
import Brick.Widgets.Border (borderWithLabel)
import Brick.Widgets.Center (centerLayer)
import qualified Brick.Widgets.Edit as E
import Backlog.Types (ResourceName)
import Data.Text (Text)

renderNewTask :: E.Editor Text ResourceName -> Widget ResourceName
renderNewTask ed =
  centerLayer $
  borderWithLabel (txt " New task ") $
  padAll 1 $
  vBox
    [ txt "Title:"
    , E.renderEditor (txt . mconcat) True ed
    , txt ""
    , txt "[enter] confirm  [esc] cancel"
    ]
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/Widgets/NewTask.hs
git commit -m "feat: add NewTask input widget"
```

---

### Task 10: TaskDetail widget

**Files:**
- Create: `src/Backlog/Widgets/TaskDetail.hs`

- [ ] **Step 1: Create `src/Backlog/Widgets/TaskDetail.hs`**

```haskell
module Backlog.Widgets.TaskDetail (renderTaskDetail) where

import Brick
import Brick.Widgets.Border (borderWithLabel)
import Brick.Widgets.Center (centerLayer)
import Backlog.Types (Task(..), ResourceName)

renderTaskDetail :: Task -> Widget ResourceName
renderTaskDetail task =
  centerLayer $
  borderWithLabel (txt (" " <> taskTitle task <> " ")) $
  padAll 1 $
  vBox
    [ txtWrap body
    , txt ""
    , txt "[esc] back"
    ]
  where
    body = if taskDescription task == "" then "(no description)" else taskDescription task
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/Widgets/TaskDetail.hs
git commit -m "feat: add TaskDetail overlay widget"
```

---

### Task 11: Board widget

**Files:**
- Create: `src/Backlog/Widgets/Board.hs`

- [ ] **Step 1: Create `src/Backlog/Widgets/Board.hs`**

```haskell
module Backlog.Widgets.Board (renderBoard) where

import Brick
import Brick.Widgets.Border (borderWithLabel, vBorder)
import qualified Brick.Widgets.List as BL
import Data.List (intersperse)
import qualified Data.Map.Strict as Map
import qualified Data.Vector as Vec
import Backlog.Types

renderBoard :: Map.Map Column (BL.List ResourceName Task) -> Column -> Widget ResourceName
renderBoard lists focused =
  hBox $ intersperse vBorder $ map (renderColumn lists focused) [minBound .. maxBound]

renderColumn
  :: Map.Map Column (BL.List ResourceName Task)
  -> Column
  -> Column
  -> Widget ResourceName
renderColumn lists focused col =
  let lst      = lists Map.! col
      isFocused = col == focused
  in borderWithLabel (txt (" " <> columnName col <> " ")) $
     BL.renderList (renderTask isFocused) isFocused lst

renderTask :: Bool -> Bool -> Task -> Widget ResourceName
renderTask _colFocused selected task =
  txt ((if selected then "> " else "  ") <> taskTitle task)
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/Widgets/Board.hs
git commit -m "feat: add Board three-column widget"
```

---

### Task 12: TUI module

**Files:**
- Create: `src/Backlog/TUI.hs`

- [ ] **Step 1: Create `src/Backlog/TUI.hs`**

```haskell
module Backlog.TUI (runTUI) where

import Brick
import Brick.Widgets.Border (borderWithLabel, hBorder)
import Brick.Widgets.Center (centerLayer)
import qualified Brick.Widgets.List as BL
import qualified Brick.Widgets.Edit as E
import qualified Graphics.Vty as V
import qualified Data.Map.Strict as Map
import qualified Data.Vector as Vec
import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (fromMaybe)
import Lens.Micro (Lens', lens)
import Lens.Micro.Mtl (zoom)

import Backlog.Types
import Backlog.FileIO (writeTask, deleteTask, moveTask)
import Backlog.Slug (toSlug, makeUniqueSlug)
import Backlog.Widgets.Board (renderBoard)
import Backlog.Widgets.TaskDetail (renderTaskDetail)
import Backlog.Widgets.NewTask (renderNewTask)
import Backlog.Widgets.Confirm (renderConfirm)

-- --------------------------------------------------------------------------
-- State

data AppState = AppState
  { taskLists     :: Map.Map Column (BL.List ResourceName Task)
  , focusedColumn :: Column
  , activeWidget  :: ActiveWidget
  , backlogRoot   :: FilePath
  , statusMessage :: Maybe Text
  , newTaskEdit   :: E.Editor Text ResourceName
  , confirmTarget :: Maybe Task
  , editTarget    :: Maybe Task   -- task being edited (title or description)
  , editIsTitle   :: Bool          -- True = editing title, False = editing description
  , editEditor    :: E.Editor Text ResourceName
  }

newTaskEditL :: Lens' AppState (E.Editor Text ResourceName)
newTaskEditL = lens newTaskEdit (\s e -> s { newTaskEdit = e })

editEditorL :: Lens' AppState (E.Editor Text ResourceName)
editEditorL = lens editEditor (\s e -> s { editEditor = e })

mkInitialState :: FilePath -> Board -> AppState
mkInitialState root b = AppState
  { taskLists     = Map.mapWithKey toList b
  , focusedColumn = Backlog
  , activeWidget  = BoardWidget
  , backlogRoot   = root
  , statusMessage = Nothing
  , newTaskEdit   = E.editor NewTaskEditorName (Just 1) ""
  , confirmTarget = Nothing
  , editTarget    = Nothing
  , editIsTitle   = True
  , editEditor    = E.editor NewTaskEditorName (Just 1) ""
  }
  where
    toList col tasks = BL.list (TaskListName col) (Vec.fromList tasks) 1

-- --------------------------------------------------------------------------
-- App

theApp :: App AppState () ResourceName
theApp = App
  { appDraw         = drawUI
  , appChooseCursor = showFirstCursor
  , appHandleEvent  = handleEvent
  , appStartEvent   = return ()
  , appAttrMap      = const (attrMap V.defAttr [])
  }

runTUI :: FilePath -> Board -> IO ()
runTUI root b = do
  _ <- defaultMain theApp (mkInitialState root b)
  return ()

-- --------------------------------------------------------------------------
-- Drawing

drawUI :: AppState -> [Widget ResourceName]
drawUI st =
  let boardW  = renderBoard (taskLists st) (focusedColumn st)
      helpBar = txt "[n] new  [shift+←/→] move  [enter] open  [d] delete  [q] quit"
      base    = vBox [boardW, hBorder, helpBar]
  in case activeWidget st of
       BoardWidget   -> [base]
       DetailWidget  -> maybe [base] (\t -> [renderTaskDetail t, base]) (selectedTask st)
       NewTaskWidget -> [renderNewTask (newTaskEdit st), base]
       EditWidget    -> [renderEditOverlay st, base]
       ConfirmWidget -> maybe [base] (\t -> [renderConfirm t, base]) (confirmTarget st)

selectedTask :: AppState -> Maybe Task
selectedTask st =
  fmap snd $ BL.listSelectedElement (taskLists st Map.! focusedColumn st)

-- --------------------------------------------------------------------------
-- Event handling

handleEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleEvent ev = do
  st <- get
  case activeWidget st of
    BoardWidget   -> handleBoardEvent ev
    DetailWidget  -> handleDetailEvent ev
    NewTaskWidget -> handleNewTaskEvent ev
    EditWidget    -> handleEditEvent ev
    ConfirmWidget -> handleConfirmEvent ev

-- Board

handleBoardEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleBoardEvent (VtyEvent vtye) = case vtye of
  V.EvKey (V.KChar 'q') []         -> halt
  V.EvKey V.KEsc        []         -> halt
  V.EvKey (V.KChar 'n') []         -> modify $ \s ->
    s { activeWidget = NewTaskWidget
      , newTaskEdit  = E.editor NewTaskEditorName (Just 1) "" }
  V.EvKey V.KEnter      []         -> do
    st <- get
    case selectedTask st of
      Nothing -> return ()
      Just _  -> modify $ \s -> s { activeWidget = DetailWidget }
  V.EvKey (V.KChar 'd') []         -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task -> modify $ \s -> s { activeWidget = ConfirmWidget, confirmTarget = Just task }
  V.EvKey V.KLeft       []         -> modify $ \s -> s { focusedColumn = prevCol (focusedColumn s) }
  V.EvKey V.KRight      []         -> modify $ \s -> s { focusedColumn = nextCol (focusedColumn s) }
  V.EvKey V.KUp         []         -> modifyFocusedList BL.listMoveUp
  V.EvKey V.KDown       []         -> modifyFocusedList BL.listMoveDown
  V.EvKey V.KLeft  [V.MShift]      -> get >>= \st -> shiftTask st prevCol
  V.EvKey V.KRight [V.MShift]      -> get >>= \st -> shiftTask st nextCol
  V.EvKey (V.KChar 'e') []         -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task ->
        modify $ \s -> s
          { activeWidget = EditWidget
          , editTarget   = Just task
          , editIsTitle  = True
          , editEditor   = E.editor NewTaskEditorName (Just 1) (taskTitle task) }
  _                                -> return ()
handleBoardEvent _ = return ()

-- Detail

handleDetailEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleDetailEvent (VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc        [] -> modify $ \s -> s { activeWidget = BoardWidget }
  V.EvKey (V.KChar 'q') [] -> halt
  V.EvKey (V.KChar 'e') [] -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task ->
        modify $ \s -> s
          { activeWidget = EditWidget
          , editTarget   = Just task
          , editIsTitle  = False
          , editEditor   = E.editor NewTaskEditorName Nothing (taskDescription task) }
  _                        -> return ()
handleDetailEvent _ = return ()

-- NewTask

handleNewTaskEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleNewTaskEvent ev@(VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc   [] -> modify $ \s -> s { activeWidget = BoardWidget }
  V.EvKey V.KEnter [] -> do
    st <- get
    let title = T.strip $ mconcat $ E.getEditContents (newTaskEdit st)
    if T.null title
      then return ()
      else do
        let existingSlugs = map taskSlug $ concatMap Vec.toList $ Map.elems (taskLists st)
            slug          = makeUniqueSlug existingSlugs (toSlug title)
            col           = focusedColumn st
            task          = Task slug title "" col
        liftIO $ writeTask (backlogRoot st) task
        modify $ \s ->
          let lst  = taskLists s Map.! col
              lst' = BL.listInsert (Vec.length (BL.listElements lst)) task lst
          in s { taskLists = Map.insert col lst' (taskLists s), activeWidget = BoardWidget }
  _ -> zoom newTaskEditL (E.handleEditorEvent ev)
handleNewTaskEvent _ = return ()

-- Confirm

handleConfirmEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleConfirmEvent (VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc        [] -> dismiss
  V.EvKey (V.KChar 'n') [] -> dismiss
  V.EvKey (V.KChar 'y') [] -> do
    st <- get
    case confirmTarget st of
      Nothing   -> dismiss
      Just task -> do
        liftIO $ deleteTask (backlogRoot st) task
        modify $ \s ->
          let col = taskColumn task
              idx = fromMaybe 0 (BL.listSelected (taskLists s Map.! col))
              lst = BL.listRemove idx (taskLists s Map.! col)
          in s { taskLists = Map.insert col lst (taskLists s)
               , activeWidget  = BoardWidget
               , confirmTarget = Nothing }
  _ -> return ()
  where dismiss = modify $ \s -> s { activeWidget = BoardWidget, confirmTarget = Nothing }
handleConfirmEvent _ = return ()

-- Edit

handleEditEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleEditEvent ev@(VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc   [] -> modify $ \s -> s { activeWidget = BoardWidget, editTarget = Nothing }
  V.EvKey V.KEnter [] -> do
    st <- get
    case editTarget st of
      Nothing   -> modify $ \s -> s { activeWidget = BoardWidget }
      Just task -> do
        let newText = T.strip $ mconcat $ E.getEditContents (editEditor st)
        if T.null newText
          then return ()
          else do
            let updated = if editIsTitle st
                          then task { taskTitle = newText }
                          else task { taskDescription = newText }
            liftIO $ writeTask (backlogRoot st) updated
            modify $ \s ->
              let col = taskColumn task
                  lst = taskLists s Map.! col
                  updateTask t = if taskSlug t == taskSlug task then updated else t
                  lst' = BL.listModify updateTask lst
              in s { taskLists    = Map.insert col lst' (taskLists s)
                   , activeWidget  = BoardWidget
                   , editTarget    = Nothing }
  _ -> zoom editEditorL (E.handleEditorEvent ev)
handleEditEvent _ = return ()

renderEditOverlay :: AppState -> Widget ResourceName
renderEditOverlay st =
  let label = if editIsTitle st then " Edit title " else " Edit description "
  in centerLayer $
     borderWithLabel (txt label) $
     padAll 1 $
     vBox
       [ E.renderEditor (vBox . map txt) True (editEditor st)
       , txt ""
       , txt "[enter] save  [esc] cancel"
       ]

-- --------------------------------------------------------------------------
-- Helpers

modifyFocusedList
  :: (BL.List ResourceName Task -> BL.List ResourceName Task)
  -> EventM ResourceName AppState ()
modifyFocusedList f =
  modify $ \s -> s { taskLists = Map.adjust f (focusedColumn s) (taskLists s) }

shiftTask :: AppState -> (Column -> Column) -> EventM ResourceName AppState ()
shiftTask st colFn = do
  let col    = focusedColumn st
      newCol = colFn col
  when (newCol /= col) $
    case BL.listSelectedElement (taskLists st Map.! col) of
      Nothing        -> return ()
      Just (idx, task) -> do
        moved <- liftIO $ moveTask (backlogRoot st) task newCol
        modify $ \s ->
          let srcList  = BL.listRemove idx (taskLists s Map.! col)
              dstList  = BL.listInsert
                           (Vec.length (BL.listElements (taskLists s Map.! newCol)))
                           moved
                           (taskLists s Map.! newCol)
          in s { taskLists = Map.insert col srcList $ Map.insert newCol dstList (taskLists s) }

prevCol :: Column -> Column
prevCol Backlog = Backlog
prevCol WIP     = Backlog
prevCol Done    = WIP

nextCol :: Column -> Column
nextCol Backlog = WIP
nextCol WIP     = Done
nextCol Done    = Done
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0 with no errors. Fix any type errors before proceeding.

- [ ] **Step 3: Commit**

```bash
git add src/Backlog/TUI.hs
git commit -m "feat: add TUI module with Brick app wiring"
```

---

### Task 13: Wire Main to TUI

**Files:**
- Modify: `app/Main.hs`

- [ ] **Step 1: Update `launchTUI` in `app/Main.hs`**

Replace the `launchTUI` function:

```haskell
launchTUI :: IO ()
launchTUI = do
  mRoot <- findBacklogRoot
  case mRoot of
    Nothing   -> do
      hPutStrLn stderr
        "no backlog found in this directory or any parent (run 'backlog init' to create one)"
      exitFailure
    Just root -> do
      board <- loadBoard root
      Backlog.TUI.runTUI root board
```

Add the import at the top:

```haskell
import qualified Backlog.TUI
```

- [ ] **Step 2: Verify it builds**

Run: `stack build`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add app/Main.hs
git commit -m "feat: wire Main to TUI"
```

---

### Task 14: Smoke test

**Files:** none

- [ ] **Step 1: Initialize a test backlog**

```bash
cd /tmp && rm -rf smoke-test && mkdir smoke-test && cd smoke-test
stack exec backlog -- init
```
Expected: `Initialized empty backlog in /tmp/smoke-test/.backlog`

- [ ] **Step 2: Launch the TUI**

```bash
stack exec backlog
```
Expected: TUI opens with three empty columns (BACKLOG, WIP, DONE) and a help bar at the bottom.

- [ ] **Step 3: Verify these interactions work**

| Action | Expected result |
|--------|----------------|
| Press `n`, type a title, press `enter` | Task appears in BACKLOG |
| Press `↓` / `↑` | Selection moves within column |
| Press `→` | Focus moves to WIP column |
| Press `shift+←` on a task | Task moves to previous column |
| Press `enter` on a task | Detail panel opens |
| Press `esc` | Returns to board |
| Press `d` on a task | Confirmation dialog appears |
| Press `y` | Task is deleted |
| Press `q` | TUI exits |

- [ ] **Step 4: Verify files on disk**

After creating tasks and moving them, inspect the `.backlog/` directory:

```bash
ls /tmp/smoke-test/.backlog/backlog/
ls /tmp/smoke-test/.backlog/wip/
ls /tmp/smoke-test/.backlog/done/
cat /tmp/smoke-test/.backlog/backlog/<slug>.md
```

Expected: files exist in the correct column directories, content is `# Title\n\n` format.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete backlog CLI implementation"
```
