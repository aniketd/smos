{-# LANGUAGE TypeApplications #-}

module Smos.Cursor.ContentsSpec where

import Test.Hspec
import Test.Validity

import Cursor.Types

import Smos.Data.Gen ()

import Smos.Cursor.Contents
import Smos.Cursor.Contents.Gen ()

spec :: Spec
spec = do
  eqSpecOnValid @ContentsCursor
  genValidSpec @ContentsCursor
  describe "makeContentsCursor" $
    it "produces valid cursors" $ producesValidsOnValids makeContentsCursor
  describe "rebuildContentsCursor" $ do
    it "produces valid cursors" $ producesValidsOnValids rebuildContentsCursor
    it "is the inverse of makeContentsCursor" $
      inverseFunctionsOnValid makeContentsCursor rebuildContentsCursor
  describe "makeContentsCursorWithSelection" $ do
    it "produces valid cursors" $
      producesValidsOnValids3 makeContentsCursorWithSelection
    it "rebuilds the current cursor when given the current selection" $
      forAllValid $ \cc ->
        let (x, y) = contentsCursorSelection cc
         in makeContentsCursorWithSelection x y (rebuildContentsCursor cc) `shouldBe`
            Just cc
  describe "contentsCursorSelection" $
    it "produces valid cursors" $ producesValidsOnValids contentsCursorSelection
  describe "contentsCursorSelectPrevLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectPrevLine
  describe "contentsCursorSelectNextLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectNextLine
  describe "contentsCursorSelectFirstLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectFirstLine
  describe "contentsCursorSelectLastLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectLastLine
  describe "contentsCursorSelectPrevChar" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectPrevChar
  describe "contentsCursorSelectNextChar" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectNextChar
  describe "contentsCursorIndexOnLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorIndexOnLine
  describe "contentsCursorSelectIndexOnLine" $
    it "produces valid cursors" $
    producesValidsOnValids2 contentsCursorSelectIndexOnLine
  describe "contentsCursorInsertChar" $
    it "produces valid cursors" $
    producesValidsOnValids2 contentsCursorInsertChar
  describe "contentsCursorAppendChar" $
    it "produces valid cursors" $
    producesValidsOnValids2 contentsCursorAppendChar
  describe "contentsCursorInsertNewline" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorInsertNewline
  describe "contentsCursorAppendNewline" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorAppendNewline
  describe "contentsCursorRemove" $ do
    it "produces valid cursors" $ producesValidsOnValids contentsCursorRemove
    it "removes the contents cursor if the contents cursor was empty" $
      contentsCursorRemove emptyContentsCursor `shouldBe` Just Deleted
  describe "contentsCursorDelete" $ do
    it "produces valid cursors" $ producesValidsOnValids contentsCursorDelete
    it "removes the contents cursor if the contents cursor was empty" $
      contentsCursorDelete emptyContentsCursor `shouldBe` Just Deleted
  describe "contentsCursorSelectStartOfLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectStartOfLine
  describe "contentsCursorSelectEndOfLine" $
    it "produces valid cursors" $
    producesValidsOnValids contentsCursorSelectEndOfLine
