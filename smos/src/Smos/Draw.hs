{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Smos.Draw
  ( smosDraw
  ) where

import Import hiding ((<+>))

import qualified Data.List.NonEmpty as NE
import qualified Data.Map as M
import qualified Data.Text as T
import Data.Time
import Text.Time.Pretty

import Brick.Types as B
import Brick.Widgets.Border as B
import Brick.Widgets.Center as B
import Brick.Widgets.Core as B
import Brick.Widgets.Core ((<+>))

import Lens.Micro

import Cursor.FuzzyDay
import Cursor.Map
import Cursor.Simple.List.NonEmpty
import Cursor.Text
import Cursor.Tree hiding (drawTreeCursor)

import Smos.Data

import Smos.Cursor.Collapse
import Smos.Cursor.Contents
import Smos.Cursor.Entry
import Smos.Cursor.Header
import Smos.Cursor.Logbook
import Smos.Cursor.Properties
import Smos.Cursor.Report.Next
import Smos.Cursor.SmosFile
import Smos.Cursor.StateHistory
import Smos.Cursor.Tag
import Smos.Cursor.Tags
import Smos.Cursor.Timestamps

import Smos.Report.Path

import Smos.Draw.Base
import Smos.Draw.Cursor
import Smos.Draw.Text

import Smos.Keys
import Smos.Style
import Smos.Types

smosDraw :: SmosConfig -> SmosState -> [Widget ResourceName]
smosDraw SmosConfig {..} ss@SmosState {..} =
  let helpCursorWidget = drawHelpCursor (selectWhen HelpSelected) editorCursorHelpCursor
      withHeading hw w =
        vBox [hBox [str "──[ ", (withAttr selectedAttr hw), str " ]──", vLimit 1 $ fill '─'], w]
      fileCursorWidget =
        withHeading (drawFilePath smosStateFilePath) $
        maybe drawInfo (drawFileCursor $ selectWhen FileSelected) editorCursorFileCursor
      reportCursorWidget =
        withHeading (str "Next Action Report") $
        maybe
          (str "empty report")
          (drawReportCursor (selectWhen ReportSelected))
          editorCursorReportCursor
      mainCursorWidget =
        case editorCursorSelection of
          FileSelected -> fileCursorWidget
          ReportSelected -> reportCursorWidget
          HelpSelected -> helpCursorWidget
      debugWidget = [drawDebug ss | editorCursorDebug]
      baseWidget = [vBox $ [mainCursorWidget] ++ debugWidget]
   in baseWidget
  where
    EditorCursor {..} = smosStateCursor
    selectWhen :: EditorSelection -> Select
    selectWhen ecs =
      if ecs == editorCursorSelection
        then MaybeSelected
        else NotSelected
    drawFileCursor :: Select -> SmosFileCursor -> Widget ResourceName
    drawFileCursor s = flip runReader smosStateTime . drawSmosFileCursor s

drawInfo :: Widget n
drawInfo =
  withAttr selectedAttr $
  B.vCenterLayer $
  vBox $
  map
    B.hCenterLayer
    [ str "SMOS"
    , str " "
    , str "version 0.0.0.0"
    , str "by Tom Sydney Kerckhove"
    , str "Smos is open source and freely distributable"
    , str " "
    , str "Building smos takes time, energy and money."
    , str "Please consider supporting the project."
    , str "https://smos.cs-syd.eu/support"
    ]

drawHelpCursor :: Select -> Maybe HelpCursor -> Widget ResourceName
drawHelpCursor _ Nothing = drawInfo
drawHelpCursor s (Just HelpCursor {..}) =
  centerLayer $
  borderWithLabel (withAttr selectedAttr $ txt ("[Help page: " <> helpCursorTitle <> "]")) $
  hBox
    [ vBox
        [ padAll 1 $
          viewport "viewport-help" Vertical $
          case helpCursorSelectedKeyHelpCursors of
            Nothing -> txtWrap "No matching keybindings found."
            Just hcs -> drawVerticalNonEmptyCursorTable (go NotSelected) (go s) (go NotSelected) hcs
        , hBox [drawText "Search: ", drawTextCursor MaybeSelected helpCursorSearchBar]
        ]
    , vBorder
    , padAll 1 $
      case helpCursorSelectedKeyHelpCursors of
        Nothing -> emptyWidget
        Just hcs ->
          let KeyHelpCursor {..} = nonEmptyCursorCurrent hcs
           in vBox
                [ txt "Name: " <+>
                  withAttr selectedAttr (drawText $ actionNameText keyHelpCursorName)
                , txt "Description: "
                , hLimit 75 $
                  padRight Max $ withAttr helpDescriptionAttr $ drawText keyHelpCursorDescription
                ]
    ]
  where
    go :: Select -> KeyHelpCursor -> [Widget n]
    go s_ KeyHelpCursor {..} =
      let msel =
            (case s_ of
               MaybeSelected -> forceAttr selectedAttr . visible
               NotSelected -> id)
       in [ hBox $
            intersperse (str ", ") $
            map (withAttr helpKeyCombinationAttr . drawKeyCombination) keyHelpCursorKeyBinding
          , msel $ withAttr helpNameAttr $ drawText $ actionNameText keyHelpCursorName
          ]

drawKeyCombination :: KeyCombination -> Widget n
drawKeyCombination = txt . go
  where
    go :: KeyCombination -> Text
    go (PressExactly kp) = renderKeyPress kp
    go PressAnyChar = "<any char>"
    go PressAny = "<any key>"
    go (PressCombination kp km) = renderKeyPress kp <> go km

drawHistory :: Seq KeyPress -> Widget n
drawHistory = txtWrap . T.unwords . map renderKeyPress . toList

drawDebug :: SmosState -> Widget n
drawDebug SmosState {..} =
  vBox
    [ str "Key history: " <+> drawHistory smosStateKeyHistory
    , str "Last match: " <+>
      fromMaybe emptyWidget (drawLastMatches (debugInfoLastMatches smosStateDebugInfo))
    , strWrap $ ppShow smosStateCursor
    ]

drawLastMatches :: Maybe (NonEmpty ActivationDebug) -> Maybe (Widget n)
drawLastMatches Nothing = Nothing
drawLastMatches (Just ts) = Just $ vBox $ map (strWrap . ppShow) $ NE.toList ts

defaultPadding :: Padding
defaultPadding = Pad 2

drawReportCursor :: Select -> ReportCursor -> Widget ResourceName
drawReportCursor s rc =
  viewport "viewport-report" Vertical $
  case rc of
    ReportNextActions narc -> drawNextActionReportCursor s narc

drawNextActionReportCursor :: Select -> NextActionReportCursor -> Widget ResourceName
drawNextActionReportCursor s =
  drawVerticalNonEmptyCursor
    (drawNextActionEntryCursor NotSelected)
    (drawNextActionEntryCursor s)
    (drawNextActionEntryCursor NotSelected)

drawNextActionEntryCursor :: Select -> NextActionEntryCursor -> Widget ResourceName
drawNextActionEntryCursor s naec@NextActionEntryCursor {..} =
  let e@Entry {..} = naec ^. nextActionEntryCursorEntryL
      sel =
        (case s of
           MaybeSelected -> forceAttr selectedAttr . visible
           NotSelected -> id)
   in hBox $
      intersperse (str " ") $
      [ hLimit 20 $
        padRight Max $
        drawFilePath $
        case nextActionEntryCursorFilePath of
          Relative _ rf -> filename rf
          Absolute af -> filename af
      , maybe emptyWidget drawTodoState $ entryState e
      , sel $ drawHeader entryHeader
      ]

drawSmosFileCursor :: Select -> SmosFileCursor -> Drawer
drawSmosFileCursor s =
  fmap (viewport "viewport-file" Vertical) .
  drawVerticalForestCursor drawEntryCTree (drawSmosTreeCursor s) drawEntryCTree

drawSmosTreeCursor ::
     Select -> TreeCursor (CollapseEntry EntryCursor) (CollapseEntry Entry) -> Drawer
drawSmosTreeCursor s = drawTreeCursorM wrap cur
  where
    cur :: CollapseEntry EntryCursor -> CForest (CollapseEntry Entry) -> Drawer
    cur ec cf =
      case cf of
        EmptyCForest -> drawEntryCursor s TreeIsNotCollapsed ec
        ClosedForest _ -> drawEntryCursor s TreeIsCollapsed ec
        OpenForest ts -> do
          ecw <- drawEntryCursor s TreeIsNotCollapsed ec
          etws <- mapM drawEntryCTree $ NE.toList ts
          pure $ ecw <=> padLeft defaultPadding (vBox etws)
    wrap ::
         [CTree (CollapseEntry Entry)]
      -> CollapseEntry Entry
      -> [CTree (CollapseEntry Entry)]
      -> Widget ResourceName
      -> Drawer
    wrap tsl e tsr w = do
      befores <- mapM drawEntryCTree tsl
      ew <- drawEntry TreeIsNotCollapsed e
      afters <- mapM drawEntryCTree tsr
      pure $ ew <=> padLeft defaultPadding (vBox $ concat [befores, [w], afters])

drawEntryCTree :: CTree (CollapseEntry Entry) -> Drawer
drawEntryCTree (CNode t cf) =
  case cf of
    EmptyCForest -> drawEntry TreeIsNotCollapsed t
    ClosedForest _ -> drawEntry TreeIsCollapsed t
    OpenForest ts -> do
      ew <- drawEntry TreeIsNotCollapsed t
      etws <- mapM drawEntryCTree $ NE.toList ts
      pure $ ew <=> padLeft defaultPadding (vBox etws)

data TreeCollapsing
  = TreeIsNotCollapsed
  | TreeIsCollapsed
  deriving (Show, Eq)

drawEntryCursor :: Select -> TreeCollapsing -> CollapseEntry EntryCursor -> Drawer
drawEntryCursor s tc e = do
  tscw <- forM entryCursorTimestampsCursor $ drawTimestampsCursor (selectWhen TimestampsSelected)
  lbcw <- drawLogbookCursor (selectWhen LogbookSelected) entryCursorLogbookCursor
  shcw <-
    fmap join $
    forM entryCursorStateHistoryCursor $ drawStateHistoryCursor (selectWhen StateHistorySelected)
  pure $
    (case s of
       NotSelected -> id
       MaybeSelected -> visible) $
    vBox $
    catMaybes
      [ Just $
        hBox $
        intersperse (str " ") $
        concat $
        [ [ case s of
              NotSelected -> str "-"
              MaybeSelected -> withAttr selectedAttr $ str ">"
          ]
        , maybeToList (entryCursorStateHistoryCursor >>= drawCurrentStateFromCursor)
        , [drawHeaderCursor (selectWhen HeaderSelected) entryCursorHeaderCursor]
        , maybeToList $ drawTagsCursor (selectWhen TagsSelected) <$> entryCursorTagsCursor
        , [ str "..."
          | let e_ = rebuildEntryCursor ec
             in or
                  [ not (collapseEntryShowContents e) && not (isNothing $ entryContents e_)
                  , not (collapseEntryShowHistory e) &&
                    not (nullStateHistory $ entryStateHistory e_)
                  , not (collapseEntryShowLogbook e) && not (nullLogbook $ entryLogbook e_)
                  ]
          ]
        , [str "+++" | tc == TreeIsCollapsed]
        ]
      , drawIfM collapseEntryShowContents $
        drawContentsCursor (selectWhen ContentsSelected) <$> entryCursorContentsCursor
      , tscw
      , drawPropertiesCursor (selectWhen PropertiesSelected) <$> entryCursorPropertiesCursor
      , drawIfM collapseEntryShowHistory shcw
      , drawIfM collapseEntryShowLogbook lbcw
      ]
  where
    ec@EntryCursor {..} = collapseEntryValue e
    drawIfM :: (forall e. CollapseEntry e -> Bool) -> Maybe a -> Maybe a
    drawIfM bf mw = mw >>= drawIf bf
    drawIf :: (forall e. CollapseEntry e -> Bool) -> a -> Maybe a
    drawIf bf w =
      if bf e
        then Just w
        else Nothing
    selectWhen :: EntryCursorSelection -> Select
    selectWhen ecs =
      s <>
      (if ecs == entryCursorSelected
         then MaybeSelected
         else NotSelected)

drawEntry :: TreeCollapsing -> CollapseEntry Entry -> Drawer
drawEntry tc e = do
  tsw <- drawTimestamps entryTimestamps
  lbw <- drawLogbook entryLogbook
  shw <- drawStateHistory entryStateHistory
  pure $
    vBox $
    catMaybes
      [ Just $
        hBox $
        intersperse (str " ") $
        concat
          [ [str "-"]
          , maybeToList (drawCurrentState entryStateHistory)
          , [drawHeader entryHeader]
          , maybeToList (drawTags entryTags)
          , [ str "..."
            | or
                [ not (collapseEntryShowContents e) && not (isNothing entryContents)
                , not (collapseEntryShowHistory e) && not (nullStateHistory entryStateHistory)
                , not (collapseEntryShowLogbook e) && not (nullLogbook entryLogbook)
                ]
            ]
          , [str "+++" | tc == TreeIsCollapsed]
          ]
      , drawIfM collapseEntryShowContents $ drawContents <$> entryContents
      , tsw
      , drawProperties entryProperties
      , drawIfM collapseEntryShowHistory shw
      , drawIfM collapseEntryShowLogbook lbw
      ]
  where
    Entry {..} = collapseEntryValue e
    drawIfM :: (forall e. CollapseEntry e -> Bool) -> Maybe a -> Maybe a
    drawIfM bf mw = mw >>= drawIf bf
    drawIf :: (forall e. CollapseEntry e -> Bool) -> a -> Maybe a
    drawIf bf w =
      if bf e
        then Just w
        else Nothing

drawHeaderCursor :: Select -> HeaderCursor -> Widget ResourceName
drawHeaderCursor s = withAttr headerAttr . drawTextCursor s

drawHeader :: Header -> Widget ResourceName
drawHeader = withAttr headerAttr . drawText . headerText

drawCurrentStateFromCursor :: StateHistoryCursor -> Maybe (Widget ResourceName)
drawCurrentStateFromCursor = drawCurrentState . rebuildStateHistoryCursor . Just

drawCurrentState :: StateHistory -> Maybe (Widget ResourceName)
drawCurrentState stateHistory =
  stateHistoryState stateHistory <&> \ts -> withAttr todoStateAttr $ drawTodoState ts

drawContentsCursor :: Select -> ContentsCursor -> Widget ResourceName
drawContentsCursor = drawTextFieldCursor

drawContents :: Contents -> Widget ResourceName
drawContents = drawText . contentsText

drawTimestampsCursor :: Select -> TimestampsCursor -> Drawer
drawTimestampsCursor s =
  drawVerticalMapCursorM drawTimestamp (drawTimestampKVCursor s) drawTimestamp

drawTimestamps :: Map TimestampName Timestamp -> MDrawer
drawTimestamps m
  | M.null m = pure Nothing
  | otherwise = fmap (Just . vBox) $ mapM (uncurry drawTimestamp) (M.toList m)

drawTimestampKVCursor ::
     Select -> KeyValueCursor TextCursor FuzzyDayCursor TimestampName Timestamp -> Drawer
drawTimestampKVCursor s kvc =
  case kvc of
    KeyValueCursorKey tc ts -> do
      dw <- drawDay $ timestampDay ts
      pure $
        hBox
          [ case s of
              NotSelected -> drawTimestampName $ rebuildTimestampNameCursor tc
              MaybeSelected -> drawTextCursor s tc
          , str ": "
          , dw
          ]
    KeyValueCursorValue tsn fdc -> do
      fdcw <- drawFuzzyDayCursor s fdc
      pure $
        hBox
          [ drawTimestampName tsn
          , str ": "
          , case s of
              NotSelected -> str $ formatTimestampDay $ timestampDay $ rebuildTimestampCursor fdc
              MaybeSelected -> fdcw
          ]

drawTimestamp :: TimestampName -> Timestamp -> Drawer
drawTimestamp tsn ts = do
  dw <- drawDay $ timestampDay ts
  pure $ hBox [drawTimestampName tsn, str ": ", dw]

drawFuzzyDayCursor :: Select -> FuzzyDayCursor -> Drawer
drawFuzzyDayCursor s fdc@FuzzyDayCursor {..} = do
  dw <- drawDay (rebuildFuzzyDayCursor fdc)
  pure $
    (case s of
       NotSelected -> id
       MaybeSelected -> withAttr selectedAttr) $
    hBox $
    intersperse (str " ") $
    [drawTextCursor s fuzzyDayCursorTextCursor] ++
    [hBox [str "(", dw, str ")"] | MaybeSelected <- [s]]

drawTimestampName :: TimestampName -> Widget n
drawTimestampName tsn =
  withAttr (timestampNameSpecificAttr tsn <> timestampNameAttr) . drawText $ timestampNameText tsn

drawDay :: Day -> Drawer
drawDay d = do
  zt@(ZonedTime _ tz) <- ask
  pure $
    hBox
      [ str $ formatTimestampDay d
      , str ", "
      , str $ prettyTimeAuto (zonedTimeToUTC zt) $ localTimeToUTC tz $ LocalTime d midnight
      ]

drawPropertiesCursor :: Select -> PropertiesCursor -> Widget ResourceName
drawPropertiesCursor s =
  drawVerticalMapCursor drawPropertyPair (drawPropertyKVCursor s) drawPropertyPair .
  propertiesCursorMapCursor

drawPropertyKVCursor ::
     Select
  -> KeyValueCursor TextCursor TextCursor PropertyName PropertyValue
  -> Widget ResourceName
drawPropertyKVCursor s kvc =
  let sel =
        (case s of
           NotSelected -> id
           MaybeSelected -> withAttr selectedAttr)
   in case kvc of
        KeyValueCursorKey tc pv ->
          withAttr
            (maybe
               id
               (\pn -> (<>) (propertyNameSpecificAttr pn))
               (propertyName $ rebuildTextCursor tc) $
             propertyNameAttr) $
          hBox [sel $ drawTextCursor s tc, str ": ", drawPropertyValue pv]
        KeyValueCursorValue pn tc ->
          withAttr (propertyNameSpecificAttr pn <> propertyNameAttr) $
          hBox [drawPropertyName pn, str ": ", sel $ drawTextCursor s tc]

drawProperties :: Map PropertyName PropertyValue -> Maybe (Widget ResourceName)
drawProperties m
  | M.null m = Nothing
  | otherwise = Just $ vBox $ map (uncurry drawPropertyPair) $ M.toList m

drawPropertyPair :: PropertyName -> PropertyValue -> Widget ResourceName
drawPropertyPair pn pv =
  withAttr (propertyNameSpecificAttr pn <> propertyNameAttr) $
  hBox [drawPropertyName pn, str ": ", drawPropertyValue pv]

drawPropertyName :: PropertyName -> Widget ResourceName
drawPropertyName = drawText . propertyNameText

drawPropertyValue :: PropertyValue -> Widget ResourceName
drawPropertyValue = drawText . propertyValueText

drawStateHistoryCursor :: Select -> StateHistoryCursor -> MDrawer
drawStateHistoryCursor _ = drawStateHistory . rebuildStateHistoryCursor . Just

drawStateHistory :: StateHistory -> MDrawer
drawStateHistory (StateHistory ls)
  | null ls = pure Nothing
  | otherwise = do
    zt <- ask
    pure $
      Just $
      withAttr todoStateHistoryAttr $
      vBox $
      flip map ls $ \StateHistoryEntry {..} ->
        hBox $
        catMaybes
          [ Just $
            strWrap $
            unwords
              [ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" stateHistoryEntryTimestamp
              , "(" ++ (prettyTimeAuto (zonedTimeToUTC zt) stateHistoryEntryTimestamp) ++ ")"
              ]
          , ((str " " <+>) . drawTodoState) <$> stateHistoryEntryNewState
          ]

drawTagsCursor :: Select -> TagsCursor -> Widget ResourceName
drawTagsCursor s =
  drawHorizontalNonEmptyCursor
    (\t -> str ":" <+> drawTag t)
    (drawTagCursor s)
    (\t -> drawTag t <+> str ":") .
  tagsCursorNonEmptyCursor

drawTags :: [Tag] -> Maybe (Widget ResourceName)
drawTags ts
  | null ts = Nothing
  | otherwise = Just $ str ":" <+> hBox (intersperse (str ":") (map drawTag ts)) <+> str ":"

drawTagCursor :: Select -> TagCursor -> Widget ResourceName
drawTagCursor s =
  (case s of
     NotSelected -> id
     MaybeSelected -> withAttr selectedAttr) .
  (str ":" <+>) . (<+> str ":") . drawTextCursor s . tagCursorTextCursor

drawTag :: Tag -> Widget n
drawTag = drawText . tagText

drawLogbookCursor :: Select -> LogbookCursor -> MDrawer
drawLogbookCursor _ lbc =
  case lbc of
    LogbookCursorClosed Nothing -> pure Nothing
    LogbookCursorClosed (Just ne) -> do
      let lbes = (NE.toList $ rebuildNonEmptyCursor ne)
      md <- drawLogbookEntries lbes
      tw <- drawLogbookTotal Nothing lbes
      pure $ Just $ vBox $ [fromMaybe emptyWidget md] ++ maybeToList tw -- TODO don't use empty widgets
    LogbookCursorOpen u ne -> do
      ow <- drawLogOpen u
      let lbes = (maybe [] (NE.toList . rebuildNonEmptyCursor) ne)
      md <- drawLogbookEntries lbes
      tw <- drawLogbookTotal (Just u) lbes
      pure $ Just $ vBox $ [ow, fromMaybe emptyWidget md] ++ maybeToList tw

drawLogbook :: Logbook -> MDrawer
drawLogbook (LogClosed ls) = do
  md <- drawLogbookEntries ls
  tw <- drawLogbookTotal Nothing ls
  pure $ Just $ vBox $ maybe [] (: []) md ++ maybeToList tw
drawLogbook (LogOpen u ls) = do
  ow <- drawLogOpen u
  md <- drawLogbookEntries ls
  tw <- drawLogbookTotal (Just u) ls
  pure $ Just $ vBox $ [ow, fromMaybe emptyWidget md] ++ maybeToList tw -- TODO don't use empty widgets

drawLogbookEntries :: [LogbookEntry] -> MDrawer
drawLogbookEntries [] = pure Nothing
drawLogbookEntries lbes = (Just . vBox) <$> mapM drawLogbookEntry lbes

drawLogbookTotal :: Maybe UTCTime -> [LogbookEntry] -> MDrawer
drawLogbookTotal Nothing [] = pure Nothing
drawLogbookTotal mopen lbes = do
  openTime <-
    forM mopen $ \open -> do
      now <- asks zonedTimeToUTC
      pure $ diffUTCTime now open
  let total = fromMaybe 0 openTime + sum (map logbookEntryDiffTime lbes)
  pure $
    Just $
    hBox
      [ str "TOTAL: "
      , hLimit (length ("[2018-10-11 00:30:02]--[2018-10-11 00:30:09] = " :: [Char])) $
        vLimit 1 $ fill ' '
      , drawNominalDiffTime total
      ]

drawLogbookEntry :: LogbookEntry -> Drawer
drawLogbookEntry lbe@LogbookEntry {..} = do
  sw <- drawLogbookTimestamp logbookEntryStart
  ew <- drawLogbookTimestamp logbookEntryEnd
  pure $
    hBox
      [str "CLOCK: ", sw, str "--", ew, str " = ", drawNominalDiffTime $ logbookEntryDiffTime lbe]

drawLogOpen :: UTCTime -> Drawer
drawLogOpen u = do
  now <- asks zonedTimeToUTC
  sw <- drawLogbookTimestamp u
  ew <- drawLogbookTimestamp now
  pure $
    withAttr selectedAttr $
    hBox
      [ str "CLOCK: "
      , sw
      , str "--"
      , ew
      , str " = "
      , drawNominalDiffTime $ diffUTCTime now u
      , str " RUNNING"
      ]

drawLogbookTimestamp :: UTCTime -> Drawer
drawLogbookTimestamp utct = do
  tw <- drawUTCLocal utct
  pure $ str "[" <+> tw <+> str "]"

drawTodoState :: TodoState -> Widget ResourceName
drawTodoState ts =
  withAttr (todoStateSpecificAttr ts <> todoStateAttr) . drawText $ todoStateText ts

drawUTCLocal :: UTCTime -> Drawer
drawUTCLocal utct = do
  tz <- asks zonedTimeZone
  let localTime = utcToLocalTime tz utct
  pure $ str (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" localTime)

type DrawEnv = ZonedTime

type MDrawer = Reader DrawEnv (Maybe (Widget ResourceName))

type Drawer = Reader DrawEnv (Widget ResourceName)
