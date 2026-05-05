{-# LANGUAGE OverloadedStrings #-}

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

loadBoard :: FilePath -> IO Board
loadBoard = error "not yet implemented"

writeTask :: FilePath -> Task -> IO ()
writeTask = error "not yet implemented"

deleteTask :: FilePath -> Task -> IO ()
deleteTask = error "not yet implemented"

moveTask :: FilePath -> Task -> Column -> IO Task
moveTask = error "not yet implemented"

initBacklog :: IO ()
initBacklog = error "not yet implemented"
