{-# LANGUAGE OverloadedStrings #-}

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
