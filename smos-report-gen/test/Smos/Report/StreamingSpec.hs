{-# LANGUAGE TypeApplications #-}

module Smos.Report.StreamingSpec where

import Test.Hspec
import Test.Validity

import Data.List.NonEmpty (NonEmpty(..))
import Data.Tree

import Cursor.Forest
import Cursor.List.NonEmpty
import Cursor.Tree

import Smos.Data

import Data.GenValidity.Containers ()

import Smos.Data.Gen ()

import Smos.Report.Streaming

spec :: Spec
spec =
  describe "forestCursors" $ do
    it "produces valid forests" $ producesValidsOnValids (forestCursors @Entry)
    it "produces congruent forests" $
      forAllValid $ \f -> () <$ forestCursors @Entry f `shouldBe` () <$ f
    it "works for this simple case" $
      concatMap flatten (forestCursors [Node 'a' [Node 'b' []], Node 'c' []]) `shouldBe`
      [ ForestCursor
          { forestCursorListCursor =
              NonEmptyCursor
                { nonEmptyCursorPrev = []
                , nonEmptyCursorCurrent =
                    TreeCursor
                      { treeAbove = Nothing
                      , treeCurrent = 'a'
                      , treeBelow = OpenForest (CNode 'b' EmptyCForest :| [])
                      }
                , nonEmptyCursorNext = [CNode 'c' EmptyCForest]
                }
          }
      , ForestCursor
          { forestCursorListCursor =
              NonEmptyCursor
                { nonEmptyCursorPrev = []
                , nonEmptyCursorCurrent =
                    TreeCursor
                      { treeAbove =
                          Just
                            (TreeAbove
                               { treeAboveLefts = []
                               , treeAboveAbove = Nothing
                               , treeAboveNode = 'a'
                               , treeAboveRights = []
                               })
                      , treeCurrent = 'b'
                      , treeBelow = EmptyCForest
                      }
                , nonEmptyCursorNext = [CNode 'c' EmptyCForest]
                }
          }
      , ForestCursor
          { forestCursorListCursor =
              NonEmptyCursor
                { nonEmptyCursorPrev =
                    [CNode 'a' (OpenForest (CNode 'b' EmptyCForest :| []))]
                , nonEmptyCursorCurrent =
                    TreeCursor
                      { treeAbove = Nothing
                      , treeCurrent = 'c'
                      , treeBelow = EmptyCForest
                      }
                , nonEmptyCursorNext = []
                }
          }
      ]
