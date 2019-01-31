-- Test the sprite engine from Haskell

module ShowImageB ( updatePeriodGoal
                  , showSpriteTree
                  , initialViewSizeVar, setViewSize
                  ) where

import HSpriteLib
import BaseTypes
import Transform2
import Vector2
import VectorSpace
import Point2
import qualified Win32
import IOExts
import Monad (when)
import Concurrent (writeChan)
import Event (EventChannel, newChannelEvent)
import User
import Word(word32ToInt)
import Int(int32ToInt, Int32)
import RenderImage (importPixelsPerLength, screenPixelsPerLength)

type UserChannel = EventChannel UserAction

-- Window stuff

-- Make a window and route user events

makeWindow :: (Win32.HWND -> IO ())	-- create
	   -> IO ()			-- resize
	   -> IO ()			-- update
	   -> IO ()			-- close
	   -> SpriteTime		-- update goal interval
	   -> UserChannel		-- receives user events
	   -> IO ()


makeWindow createIO resizeIO updateIO closeIO
	   updateInterval userChan =
  let 
      send userEvent = do
        -- Get time now.  Bogus, since the event really happened before
	-- now.
        t <- currentSpriteTime
        --putStrLn ("User event " ++ show (t, userEvent))
        --putStr ("ue " ++ show t ++ " ")
        writeChan userChan (t, Just userEvent)
	return 0

      -- Map lParam mouse point to a Point2
      posn hwnd lParam =
	do (winWidth,winHeight) <- getViewSize hwnd
	   -- putStrLn ("posn " ++ show (w',h'))
	   ( return $
	     let -- Turn window coords into logical coords.
		 -- First compute coords relative to the upper left
		 (yRelWinUL,xRelWinUL)  = lParam `divMod` 65536
		 -- subtract position of window center relative to UL, to get
		 -- coords relative to window center
		 xRelWinCenter = xRelWinUL - winWidth `div` 2
		 yRelWinCenter = yRelWinUL - winHeight `div` 2
	     in
		 -- Throw in scaling, recalling that window positive == down
		 point2XY (fromInt32 xRelWinCenter / screenPixelsPerLength)
			  (fromInt32 yRelWinCenter / -screenPixelsPerLength) )

      fireButtonEvent hwnd lParam isLeft isDown =
	do p <- posn hwnd lParam
	   --putStrLn ("Button " ++ show (isLeft,isDown) ++ " at pos " ++ show p)
	   send (Button isLeft isDown p)

      fireKeyEvent wParam isDown =
	do --putStrLn ("fireKeyEvent " ++ show (wParam, char, isDown, t))
	   send (Key isDown wParam) -- (Win32.VKey wParam)) -- GSL

      wndProc2 hwnd msg wParam lParam

	| msg == Win32.wM_DESTROY = do
          -- Kill the update timer
	  Win32.killTimer (Just hwnd) 1 
	  send Quit

	| msg == Win32.wM_LBUTTONDOWN || msg == Win32.wM_LBUTTONDBLCLK =
	  fireButtonEvent hwnd lParam True True

	| msg == Win32.wM_LBUTTONUP =
	  fireButtonEvent hwnd lParam True False

	| msg == Win32.wM_RBUTTONDOWN || msg == Win32.wM_RBUTTONDBLCLK =
	  fireButtonEvent hwnd lParam False True

	| msg == Win32.wM_RBUTTONUP =
	  fireButtonEvent hwnd lParam False False

	| msg == Win32.wM_MOUSEMOVE = do
	  p <- posn hwnd lParam
	  send (MouseMove p)

	| msg == Win32.wM_KEYDOWN =
	  fireKeyEvent wParam True

	| msg == Win32.wM_KEYUP =
	  fireKeyEvent wParam False

	| msg == Win32.wM_CHAR =
	  send (CharKey (toEnum (word32ToInt wParam)))

	| msg == Win32.wM_SIZE = do
          let (hPix,wPix) = lParam `divMod` 65536
          send (Resize (vector2XY (fromInt32 wPix / screenPixelsPerLength)
                                  (fromInt32 hPix / screenPixelsPerLength)))
          resizeIO
          return 0

	-- Timer.  Do the sprite tree updates.
	| msg == Win32.wM_TIMER = do
	  -- putStrLn "WM_TIMER"
	  updateIO
	  return 0

	| msg == Win32.wM_CLOSE = do
	  -- putStrLn "WM_CLOSE"
	  closeIO
	  return 0

	| otherwise
	= Win32.defWindowProc (Just hwnd) msg wParam lParam

      demoClass = Win32.mkClassName "Fran"

      eventLoop :: Win32.HWND -> IO ()
      eventLoop hwnd =
        (do lpmsg <- Win32.getMessage (Just hwnd)
	    Win32.translateMessage lpmsg
	    Win32.dispatchMessage  lpmsg
	    eventLoop hwnd)
	`catch` (\ _ -> return ())
	
  in do
	icon <- Win32.loadIcon   Nothing Win32.iDI_APPLICATION
	cursor <- Win32.loadCursor Nothing Win32.iDC_ARROW
	blackBrush <- Win32.getStockBrush Win32.bLACK_BRUSH
	mainInstance <- Win32.getModuleHandle Nothing
	Win32.registerClass (
	      0, -- Win32.emptyb, -- no extra redraw on resize
	      mainInstance,
	      (Just icon),
	      (Just cursor),
	      (Just blackBrush),
	      Nothing,
	      demoClass)

	--putStrLn "In makeWindow"
	w <- makeWindowNormal demoClass mainInstance wndProc2
	createIO w

	-- Set the (millisecond-based) update timer.
	Win32.setWinTimer w 1 (round (1000 * updateInterval))
	--putStrLn ("Update rate set for " ++ show updateInterval ++ " ms")

	Win32.showWindow w Win32.sW_SHOWNORMAL
	Win32.bringWindowToTop w
	eventLoop w
	(Win32.unregisterClass demoClass mainInstance `catch` \_ -> return ())


