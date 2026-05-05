{-# LANGUAGE OverloadedStrings #-}

module Backlog.Widgets.NewTask (renderNewTask) where

import Brick
import Brick.Widgets.Border (borderWithLabel)
import Brick.Widgets.Center (centerLayer)
import qualified Brick.Widgets.Edit as E
import Backlog.Types (ResourceName)
import Data.Text (Text)

renderNewTask :: E.Editor Text ResourceName -> Widget ResourceName
renderNewTask ed =
  centerLayer $
  borderWithLabel (txt " New task ") $
  padAll 1 $
  vBox
    [ txt "Title:"
    , E.renderEditor (txt . mconcat) True ed
    , txt ""
    , txt "[enter] confirm  [esc] cancel"
    ]
