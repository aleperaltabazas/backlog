{-# LANGUAGE OverloadedStrings #-}

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
