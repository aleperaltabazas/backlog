{-# LANGUAGE OverloadedStrings #-}

module Backlog.TUI (runTUI) where

import Brick
import Brick.Widgets.Border (borderWithLabel, hBorder)
import Brick.Widgets.Center (centerLayer)
import qualified Brick.Widgets.List as BL
import qualified Brick.Widgets.Edit as E
import qualified Graphics.Vty as V
import qualified Data.Map.Strict as Map
import qualified Data.Vector as Vec
import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (fromMaybe)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)

import Backlog.Types
import Backlog.FileIO (writeTask, deleteTask, moveTask)
import Backlog.Slug (toSlug, makeUniqueSlug)
import Backlog.Widgets.Board (renderBoard)
import Backlog.Widgets.TaskDetail (renderTaskDetail)
import Backlog.Widgets.NewTask (renderNewTask)
import Backlog.Widgets.Confirm (renderConfirm)

-- --------------------------------------------------------------------------
-- State

data AppState = AppState
  { taskLists     :: Map.Map Column (BL.List ResourceName Task)
  , focusedColumn :: Column
  , activeWidget  :: ActiveWidget
  , backlogRoot   :: FilePath
  , statusMessage :: Maybe Text
  , newTaskEdit   :: E.Editor Text ResourceName
  , confirmTarget :: Maybe Task
  , editTarget    :: Maybe Task
  , editIsTitle   :: Bool
  , editEditor    :: E.Editor Text ResourceName
  }

mkInitialState :: FilePath -> Board -> AppState
mkInitialState root b = AppState
  { taskLists     = lists
  , focusedColumn = pickFocus lists Backlog
  , activeWidget  = BoardWidget
  , backlogRoot   = root
  , statusMessage = Nothing
  , newTaskEdit   = E.editor NewTaskEditorName (Just 1) ""
  , confirmTarget = Nothing
  , editTarget    = Nothing
  , editIsTitle   = True
  , editEditor    = E.editor EditEditorName (Just 1) ""
  }
  where
    lists = Map.mapWithKey (\col tasks -> BL.list (TaskListName col) (Vec.fromList tasks) 1) b

-- --------------------------------------------------------------------------
-- App

theApp :: App AppState () ResourceName
theApp = App
  { appDraw         = drawUI
  , appChooseCursor = showFirstCursor
  , appHandleEvent  = handleEvent
  , appStartEvent   = return ()
  , appAttrMap      = const (attrMap V.defAttr [])
  }

runTUI :: FilePath -> Board -> IO ()
runTUI root b = do
  _ <- defaultMain theApp (mkInitialState root b)
  return ()

-- --------------------------------------------------------------------------
-- Drawing

drawUI :: AppState -> [Widget ResourceName]
drawUI st =
  let boardW  = renderBoard (taskLists st) (focusedColumn st)
      helpBar = txt "[n] new  [shift+←/→] move  [enter] open  [d] delete  [q] quit"
      base    = vBox [boardW, hBorder, helpBar]
  in case activeWidget st of
       BoardWidget   -> [base]
       DetailWidget  -> maybe [base] (\t -> [renderTaskDetail t, base]) (selectedTask st)
       NewTaskWidget -> [renderNewTask (newTaskEdit st), base]
       EditWidget    -> [renderEditOverlay st, base]
       ConfirmWidget -> maybe [base] (\t -> [renderConfirm t, base]) (confirmTarget st)

selectedTask :: AppState -> Maybe Task
selectedTask st =
  fmap snd $ BL.listSelectedElement (taskLists st Map.! focusedColumn st)

-- --------------------------------------------------------------------------
-- Event handling

handleEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleEvent ev = do
  st <- get
  case activeWidget st of
    BoardWidget   -> handleBoardEvent ev
    DetailWidget  -> handleDetailEvent ev
    NewTaskWidget -> handleNewTaskEvent ev
    EditWidget    -> handleEditEvent ev
    ConfirmWidget -> handleConfirmEvent ev

-- Board

handleBoardEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleBoardEvent (VtyEvent vtye) = case vtye of
  V.EvKey (V.KChar 'q') []         -> halt
  V.EvKey V.KEsc        []         -> halt
  V.EvKey (V.KChar 'n') []         -> modify $ \s ->
    s { activeWidget = NewTaskWidget
      , newTaskEdit  = E.editor NewTaskEditorName (Just 1) "" }
  V.EvKey V.KEnter      []         -> do
    st <- get
    case selectedTask st of
      Nothing -> return ()
      Just _  -> modify $ \s -> s { activeWidget = DetailWidget }
  V.EvKey (V.KChar 'd') []         -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task -> modify $ \s -> s { activeWidget = ConfirmWidget, confirmTarget = Just task }
  V.EvKey V.KLeft       []         -> modify $ \s -> s { focusedColumn = prevCol (focusedColumn s) }
  V.EvKey V.KRight      []         -> modify $ \s -> s { focusedColumn = nextCol (focusedColumn s) }
  V.EvKey V.KUp         []         -> handleListNav vtye
  V.EvKey V.KDown       []         -> handleListNav vtye
  V.EvKey V.KLeft  [V.MShift]      -> get >>= \st -> shiftTask st prevCol
  V.EvKey V.KRight [V.MShift]      -> get >>= \st -> shiftTask st nextCol
  V.EvKey (V.KChar 'e') []         -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task ->
        modify $ \s -> s
          { activeWidget = EditWidget
          , editTarget   = Just task
          , editIsTitle  = True
          , editEditor   = E.editor EditEditorName (Just 1) (taskTitle task) }
  _                                -> return ()
handleBoardEvent _ = return ()

-- Detail

handleDetailEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleDetailEvent (VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc        [] -> modify $ \s -> s { activeWidget = BoardWidget }
  V.EvKey (V.KChar 'q') [] -> halt
  V.EvKey (V.KChar 'e') [] -> do
    st <- get
    case selectedTask st of
      Nothing   -> return ()
      Just task ->
        modify $ \s -> s
          { activeWidget = EditWidget
          , editTarget   = Just task
          , editIsTitle  = False
          , editEditor   = E.editor EditEditorName Nothing (taskDescription task) }
  _                        -> return ()
handleDetailEvent _ = return ()

-- NewTask

handleNewTaskEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleNewTaskEvent ev@(VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc   [] -> modify $ \s -> s { activeWidget = BoardWidget }
  V.EvKey V.KEnter [] -> do
    st <- get
    let title = T.strip $ mconcat $ E.getEditContents (newTaskEdit st)
    if T.null title
      then return ()
      else do
        let existingSlugs = map taskSlug $ concatMap (Vec.toList . BL.listElements) $ Map.elems (taskLists st)
            slug          = makeUniqueSlug existingSlugs (toSlug title)
            col           = focusedColumn st
            task          = Task slug title "" col
        liftIO $ writeTask (backlogRoot st) task
        modify $ \s ->
          let lst  = taskLists s Map.! col
              lst' = BL.listInsert (Vec.length (BL.listElements lst)) task lst
          in s { taskLists = Map.insert col lst' (taskLists s), activeWidget = BoardWidget }
  _ -> do
    st <- get
    newEd <- nestEventM' (newTaskEdit st) (E.handleEditorEvent ev)
    modify $ \s -> s { newTaskEdit = newEd }
handleNewTaskEvent _ = return ()

-- Confirm

handleConfirmEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleConfirmEvent (VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc        [] -> dismiss
  V.EvKey (V.KChar 'n') [] -> dismiss
  V.EvKey (V.KChar 'y') [] -> do
    st <- get
    case confirmTarget st of
      Nothing   -> dismiss
      Just task -> do
        liftIO $ deleteTask (backlogRoot st) task
        modify $ \s ->
          let col     = taskColumn task
              lst0    = taskLists s Map.! col
              idx     = fromMaybe 0 $
                          Vec.findIndex (\t -> taskSlug t == taskSlug task)
                                        (BL.listElements lst0)
              lst     = BL.listRemove idx lst0
              lists'  = Map.insert col lst (taskLists s)
          in s { taskLists     = lists'
               , focusedColumn = pickFocus lists' col
               , activeWidget  = BoardWidget
               , confirmTarget = Nothing }
  _ -> return ()
  where dismiss = modify $ \s -> s { activeWidget = BoardWidget, confirmTarget = Nothing }
handleConfirmEvent _ = return ()

-- Edit

handleEditEvent :: BrickEvent ResourceName () -> EventM ResourceName AppState ()
handleEditEvent ev@(VtyEvent vtye) = case vtye of
  V.EvKey V.KEsc   [] -> modify $ \s -> s { activeWidget = BoardWidget, editTarget = Nothing }
  V.EvKey V.KEnter [] -> do
    st <- get
    case editTarget st of
      Nothing   -> modify $ \s -> s { activeWidget = BoardWidget }
      Just task -> do
        let newText = T.strip $ mconcat $ E.getEditContents (editEditor st)
        if T.null newText
          then return ()
          else do
            let updated = if editIsTitle st
                          then task { taskTitle = newText }
                          else task { taskDescription = newText }
            liftIO $ writeTask (backlogRoot st) updated
            modify $ \s ->
              let col = taskColumn task
                  lst = taskLists s Map.! col
                  updateTask t = if taskSlug t == taskSlug task then updated else t
                  lst' = BL.listModify updateTask lst
              in s { taskLists    = Map.insert col lst' (taskLists s)
                   , activeWidget  = BoardWidget
                   , editTarget    = Nothing }
  _ -> do
    st <- get
    newEd <- nestEventM' (editEditor st) (E.handleEditorEvent ev)
    modify $ \s -> s { editEditor = newEd }
handleEditEvent _ = return ()

renderEditOverlay :: AppState -> Widget ResourceName
renderEditOverlay st =
  let label = if editIsTitle st then " Edit title " else " Edit description "
  in centerLayer $
     borderWithLabel (txt label) $
     padAll 1 $
     vBox
       [ E.renderEditor (vBox . map txt) True (editEditor st)
       , txt ""
       , txt "[enter] save  [esc] cancel"
       ]

-- --------------------------------------------------------------------------
-- Helpers

pickFocus :: Map.Map Column (BL.List ResourceName Task) -> Column -> Column
pickFocus lists preferred
  | notEmpty (lists Map.! preferred) = preferred
  | otherwise =
      case filter (notEmpty . (lists Map.!)) [minBound .. maxBound] of
        []    -> preferred
        (c:_) -> c
  where notEmpty lst = not (Vec.null (BL.listElements lst))

handleListNav :: V.Event -> EventM ResourceName AppState ()
handleListNav vtye = do
  st <- get
  let col = focusedColumn st
  newLst <- nestEventM' (taskLists st Map.! col) (BL.handleListEvent vtye)
  modify $ \s -> s { taskLists = Map.insert col newLst (taskLists s) }

shiftTask :: AppState -> (Column -> Column) -> EventM ResourceName AppState ()
shiftTask st colFn = do
  let col    = focusedColumn st
      newCol = colFn col
  when (newCol /= col) $
    case BL.listSelectedElement (taskLists st Map.! col) of
      Nothing        -> return ()
      Just (idx, task) -> do
        moved <- liftIO $ moveTask (backlogRoot st) task newCol
        modify $ \s ->
          let srcList  = BL.listRemove idx (taskLists s Map.! col)
              insertAt = Vec.length (BL.listElements (taskLists s Map.! newCol))
              dstList  = BL.listMoveTo insertAt $
                           BL.listInsert insertAt moved (taskLists s Map.! newCol)
          in s { taskLists     = Map.insert col srcList $ Map.insert newCol dstList (taskLists s)
               , focusedColumn = newCol }

prevCol :: Column -> Column
prevCol Backlog = Backlog
prevCol WIP     = Backlog
prevCol Done    = WIP

nextCol :: Column -> Column
nextCol Backlog = WIP
nextCol WIP     = Done
nextCol Done    = Done
