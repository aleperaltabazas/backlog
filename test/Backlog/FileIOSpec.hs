{-# LANGUAGE OverloadedStrings #-}

module Backlog.FileIOSpec (spec) where

import Test.Hspec
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))
import System.Directory (createDirectory, doesFileExist)
import qualified Data.Map.Strict as Map
import Backlog.Types
import Backlog.FileIO

spec :: Spec
spec = do
  describe "parseTaskFile" $ do
    it "parses the title from the H1 heading" $ do
      let task = parseTaskFile Backlog "add-auth" "# Add authentication\n"
      taskTitle task `shouldBe` "Add authentication"

    it "parses description from content after the blank line" $ do
      let task = parseTaskFile Backlog "add-auth" "# Add authentication\n\nSome description."
      taskDescription task `shouldBe` "Some description."

    it "returns empty description when there is none" $ do
      let task = parseTaskFile Backlog "fix-bug" "# Fix bug\n"
      taskDescription task `shouldBe` ""

    it "sets the slug from the provided argument" $ do
      let task = parseTaskFile WIP "my-slug" "# My task\n"
      taskSlug task `shouldBe` "my-slug"

    it "sets the column from the provided argument" $ do
      let task = parseTaskFile Done "slug" "# Task\n"
      taskColumn task `shouldBe` Done

  describe "loadBoard" $ do
    it "loads tasks from all three column directories" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> "backlog")
        createDirectory (tmp </> "wip")
        createDirectory (tmp </> "done")
        writeFile (tmp </> "backlog" </> "task-one.md") "# Task one\n"
        writeFile (tmp </> "done"    </> "task-two.md") "# Task two\n\nDone."
        board <- loadBoard tmp
        length (board Map.! Backlog) `shouldBe` 1
        length (board Map.! WIP)     `shouldBe` 0
        length (board Map.! Done)    `shouldBe` 1

  describe "writeTask" $ do
    it "creates a file in the correct column directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "Description." Backlog
        writeTask tmp task
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` True)

  describe "moveTask" $ do
    it "moves the file to the new column directory and updates taskColumn" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "" Backlog
        writeTask tmp task
        moved <- moveTask tmp task WIP
        taskColumn moved `shouldBe` WIP
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` False)
        doesFileExist (tmp </> "wip"     </> "my-task.md") >>= (`shouldBe` True)

  describe "deleteTask" $ do
    it "removes the task file from disk" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        mapM_ (createDirectory . (tmp </>)) ["backlog", "wip", "done"]
        let task = Task "my-task" "My task" "" Backlog
        writeTask tmp task
        deleteTask tmp task
        doesFileExist (tmp </> "backlog" </> "my-task.md") >>= (`shouldBe` False)
