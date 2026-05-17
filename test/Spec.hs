module Main where

import Test.Hspec
import qualified Backlog.SlugSpec
import qualified Backlog.DiscoverySpec
import qualified Backlog.FileIOSpec
import qualified Backlog.CLISpec

main :: IO ()
main = hspec $ do
  Backlog.SlugSpec.spec
  Backlog.DiscoverySpec.spec
  Backlog.FileIOSpec.spec
  Backlog.CLISpec.spec
