{-# LANGUAGE OverloadedStrings #-}

module Backlog.CLI
  ( findTask
  , columnReader
  , runCreate
  , runMove
  , runDelete
  , runUpdate
  ) where

import Backlog.Discovery (findBacklogRoot)
import Backlog.FileIO (loadBoard, writeTask, moveTask, deleteTask)
import Backlog.Slug (toSlug, makeUniqueSlug)
import Backlog.Types
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Options.Applicative (ReadM, eitherReader)
import System.IO (hPutStrLn, stderr, hFlush, stdout)
import System.Exit (exitFailure)
import Control.Monad (when)

columnReader :: ReadM Column
columnReader = eitherReader $ \s -> case s of
  "backlog" -> Right Backlog
  "wip"     -> Right WIP
  "done"    -> Right Done
  other     -> Left $ "invalid column: " <> other <> " (use backlog, wip, or done)"

findTask :: Board -> Text -> Maybe Task
findTask board input =
  listToMaybe [ t | col <- [minBound..maxBound]
                  , t   <- Map.findWithDefault [] col board
                  , taskSlug t == input || taskSlug t == toSlug input ]

-- Helper to find the backlog root and run an action with it
withRoot :: (FilePath -> IO a) -> IO a
withRoot action = do
  maybeRoot <- findBacklogRoot
  case maybeRoot of
    Nothing   -> do
      hPutStrLn stderr "error: .backlog/ directory not found"
      exitFailure
    Just root -> action root

-- Helper to find a task by slug/title and run an action with it
withFoundTask :: Board -> Text -> (Task -> IO a) -> IO a
withFoundTask board input action =
  case findTask board input of
    Nothing   -> do
      hPutStrLn stderr $ "error: task '" <> T.unpack input <> "' not found"
      exitFailure
    Just task -> action task

runCreate :: Text -> Column -> Text -> Bool -> IO ()
runCreate titleText col desc verboseFlag = withRoot $ \root -> do
  board <- loadBoard root
  let allSlugs = concatMap (map taskSlug) (Map.elems board)
      slug     = makeUniqueSlug allSlugs (toSlug titleText)
      task     = Task { taskSlug = slug, taskTitle = titleText
                      , taskDescription = desc, taskColumn = col }
  writeTask root task
  when verboseFlag $ putStrLn $ "Created task '" <> T.unpack slug <> "'"

runMove :: Text -> Column -> Bool -> IO ()
runMove input dest verboseFlag = withRoot $ \root -> do
  board <- loadBoard root
  withFoundTask board input $ \task -> do
    _ <- moveTask root task dest
    when verboseFlag $ putStrLn $
      "Moved '" <> T.unpack (taskSlug task) <> "' to " <> columnDirName dest

runDelete :: Text -> Bool -> Bool -> IO ()
runDelete input skipConfirm verboseFlag = withRoot $ \root -> do
  board <- loadBoard root
  withFoundTask board input $ \task -> do
    confirmed <- if skipConfirm
      then return True
      else do
        putStr $ "Delete '" <> T.unpack (taskSlug task) <> "'? [y/N] "
        hFlush stdout
        answer <- getLine
        return (answer == "y" || answer == "Y")
    if confirmed
      then do
        deleteTask root task
        when verboseFlag $ putStrLn $ "Deleted '" <> T.unpack (taskSlug task) <> "'"
      else putStrLn "Aborted."

runUpdate :: Text -> Maybe Text -> Maybe Text -> Bool -> IO ()
runUpdate = error "not implemented"
