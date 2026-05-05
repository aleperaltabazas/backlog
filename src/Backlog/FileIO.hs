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
loadBoard root = do
  cols  <- mapM (loadColumn root) [minBound .. maxBound]
  return $ Map.fromList (zip [minBound .. maxBound] cols)

loadColumn :: FilePath -> Column -> IO [Task]
loadColumn root col = do
  let dir = columnDir root col
  exists <- doesDirectoryExist dir
  if not exists
    then return []
    else do
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
