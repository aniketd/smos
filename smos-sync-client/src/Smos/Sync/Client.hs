{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeOperators #-}

module Smos.Sync.Client
  ( smosSyncClient
  ) where

import GHC.Generics (Generic)

import Data.Aeson as JSON
import Data.ByteString (ByteString)
import qualified Data.ByteString as SB
import qualified Data.ByteString.Lazy as LB
import Data.Hashable
import Data.Map (Map)
import qualified Data.Map as M
import Data.Maybe
import Data.UUID as UUID (UUID)
import Text.Show.Pretty

import Control.Monad

import System.Environment
import System.Exit
import qualified System.FilePath as FP

import Servant.Client

import Path
import Path.IO

import Data.Mergeful

import Network.HTTP.Client as HTTP

import Smos.Sync.API

smosSyncClient :: IO ()
smosSyncClient = do
  (metaFileFP:dirFP:_) <- getArgs
  metaFile <- resolveFile' metaFileFP
  dir <- resolveDir' dirFP
  clientStore <- readClientStore metaFile dir
  man <- HTTP.newManager HTTP.defaultManagerSettings
  burl <- parseBaseUrl "localhost:8000"
  let cenv = mkClientEnv man burl
  let req = makeSyncRequest clientStore
  pPrint req
  errOrResp <- runClient cenv $ clientSync req
  resp <-
    case errOrResp of
      Left err -> die $ show err
      Right resp -> pure resp
  pPrint resp
  saveClientStore metaFile dir $ mergeSyncResponseIgnoreProblems clientStore resp

runClient :: ClientEnv -> ClientM a -> IO (Either ServantError a)
runClient = flip runClientM

clientSync :: SyncRequest UUID SyncFile -> ClientM (SyncResponse UUID SyncFile)
clientSync = client syncAPI

readClientStore :: Path Abs File -> Path Abs Dir -> IO (ClientStore UUID SyncFile)
readClientStore metaFile dir = do
  meta <- readStoreMeta metaFile
  files <- readSyncFiles dir
  pure $ consolidateMetaWithFiles meta files

newtype ClientMetaData =
  ClientMetaData
    { clientMetaDataMap :: Map (Path Rel File) SyncFileMeta
    }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data SyncFileMeta =
  SyncFileMeta
    { syncFileMetaUUID :: UUID
    , syncFileMetaHash :: Int
    , syncFileMetaTime :: ServerTime
    }
  deriving (Show, Eq, Generic)

instance FromJSON SyncFileMeta where
  parseJSON =
    withObject "SyncFileMeta" $ \o -> SyncFileMeta <$> o .: "uuid" <*> o .: "hash" <*> o .: "time"

instance ToJSON SyncFileMeta where
  toJSON SyncFileMeta {..} =
    object ["uuid" .= syncFileMetaUUID, "hash" .= syncFileMetaHash, "time" .= syncFileMetaTime]

readStoreMeta :: Path Abs File -> IO ClientMetaData
readStoreMeta p = do
  mContents <- forgivingAbsence $ LB.readFile $ toFilePath p
  case mContents of
    Nothing -> pure $ ClientMetaData {clientMetaDataMap = M.empty}
    Just contents ->
      case JSON.eitherDecode contents of
        Left err -> die err
        Right store -> pure store

readSyncFiles :: Path Abs Dir -> IO (Map (Path Rel File) ByteString)
readSyncFiles dir = do
  files <- snd <$> listDirRecur dir
  fmap (M.fromList . catMaybes) $
    forM files $ \file ->
      case stripProperPrefix dir file of
        Nothing -> pure Nothing
        Just rfile -> Just <$> ((,) rfile <$> SB.readFile (toFilePath file))

consolidateMetaWithFiles ::
     ClientMetaData -> Map (Path Rel File) ByteString -> ClientStore UUID SyncFile
consolidateMetaWithFiles ClientMetaData {..} contentsMap
  -- The existing files need to be checked for deletions and changes.
 =
  let go1 :: ClientStore UUID SyncFile -> Path Rel File -> SyncFileMeta -> ClientStore UUID SyncFile
      go1 s rf SyncFileMeta {..} =
        case M.lookup rf contentsMap of
          Nothing
           -- The file is not there, that means that it must have been deleted.
           ->
            s
              { clientStoreDeletedItems =
                  M.insert syncFileMetaUUID syncFileMetaTime $ clientStoreDeletedItems s
              }
          Just contents
           -- The file is there, so we need to check if it has changed.
           -- We will trust hashing. (TODO do we need to fix that?)
           ->
            if hash contents == syncFileMetaHash
               -- If it hasn't changed, it's still synced.
              then s
                     { clientStoreSyncedItems =
                         M.insert
                           syncFileMetaUUID
                           (Timed
                              { timedValue =
                                  SyncFile {syncFilePath = rf, syncFileContents = contents}
                              , timedTime = syncFileMetaTime
                              }) $
                         clientStoreSyncedItems s
                     }
               -- If it has changed, mark it as such
              else s
                     { clientStoreSyncedButChangedItems =
                         M.insert
                           syncFileMetaUUID
                           (Timed
                              { timedValue =
                                  SyncFile {syncFilePath = rf, syncFileContents = contents}
                              , timedTime = syncFileMetaTime
                              }) $
                         clientStoreSyncedButChangedItems s
                     }
      syncedChangedAndDeleted = M.foldlWithKey go1 emptyClientStore clientMetaDataMap
      go2 :: ClientStore UUID SyncFile -> Path Rel File -> ByteString -> ClientStore UUID SyncFile
      go2 s rf contents =
        s
          { clientStoreAddedItems =
              SyncFile {syncFilePath = rf, syncFileContents = contents} : clientStoreAddedItems s
          }
   in M.foldlWithKey go2 syncedChangedAndDeleted (contentsMap `M.difference` clientMetaDataMap)

-- TODO this could be optimised using the sync response
saveClientStore :: Path Abs File -> Path Abs Dir -> ClientStore UUID SyncFile -> IO ()
saveClientStore metaFile dir store = do
  saveMeta metaFile $ makeClientMetaData store
  saveSyncFiles dir store

-- | We only check the synced items, because it should be the case that
-- they're the only ones that are not empty.
makeClientMetaData :: ClientStore UUID SyncFile -> ClientMetaData
makeClientMetaData ClientStore {..} =
  if not
       (null clientStoreAddedItems &&
        null clientStoreDeletedItems && null clientStoreSyncedButChangedItems)
    then error "Should not happen."
    else let go ::
                  Map (Path Rel File) SyncFileMeta
               -> UUID
               -> Timed SyncFile
               -> Map (Path Rel File) SyncFileMeta
             go m u Timed {..} =
               let SyncFile {..} = timedValue
                in M.insert
                     syncFilePath
                     SyncFileMeta
                       { syncFileMetaUUID = u
                       , syncFileMetaTime = timedTime
                       , syncFileMetaHash = hash syncFileContents
                       }
                     m
          in ClientMetaData $ M.foldlWithKey go M.empty clientStoreSyncedItems

saveMeta :: Path Abs File -> ClientMetaData -> IO ()
saveMeta p store = encodeFile (toFilePath p) store

saveSyncFiles :: Path Abs Dir -> ClientStore UUID SyncFile -> IO ()
saveSyncFiles dir store = do
  tmpDir1 <- resolveDir' $ FP.dropTrailingPathSeparator (toFilePath dir) ++ "-tmp1"
  tmpDir2 <- resolveDir' $ FP.dropTrailingPathSeparator (toFilePath dir) ++ "-tmp2"
  writeAllTo tmpDir1
  renameDir dir tmpDir2
  renameDir tmpDir1 dir
  removeDirRecur tmpDir2
  where
    writeAllTo d = do
      ensureDir d
      void $ M.traverseWithKey go (makeContentsMap store)
      where
        go p bs = SB.writeFile (fromAbsFile (d </> p)) bs

makeContentsMap :: ClientStore UUID SyncFile -> Map (Path Rel File) ByteString
makeContentsMap ClientStore {..} =
  M.fromList $
  map (\SyncFile {..} -> (syncFilePath, syncFileContents)) $
  concat
    [ clientStoreAddedItems
    , M.elems $ M.map timedValue clientStoreSyncedItems
    , M.elems $ M.map timedValue clientStoreSyncedButChangedItems
    ]
