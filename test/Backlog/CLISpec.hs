{-# LANGUAGE OverloadedStrings #-}

module Backlog.CLISpec (spec) where

import Test.Hspec
import qualified Data.Map.Strict as Map
import Backlog.Types
import Backlog.CLI (findTask)

sampleBoard :: Board
sampleBoard = Map.fromList
  [ (Backlog, [Task "add-auth" "Add authentication" "" Backlog])
  , (WIP,     [Task "fix-bug"  "Fix bug"            "" WIP])
  , (Done,    [Task "old-task" "Old task"            "" Done])
  ]

spec :: Spec
spec = do
  describe "findTask" $ do
    it "finds a task by exact slug" $
      findTask sampleBoard "fix-bug" `shouldBe` Just (Task "fix-bug" "Fix bug" "" WIP)

    it "finds a task by title converted to slug" $
      findTask sampleBoard "Fix bug" `shouldBe` Just (Task "fix-bug" "Fix bug" "" WIP)

    it "returns Nothing when task is not found" $
      findTask sampleBoard "nonexistent" `shouldBe` Nothing

    it "searches Backlog before WIP when slugs collide" $ do
      let board = Map.fromList
            [ (Backlog, [Task "shared" "Shared" "" Backlog])
            , (WIP,     [Task "shared" "Shared" "" WIP])
            , (Done,    [])
            ]
      findTask board "shared" `shouldBe` Just (Task "shared" "Shared" "" Backlog)
