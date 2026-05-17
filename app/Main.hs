{-# LANGUAGE OverloadedStrings #-}

module Main where

import Backlog.Discovery (findBacklogRoot)
import Backlog.FileIO (loadBoard, initBacklog)
import qualified Backlog.CLI as CLI
import Backlog.Types (Column (..))
import qualified Backlog.TUI
import Data.Text (Text)
import qualified Data.Text as T
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

data Command
  = Launch
  | Init
  | Create Text Column Text Bool                -- title, row, description, verbose
  | Move   Text Column Bool                     -- task, destination, verbose
  | Delete Text Bool   Bool                     -- task, yes, verbose
  | Update Text (Maybe Text) (Maybe Text) Bool  -- task, title, description, verbose

commandParser :: Parser Command
commandParser =
  subparser
    ( command "init"   initInfo
   <> command "create" createInfo
   <> command "move"   moveInfo
   <> command "delete" deleteInfo
   <> command "update" updateInfo
    )
  <|> pure Launch

initInfo :: ParserInfo Command
initInfo = info (helper <*> pure Init)
  (progDesc "Initialise a new .backlog/ in the current directory")

createInfo :: ParserInfo Command
createInfo = info (helper <*> createParser)
  (progDesc "Create a new task")

createParser :: Parser Command
createParser = Create
  <$> (T.pack <$> strOption
        ( long "title" <> short 't' <> metavar "TITLE" <> help "Task title" ))
  <*> option CLI.columnReader
        ( long "row" <> short 'r' <> metavar "ROW"
       <> value Backlog <> showDefaultWith (const "backlog")
       <> help "Column: backlog|wip|done" )
  <*> (T.pack <$> strOption
        ( long "description" <> short 'd' <> metavar "DESCRIPTION"
       <> value "" <> help "Task description (default: empty)" ))
  <*> switch ( long "verbose" <> short 'v' <> help "Print confirmation on success" )

moveInfo :: ParserInfo Command
moveInfo = info (helper <*> moveParser)
  (progDesc "Move a task to another column")

moveParser :: Parser Command
moveParser = Move
  <$> (T.pack <$> argument str (metavar "TASK" <> help "Task slug or title"))
  <*> option CLI.columnReader
        ( long "to" <> metavar "DESTINATION" <> help "Destination column: backlog|wip|done" )
  <*> switch ( long "verbose" <> short 'v' <> help "Print confirmation on success" )

deleteInfo :: ParserInfo Command
deleteInfo = info (helper <*> deleteParser)
  (progDesc "Delete a task")

deleteParser :: Parser Command
deleteParser = Delete
  <$> (T.pack <$> argument str (metavar "TASK" <> help "Task slug or title"))
  <*> switch ( long "yes" <> short 'y' <> help "Skip confirmation prompt" )
  <*> switch ( long "verbose" <> short 'v' <> help "Print confirmation on success" )

updateInfo :: ParserInfo Command
updateInfo = info (helper <*> updateParser)
  (progDesc "Update a task's title or description")

updateParser :: Parser Command
updateParser = Update
  <$> (T.pack <$> argument str (metavar "TASK" <> help "Task slug or title"))
  <*> optional (T.pack <$> strOption
        ( long "title" <> short 't' <> metavar "TITLE" <> help "New title" ))
  <*> optional (T.pack <$> strOption
        ( long "description" <> short 'd' <> metavar "DESCRIPTION" <> help "New description" ))
  <*> switch ( long "verbose" <> short 'v' <> help "Print confirmation on success" )

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
    Init                       -> initBacklog
    Launch                     -> launchTUI
    Create t col desc v        -> CLI.runCreate t col desc v
    Move   tsk dest v          -> CLI.runMove tsk dest v
    Delete tsk skipConfirm v   -> CLI.runDelete tsk skipConfirm v
    Update tsk mTitle mDesc v  -> CLI.runUpdate tsk mTitle mDesc v

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
