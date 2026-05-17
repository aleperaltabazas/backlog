{-# LANGUAGE OverloadedStrings #-}

module Backlog.CLISpec (spec) where

import Test.Hspec
import qualified Data.Map.Strict as Map
import Backlog.Types
import System.IO.Temp (withSystemTempDirectory)
import System.Directory (createDirectory, doesFileExist, withCurrentDirectory)
import System.FilePath ((</>))
import Backlog.CLI (findTask, runCreate)

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

  describe "runCreate" $ do
    it "creates a task file in the correct column directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        let root = tmp </> ".backlog"
        mapM_ createDirectory [root, root </> "backlog", root </> "wip", root </> "done"]
        withCurrentDirectory tmp $ runCreate "My Task" Backlog "" False
        doesFileExist (root </> "backlog" </> "my-task.md") >>= (`shouldBe` True)

    it "makes slug unique when a conflicting slug already exists" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        let root = tmp </> ".backlog"
        mapM_ createDirectory [root, root </> "backlog", root </> "wip", root </> "done"]
        writeFile (root </> "backlog" </> "my-task.md") "# My task\n"
        withCurrentDirectory tmp $ runCreate "My Task" Backlog "" False
        doesFileExist (root </> "backlog" </> "my-task-2.md") >>= (`shouldBe` True)
