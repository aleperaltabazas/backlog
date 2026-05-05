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
