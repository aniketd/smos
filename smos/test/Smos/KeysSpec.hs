{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Smos.KeysSpec where

import TestImport

import Text.Megaparsec

import Smos.Keys
import Smos.Keys.Gen ()
import Smos.OptParse.Gen ()

spec :: Spec
spec = do
  eqSpecOnValid @Key
  genValidSpec @Key
  jsonSpecOnValid @Key
  describe "keyP" $ do
    parsesValidSpec keyP keyText
    parseJustSpec keyP "c" (KChar 'c')
    parseJustSpec keyP "C" (KChar 'C')
    parseJustSpec keyP "m" (KChar 'm')
    parseJustSpec keyP "M" (KChar 'M')
    parseJustSpec keyP "-" (KChar '-')
    parseJustSpec keyP "F12" (KFun 12)
    parseJustSpec keyP "f12" (KFun 12)
    parseNothingSpec keyP "g12"
    parseNothingSpec keyP "g12"
    parseJustSpec keyP "Enter" KEnter
    parseJustSpec keyP "enter" KEnter
  describe "renderKey" $ do
    it "renders the something that keyP can parse to the same thing" $
      forAllValid $ \k -> parseJust keyP (renderKey k) k
  eqSpecOnValid @Modifier
  genValidSpec @Modifier
  jsonSpecOnValid @Modifier
  describe "modifierP" $ do
    parsesValidSpec modifierP modText
    parseJustSpec modifierP "S" MShift
    parseJustSpec modifierP "s" MShift
    parseJustSpec modifierP "C" MCtrl
    parseJustSpec modifierP "c" MCtrl
    parseJustSpec modifierP "M" MMeta
    parseJustSpec modifierP "m" MMeta
    parseJustSpec modifierP "A" MAlt
    parseJustSpec modifierP "a" MAlt
  describe "renderModifier" $ do
    it "renders the something that modifierP can parse to the same thing" $
      forAllValid $ \k -> parseJust modifierP (renderModifier k) k
  eqSpecOnValid @KeyPress
  genValidSpec @KeyPress
  jsonSpecOnValid @KeyPress
  describe "keyPressP" $ do
    parsesValidSpec keyPressP keyPressText
    parseJustSpec keyPressP "a" $ KeyPress (KChar 'a') []
    parseJustSpec keyPressP "M-a" $ KeyPress (KChar 'a') [MMeta]
    parseJustSpec keyPressP "M-S-a" $ KeyPress (KChar 'a') [MMeta, MShift]
    parseJustSpec keyPressP "m" $ KeyPress (KChar 'm') []
    parseJustSpec keyPressP "M-m" $ KeyPress (KChar 'm') [MMeta]
    parseJustSpec keyPressP "M-S-m" $ KeyPress (KChar 'm') [MMeta, MShift]
    parseJustSpec keyPressP "M" $ KeyPress (KChar 'M') []
    parseJustSpec keyPressP "M-M" $ KeyPress (KChar 'M') [MMeta]
    parseJustSpec keyPressP "M-S-M" $ KeyPress (KChar 'M') [MMeta, MShift]
    parseJustSpec keyPressP "-" $ KeyPress (KChar '-') []
    parseJustSpec keyPressP "M--" $ KeyPress (KChar '-') [MMeta]
    parseJustSpec keyPressP "M-S--" $ KeyPress (KChar '-') [MMeta, MShift]
    parseJustSpec keyPressP "A" $ KeyPress (KChar 'A') []
    parseJustSpec keyPressP "m-a" $ KeyPress (KChar 'a') [MMeta]
    parseJustSpec keyPressP "M-s-A" $ KeyPress (KChar 'A') [MMeta, MShift]
    parseJustSpec keyPressP "Enter" $ KeyPress KEnter []
    parseJustSpec keyPressP "M-Enter" $ KeyPress KEnter [MMeta]
    parseJustSpec keyPressP "M-S-Enter" $ KeyPress KEnter [MMeta, MShift]
    parseJustSpec keyPressP "enter" $ KeyPress KEnter []
    parseJustSpec keyPressP "m-enter" $ KeyPress KEnter [MMeta]
    parseJustSpec keyPressP "m-s-enter" $ KeyPress KEnter [MMeta, MShift]
    parseJustSpec keyPressP "F12" $ KeyPress (KFun 12) []
    parseJustSpec keyPressP "M-F12" $ KeyPress (KFun 12) [MMeta]
    parseJustSpec keyPressP "M-S-F12" $ KeyPress (KFun 12) [MMeta, MShift]
    parseJustSpec keyPressP "f12" $ KeyPress (KFun 12) []
    parseJustSpec keyPressP "m-f12" $ KeyPress (KFun 12) [MMeta]
    parseJustSpec keyPressP "m-S-f12" $ KeyPress (KFun 12) [MMeta, MShift]
    parseNothingSpec keyPressP "Enbler"
    parseNothingSpec keyPressP "Tal"
    parseNothingSpec keyPressP "maB"
  describe "renderKeyPress" $ do
    it "renders the something that keyPressP can parse to the same thing" $
      forAllValid $ \k -> parseJust keyPressP (renderKeyPress k) k
  eqSpecOnValid @MatcherConfig
  genValidSpec @MatcherConfig
  jsonSpecOnValid @MatcherConfig
  describe "matcherConfigP" $ do
    parsesValidSpec matcherConfigP matcherConfigText
    parseJustSpec matcherConfigP "<any>" MatchConfCatchAll
    parseJustSpec matcherConfigP "<char>" MatchConfAnyChar
    describe "single keypress" $ do
      parseJustSpec matcherConfigP "a" $ MatchConfKeyPress $ KeyPress (KChar 'a') []
      parseJustSpec matcherConfigP "M-a" $ MatchConfKeyPress $ KeyPress (KChar 'a') [MMeta]
      parseJustSpec matcherConfigP "M-S-a" $
        MatchConfKeyPress $ KeyPress (KChar 'a') [MMeta, MShift]
      parseJustSpec matcherConfigP "A" $ MatchConfKeyPress $ KeyPress (KChar 'A') []
      parseJustSpec matcherConfigP "m-a" $ MatchConfKeyPress $ KeyPress (KChar 'a') [MMeta]
      parseJustSpec matcherConfigP "M-s-A" $
        MatchConfKeyPress $ KeyPress (KChar 'A') [MMeta, MShift]
      parseJustSpec matcherConfigP "Enter" $ MatchConfKeyPress $ KeyPress KEnter []
      parseJustSpec matcherConfigP "M-Enter" $ MatchConfKeyPress $ KeyPress KEnter [MMeta]
      parseJustSpec matcherConfigP "M-S-Enter" $ MatchConfKeyPress $ KeyPress KEnter [MMeta, MShift]
      parseJustSpec matcherConfigP "enter" $ MatchConfKeyPress $ KeyPress KEnter []
      parseJustSpec matcherConfigP "m-enter" $ MatchConfKeyPress $ KeyPress KEnter [MMeta]
      parseJustSpec matcherConfigP "m-s-enter" $ MatchConfKeyPress $ KeyPress KEnter [MMeta, MShift]
      parseJustSpec matcherConfigP "F12" $ MatchConfKeyPress $ KeyPress (KFun 12) []
      parseJustSpec matcherConfigP "M-F12" $ MatchConfKeyPress $ KeyPress (KFun 12) [MMeta]
      parseJustSpec matcherConfigP "M-S-F12" $
        MatchConfKeyPress $ KeyPress (KFun 12) [MMeta, MShift]
      parseJustSpec matcherConfigP "f12" $ MatchConfKeyPress $ KeyPress (KFun 12) []
      parseJustSpec matcherConfigP "m-f12" $ MatchConfKeyPress $ KeyPress (KFun 12) [MMeta]
      parseJustSpec matcherConfigP "m-S-f12" $
        MatchConfKeyPress $ KeyPress (KFun 12) [MMeta, MShift]
    describe "multi-keypress" $ do
      let ab =
            MatchConfCombination
              (KeyPress (KChar 'a') [])
              (MatchConfKeyPress $ KeyPress (KChar 'b') [])
      parseJustSpec matcherConfigP "ab" ab
      parseJustSpec matcherConfigP "a b" ab
      let abc =
            MatchConfCombination
              (KeyPress (KChar 'a') [])
              (MatchConfCombination
                 (KeyPress (KChar 'b') [])
                 (MatchConfKeyPress $ KeyPress (KChar 'c') []))
      parseJustSpec matcherConfigP "abc" abc
      parseJustSpec matcherConfigP "a bc" abc
      parseJustSpec matcherConfigP "ab c" abc
      parseJustSpec matcherConfigP "a b c" abc
      let abcd =
            MatchConfCombination
              (KeyPress (KChar 'a') [])
              (MatchConfCombination
                 (KeyPress (KChar 'b') [])
                 (MatchConfCombination
                    (KeyPress (KChar 'c') [])
                    (MatchConfKeyPress $ KeyPress (KChar 'd') [])))
      parseJustSpec matcherConfigP "abcd" abcd
      parseJustSpec matcherConfigP "a bcd" abcd
      parseJustSpec matcherConfigP "ab cd" abcd
      parseJustSpec matcherConfigP "abc d" abcd
      parseJustSpec matcherConfigP "a b cd" abcd
      parseJustSpec matcherConfigP "a bc d" abcd
      parseJustSpec matcherConfigP "ab c d" abcd
      parseJustSpec matcherConfigP "a b c d" abcd
      parseJustSpec matcherConfigP "M-ab" $
        MatchConfCombination
          (KeyPress (KChar 'a') [MMeta])
          (MatchConfKeyPress (KeyPress (KChar 'b') []))
      parseJustSpec matcherConfigP "M-S-cde" $
        MatchConfCombination
          (KeyPress (KChar 'c') [MMeta, MShift])
          (MatchConfCombination
             (KeyPress (KChar 'd') [])
             (MatchConfKeyPress $ KeyPress (KChar 'e') []))
      parseJustSpec matcherConfigP "M-S-c<any>" $
        MatchConfCombination (KeyPress (KChar 'c') [MMeta, MShift]) MatchConfCatchAll
      parseJustSpec matcherConfigP "M-S-c<char>" $
        MatchConfCombination (KeyPress (KChar 'c') [MMeta, MShift]) MatchConfAnyChar
  describe "renderMatcherConfig" $ do
    it "renders the something that matcherConfigP can parse to the same thing" $
      forAllValid $ \k -> parseJust matcherConfigP (renderMatcherConfig k) k

matcherConfigText :: Gen Text
matcherConfigText = genValid

keyPressText :: Gen Text
keyPressText = genValid

keyText :: Gen Text
keyText = genValid

modText :: Gen Text
modText = elements ["S", "C", "M", "A"]

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
