{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

module Smos.Report.FilterSpec where

import Data.Char as Char
import Data.Text (Text)
import qualified Data.Text as T

import Test.Hspec
import Test.QuickCheck as QC
import Test.Validity

import Text.Megaparsec

import Cursor.Forest.Gen ()

import Smos.Report.Path.Gen ()

import Smos.Report.Filter
import Smos.Report.Filter.Gen ()

spec :: Spec
spec = do
  eqSpecOnValid @Filter
  genValidSpec @Filter
  describe "foldFilterAnd" $ it "produces valid results" $ producesValidsOnValids foldFilterAnd
  describe "filterPredicate" $ it "produces valid results" $ producesValidsOnValids3 filterPredicate
  describe "filterP" $ do
    parsesValidSpec filterP filterText
    parseJustSpec filterP "tag:work" (FilterHasTag "work")
    parseJustSpec filterP "state:NEXT" (FilterTodoState "NEXT")
    parseJustSpec filterP "level:5" (FilterLevel 5)
    parseJustSpec
      filterP
      "property:exact:effort:30m"
      (FilterProperty $ ExactProperty "effort" "30m")
    parseJustSpec filterP "property:has:effort" (FilterProperty $ HasProperty "effort")
  describe "filterHasTagP" $ parsesValidSpec filterHasTagP tagText
  describe "filterTodoStateP" $ parsesValidSpec filterTodoStateP todoStateText
  describe "filterFileP" $ parsesValidSpec filterFileP fileText
  describe "filterLevelP" $ parsesValidSpec filterLevelP levelText
  describe "filterPropertyP" $ parsesValidSpec filterPropertyP propertyText
  describe "filterParentP" $ parsesValidSpec filterParentP parentText
  describe "filterAncestorP" $ parsesValidSpec filterAncestorP ancestorText
  describe "filterChildP" $ parsesValidSpec filterChildP childText
  describe "filterLegacyP" $ parsesValidSpec filterLegacyP legacyText
  describe "filterNotP" $ parsesValidSpec filterNotP notText
  describe "filterBinrelP" $ parsesValidSpec filterBinRelP binRelText
  describe "filterOrP" $ parsesValidSpec filterOrP orText
  describe "filterAndP" $ parsesValidSpec filterAndP andText
  describe "propertyFilterP" $ parsesValidSpec propertyFilterP propertyFilterText
  describe "exactPropertyP" $ parsesValidSpec exactPropertyP exactPropertyText
  describe "hasPropertyP" $ parsesValidSpec hasPropertyP hasPropertyText
  describe "renderFilter" $ do
    it "produces valid texts" $ producesValidsOnValids renderFilter
    it "renders filters that parse to the same" $
      forAllValid $ \f -> parseJust filterP (renderFilter f) f
  describe "renderPropertyFilter" $ do
    it "produces valid texts" $ producesValidsOnValids renderPropertyFilter
    it "renders filters that parse to the same" $
      forAllValid $ \f -> parseJust propertyFilterP (renderPropertyFilter f) f

filterText :: Gen Text
filterText =
  oneof
    [ tagText
    , todoStateText
    , fileText
    , levelText
    , propertyText
    , parentText
    , ancestorText
    , childText
    , legacyText
    , notText
    , binRelText
    ]

tagText :: Gen Text
tagText = textPieces [pure "tag:", genValid]

todoStateText :: Gen Text
todoStateText = textPieces [pure "state:", genValid]

fileText :: Gen Text
fileText = textPieces [pure "file:", genValid]

levelText :: Gen Text
levelText = textPieces [pure "level:", T.pack . show <$> (genValid :: Gen Int)]

propertyText :: Gen Text
propertyText = textPieces [pure "property:", propertyFilterText]

parentText :: Gen Text
parentText = textPieces [pure "parent:", filterText]

ancestorText :: Gen Text
ancestorText = textPieces [pure "ancestor:", filterText]

childText :: Gen Text
childText = textPieces [pure "child:", filterText]

legacyText :: Gen Text
legacyText = textPieces [pure "legacy:", filterText]

notText :: Gen Text
notText = textPieces [pure "not:", filterText]

binRelText :: Gen Text
binRelText = textPieces [pure "(", oneof [orText, andText], pure ")"]

orText :: Gen Text
orText = textPieces [filterText, pure " or ", filterText]

andText :: Gen Text
andText = textPieces [filterText, pure " and ", filterText]

propertyFilterText :: Gen Text
propertyFilterText = oneof [exactPropertyText, hasPropertyText]

exactPropertyText :: Gen Text
exactPropertyText = textPieces [pure "exact:", propertyNameText, pure ":", propertyValueText]

hasPropertyText :: Gen Text
hasPropertyText = textPieces [pure "has:", propertyNameText]

-- These don't match exactly, but they're a good start.
propertyNameText :: Gen Text
propertyNameText =
  T.pack <$>
  genListOf
    (genValid `suchThat`
     (\c -> Char.isPrint c && not (Char.isSpace c) && not (Char.isPunctuation c)))

-- These don't match exactly, but they're a good start.
propertyValueText :: Gen Text
propertyValueText =
  T.pack <$>
  genListOf
    (genValid `suchThat`
     (\c -> Char.isPrint c && not (Char.isSpace c) && not (Char.isPunctuation c)))

textPieces :: [Gen Text] -> Gen Text
textPieces = fmap T.concat . sequenceA

textStartingWith :: Text -> Gen Text
textStartingWith prefix = (prefix <>) <$> genValid

parseJustSpec :: (Show a, Eq a) => P a -> Text -> a -> Spec
parseJustSpec p s res = it (unwords ["parses", show s, "as", show res]) $ parseJust p s res

parseNothingSpec :: (Show a, Eq a) => P a -> Text -> Spec
parseNothingSpec p s = it (unwords ["fails to parse", show s]) $ parseNothing p s

parsesValidSpec :: (Show a, Eq a, Validity a) => P a -> Gen Text -> Spec
parsesValidSpec p gen = it "only parses valid values" $ forAll gen $ parsesValid p

parseJust :: (Show a, Eq a) => P a -> Text -> a -> Expectation
parseJust p s res =
  case parse (p <* eof) "test input" s of
    Left err ->
      expectationFailure $ unlines ["P failed on input", show s, "with error", parseErrorPretty err]
    Right out -> out `shouldBe` res

parseNothing :: (Show a, Eq a) => P a -> Text -> Expectation
parseNothing p s =
  case parse (p <* eof) "test input" s of
    Right v ->
      expectationFailure $
      unlines ["P succeeded on input", show s, "at parsing", show v, "but it should have failed."]
    Left _ -> pure ()

parsesValid :: (Show a, Eq a, Validity a) => P a -> Text -> Property
parsesValid p s =
  let (useful, ass) =
        case parse (p <* eof) "test input" s of
          Left _ -> (False, (pure () :: IO ()))
          Right out -> (True, shouldBeValid out)
   in cover useful 10 "useful" $ property ass
