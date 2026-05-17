{-# LANGUAGE OverloadedStrings #-}

module Backlog.CLI
  ( findTask
  , columnReader
  , runCreate
  , runMove
  , runDelete
  , runUpdate
  ) where

import Backlog.Slug (toSlug)
import Backlog.Types
import qualified Data.Map.Strict as Map
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Options.Applicative (ReadM, eitherReader)

columnReader :: ReadM Column
columnReader = eitherReader $ \s -> case s of
  "backlog" -> Right Backlog
  "wip"     -> Right WIP
  "done"    -> Right Done
  other     -> Left $ "invalid column: " <> other <> " (use backlog, wip, or done)"

findTask :: Board -> Text -> Maybe Task
findTask board input =
  listToMaybe [ t | col <- [minBound..maxBound]
                  , t   <- Map.findWithDefault [] col board
                  , taskSlug t == input || taskSlug t == toSlug input ]

runCreate :: Text -> Column -> Text -> Bool -> IO ()
runCreate = error "not implemented"

runMove :: Text -> Column -> Bool -> IO ()
runMove = error "not implemented"

runDelete :: Text -> Bool -> Bool -> IO ()
runDelete = error "not implemented"

runUpdate :: Text -> Maybe Text -> Maybe Text -> Bool -> IO ()
runUpdate = error "not implemented"
