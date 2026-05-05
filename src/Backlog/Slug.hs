{-# LANGUAGE OverloadedStrings #-}

module Backlog.Slug (toSlug, makeUniqueSlug) where

import Data.Char (isAlphaNum, toLower, isSpace)
import Data.Text (Text)
import qualified Data.Text as T

toSlug :: Text -> Text
toSlug = T.intercalate "-"
       . filter (not . T.null)
       . T.words
       . T.map (\c -> if isAlphaNum c then toLower c
                      else if isSpace c then c
                      else ' ')

makeUniqueSlug :: [Text] -> Text -> Text
makeUniqueSlug existing base =
  let candidates = base : map (\n -> base <> "-" <> T.pack (show n)) [2 :: Int ..]
  in head $ filter (`notElem` existing) candidates
