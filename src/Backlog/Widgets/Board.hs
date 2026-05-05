{-# LANGUAGE OverloadedStrings #-}

module Backlog.Widgets.Board (renderBoard) where

import Brick
import Brick.Widgets.Border (borderWithLabel, vBorder)
import qualified Brick.Widgets.List as BL
import Data.List (intersperse)
import qualified Data.Map.Strict as Map
import Backlog.Types

renderBoard :: Map.Map Column (BL.List ResourceName Task) -> Column -> Widget ResourceName
renderBoard lists focused =
  hBox $ intersperse vBorder $ map (renderColumn lists focused) [minBound .. maxBound]

renderColumn
  :: Map.Map Column (BL.List ResourceName Task)
  -> Column
  -> Column
  -> Widget ResourceName
renderColumn lists focused col =
  let lst       = lists Map.! col
      isFocused = col == focused
  in borderWithLabel (txt (" " <> columnName col <> " ")) $
     BL.renderList (renderTask isFocused) isFocused lst

renderTask :: Bool -> Bool -> Task -> Widget ResourceName
renderTask _colFocused selected task =
  txt ((if selected then "> " else "  ") <> taskTitle task)
