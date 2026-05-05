module Main where

import Test.Hspec
import qualified Backlog.SlugSpec

main :: IO ()
main = hspec Backlog.SlugSpec.spec
