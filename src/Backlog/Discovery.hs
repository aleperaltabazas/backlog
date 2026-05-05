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