makeWindowNormal demoClass mainInstance wndProc2 = do
  (sizeX,sizeY) <- map vector2XYCoords (readIORef initialViewSizeVar)
  let sizePixX = round (sizeX * screenPixelsPerLength)
      sizePixY = round (sizeY * screenPixelsPerLength)
  Win32.createWindow demoClass
               "Fran"
               Win32.wS_OVERLAPPEDWINDOW
               -- The next two are position.  Use Nothing to let Windows
               -- decide, and Just to specify explicitly, which is useful
               -- when recording.
               Nothing    Nothing
               --(Just 200) (Just 200)
               (Just $ sizePixX + extraW)
               (Just $ sizePixY + extraH)
               Nothing               -- parent
               Nothing               -- menu
               mainInstance
               wndProc2
 where
  -- Extra space for window border.  Is there a better way??
  extraW = 8
  extraH = extraW + 20

-- Get the width and height of a window's client area, in pixels.

getViewSize :: Win32.HWND -> IO (Win32.LONG,Win32.LONG)

getViewSize hwnd =
 Win32.getClientRect hwnd >>= \ (l',t',r',b') ->
 return (r' - l', b' - t')

-- Misc

updateRefStrict :: Eval a => IORef a -> (a -> a) -> IO ()

updateRefStrict var f =
  readIORef var >>= \ val ->
  -- Force evaluation of val, so computations don't pile up
  val `seq`
  writeIORef var (f val)

updatePeriodGoal :: SpriteTime
updatePeriodGoal = 0.1

-- ## Eliminate the t0 argument.

-- Show a sprite tree

showSpriteTree :: HSpriteTree -> IO () -> UserChannel -> IO ()

showSpriteTree spriteTree updateIO userChan =
 do spriteEngineVar <- newIORef (error "spriteEngineVar not set")
    updateCountVar  <- newIORef (0::Int)
    frameCountRef   <- newIORef (error "frameCountRef not set")
    windowVar	    <- newIORef (error "windowVar not set")
    
    t0 <- currentSpriteTime
    makeWindow
       -- Create IO
       (\ w ->
	 do writeIORef windowVar w
	    eng <- newSpriteEngine w spriteTree
	    writeIORef spriteEngineVar eng)
       -- Resize IO.  Recreates the back buffer and clippers.
       (do eng <- readIORef spriteEngineVar
	   onResizeSpriteEngine eng)
       -- Update IO
       (do -- garbageCollect
           updateIO
	   updateRefStrict updateCountVar (+1))
       -- Close IO
       (do eng   <- readIORef spriteEngineVar
	   count <- deleteSpriteEngine eng
	   writeIORef frameCountRef count
	   win   <- readIORef windowVar
	   Win32.destroyWindow win)
       -- update interval in seconds
       updatePeriodGoal
       userChan

    -- Clean up
    deleteSpriteTree spriteTree
    -- Show performance stats
    updateCount <- readIORef updateCountVar
    frameCount  <- readIORef frameCountRef
    showStats t0 frameCount updateCount
    return ()


-- To do: get frame count

showStats :: SpriteTime -> Int -> Int -> IO ()

showStats t0 frameCount updateCount =
 do t1 <- currentSpriteTime
    let dt = t1 - t0
    -- putStrLn (show dt ++ " seconds")
    putStrLn ""
    putStrLn (show dt ++ " seconds elapsed")
    putStrLn (show frameCount ++ " frames == " ++
              show (fromInt frameCount / dt) ++ " fps, " ++
              show (round (1000 * dt / fromInt frameCount)) ++
              " MS average")
    putStrLn (show updateCount ++ " updates == " ++
              show (fromInt updateCount / dt) ++ " ups, " ++
              show (round (1000 * dt / fromInt updateCount)) ++
              " MS average")


----------------------------------------------------------------
-- Program parameters
----------------------------------------------------------------

-- Initial window size.  Find a better way...

-- Given in Fran units, not pixels.  For instance, to exactly fit a unit
-- circle, use vector2XY 2 2.  Below, we include some extra space.

initialViewSizeVar :: IORef Vector2
initialViewSizeVar = Win32.unsafePerformIO $ newIORef $
                     (1 + extra) *^ vector2XY 2 2
 where
   extra = 0.1                          -- breathing space

setViewSize :: RealVal -> RealVal -> IO ()
setViewSize w h = writeIORef initialViewSizeVar (vector2XY w h)

