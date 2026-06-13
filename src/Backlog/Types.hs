{-# LANGUAGE OverloadedStrings #-}

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
