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
