{-# LANGUAGE OverloadedStrings #-}

module Backlog.SlugSpec (spec) where

import Test.Hspec
import Backlog.Slug

spec :: Spec
spec = do
  describe "toSlug" $ do
    it "lowercases and hyphenates words" $
      toSlug "Add authentication" `shouldBe` "add-authentication"
    it "strips non-alphanumeric characters" $
      toSlug "Fix bug (urgent!)" `shouldBe` "fix-bug-urgent"
    it "handles a single word" $
      toSlug "Refactor" `shouldBe` "refactor"

  describe "makeUniqueSlug" $ do
    it "returns the base slug when no collision" $
      makeUniqueSlug [] "add-auth" `shouldBe` "add-auth"
    it "appends -2 on first collision" $
      makeUniqueSlug ["add-auth"] "add-auth" `shouldBe` "add-auth-2"
    it "appends -3 on second collision" $
      makeUniqueSlug ["add-auth", "add-auth-2"] "add-auth" `shouldBe` "add-auth-3"
