module Backlog.DiscoverySpec (spec) where

import Test.Hspec
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))
import System.Directory (createDirectory)
import Backlog.Discovery (findBacklogRootFrom)

spec :: Spec
spec = do
  describe "findBacklogRootFrom" $ do
    it "finds .backlog in the start directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> ".backlog")
        result <- findBacklogRootFrom tmp
        result `shouldBe` Just (tmp </> ".backlog")

    it "finds .backlog in a parent directory" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        createDirectory (tmp </> ".backlog")
        createDirectory (tmp </> "src")
        result <- findBacklogRootFrom (tmp </> "src")
        result `shouldBe` Just (tmp </> ".backlog")

    it "returns Nothing when .backlog does not exist" $
      withSystemTempDirectory "backlog-test" $ \tmp -> do
        result <- findBacklogRootFrom tmp
        result `shouldBe` Nothing
