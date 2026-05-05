module Main where

import Test.Hspec
import qualified Backlog.SlugSpec
import qualified Backlog.DiscoverySpec

main :: IO ()
main = hspec $ do
  Backlog.SlugSpec.spec
  Backlog.DiscoverySpec.spec
