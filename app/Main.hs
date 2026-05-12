module Main where

import Backlog.Discovery (findBacklogRoot)
import Backlog.FileIO (loadBoard, initBacklog)
import qualified Backlog.TUI
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

data Command = Launch | Init

commandParser :: Parser Command
commandParser = subparser (command "init" initInfo) <|> pure Launch
  where
    initInfo = info (pure Init) (progDesc "Initialise a new .backlog/ in the current directory")

opts :: ParserInfo Command
opts = info (helper <*> commandParser)
  ( fullDesc
  <> progDesc "A terminal-based task board"
  <> header "backlog - manage your tasks from the terminal"
  )

main :: IO ()
main = do
  cmd <- execParser opts
  case cmd of
    Init   -> initBacklog
    Launch -> launchTUI

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
