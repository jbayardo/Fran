-- Module for testing Fran

module Test where

import Fran
import qualified Win32
import qualified StaticTypes as S
--import Trace


-- The test cases

donutSurface :: HDDSurface
donutSurface = bitmapDDSurface "../Media/donuts.bmp"

bounceBuffer, engineBuffer, monsoonBuffer, planeBuffer :: HDSBuffer
bounceBuffer  = waveDSBuffer "../Media/bounce.wav"
engineBuffer  = waveDSBuffer "../Media/sengine.wav"
monsoonBuffer = waveDSBuffer "../Media/monsoon2.wav"
planeBuffer   = waveDSBuffer "../Media/plane.wav"

donutFlipBook :: HFlipBook
donutFlipBook = flipBook donutSurface 64 64 0 0 5 6

donut :: Vector2B -> RealB -> RealB -> ImageB

donut motionB scaleB pageB =
  move motionB $
  stretch scaleB  $
  soundImage (bufferSound bounceBuffer) `over`
  flipImage donutFlipBook pageB


linearDonut :: RealVal -> RealVal -> RealVal -> RealVal
            -> User -> ImageB

linearDonut velX velY scaleRate pageRate u =
  donut (vector2XY (x0 + dt * constantB velX) (y0 + dt * constantB velY))
        scale
        (dt * constantB pageRate)
  where
   dt = userTime u
   scale = 1 + dt * constantB scaleRate
   x0 = -1
   y0 = x0


donut0, donut1, donut2, donut3, donut4, donut5, twoDonuts, threeDonuts
  :: User -> ImageB

donut0 u = flipImage donutFlipBook 0


donut0'  u = stretch 1 $ flipImage donutFlipBook 0
donut0'' u = stretch (userTime u) $ flipImage donutFlipBook 0

donut1 = linearDonut 0.40 0.35 0.0  50
donut2 = linearDonut 0.50 0.45 0.2  70
donut3 = linearDonut 0.45 0.40 0.5 100

donut4 u = donut (vector2Polar 1 dt) 1
                 (10 * dt)
  where dt = userTime u

donut5 u = donut (vector2Polar 1 dt) sc
                 (30 * sin (dt/3))
  where dt = userTime u
        sc = 1 + 0.4 * sin dt 

donut6 u =  --trace ("donut6': t0 = " ++ show (userStartTime u) ++ "\n") $
            donut (vector2Polar dist ang) sc
                  (20 * dt)
            `untilB` stop -=> emptyImage
  where dt   = 3 * userTime u
        ang  = dt
        dist = 1 - 0.05 * dt
        sc   = dist
        stop = --userTimeIs 7 u
               predicate (sc <* 0.1) u

-- Like donut4, but spirals inward
donut7 u = donut (vector2Polar (1/(1+dt/2)) dt) 1
                 (10 * dt)
  where dt = userTime u


donut8 u =
  move (vector2XY 0 1) (showBIm dt)
     `over`
  (donut0 u `untilB` ev -=> emptyImage)
 where
   ev = predicate (dt >=* 5) u
   dt = userTime u

donut8a u = donut0 u `untilB` userTimeIs 5 u -=> emptyImage
donut8b u = donut0 u `untilB` predicate (userTime u >=* 5) u -=> emptyImage


--donut9 u = donut0 u `untilB` lbp' u -=> emptyImage

--lbp' u = traceE "lbp" TraceOccsE (lbp u)
--rbp' u = traceE "rbp" TraceOccsE (rbp u)



twoDonuts u =
 donut2 u `over` donut1 u

threeDonuts u =
 donut3 u `over`
 (twoDonuts u `untilB` userTimeIs 2 u -=> emptyImage)

wordy0 u = stringBIm (constantB "Hello world!")

wordy1 u =
 (withColor blue $
  move (vector2Polar (1 / (1+dt/2)) (- dt)) $
  stretch 2 $
  showBIm dt) `over`
 donut7 u
  where
   dt = userTime u

wordy2 u =
 ( withColor color $
   move (vector2Polar (1 / (1+dt/2)) (- dt)) $
   stretch scale   $
   turn angFrac  $
   textImage text) `over`
 donut7 u
  where
   dt = userTime u
   scale = 1.5 + sin dt
   angFrac = dt / 3
   color = colorHSL h 0.5 0.5
   h = pi * (1 + sin dt)
   text = simpleText (showB dt)

turnWordy angFrac u =
 turn angFrac $ textImage (simpleText (constantB "A String to render"))

wordy3 u = turnWordy (sin (userTime u) * pi / 2) u

wordy4 u =
  stretch 2 $
  withColor blue  (turnWordy (  sin (userTime u) * pi / 2) u) `over`
  withColor green (turnWordy (- sin (userTime u) * pi / 2) u)


-- simplification of lotsODonuts

-- This test trips on the commented-out "seq" in afterE.  (Event.hs)
seqD9 u = 
 soFar `untilB` nextE e ==> \ e ->
 soFar `untilB` nextE e -=> emptyImage
  where
    soFar = emptyImage
    e = alarmE (userStartTime u) 2 `afterE_` u

seqD1 u = b `untilB` (userTimeIs 2.1111 u `afterE_` b)
 where
   b = donut1 u

lotsODonuts u = accumB over (donut6 u) another
 where
  another = alarmUE 1.2 u ==> donut6

alarmUE dt u = alarmE (userStartTime u) dt `afterE_` u

typing u = stretch 3 $
           stringBIm $
           stepper "start typing"
                   (scanlE (\ s c -> s ++ [c])
                           ""
                           (charPressAny u))


-- From the tutorial

importHead name =
  importBitmap ("../Media/" ++ name ++ " head black background.bmp")

{-
importBMP name = flipImage book 0
 where
  book = flipBook surf w h 0 0 1 1
  surf = bitmapDDSurface ("../Media/" ++ name ++ " head black background.bmp")
  (w,h) = getDDSurfaceSize surf
-}

leftRightCharlotte = moveXY wiggle 0 charlotte

charlotte = importHead "charlotte"
pat       = importHead "pat"

upDownPat = moveXY 0 wiggle pat

charlottePatDance = leftRightCharlotte `over` upDownPat 

patHorses = moveXY wiggle waggle pat `over` horses

patMouse u = move (mouseMotion u) pat

patMoves u = moveXY (-1 + atRate 1 u) 0 pat


-- Fun with time shifting

shifter u = marker p2 red  `over`
            marker p3 blue `over`  curve
 where
  curve = bezier p1 p2 p3 p4
  p1    = point2XY (-1) 0
  p2    = mouse u
  p3    = later 2 p2
  p4    = point2XY 1 0
  marker p col =
    move (p .-. origin2) $
    stretch 0.1          $
    withColor col        $
    circle

-- Sound tests

bounceS = bufferSound bounceBuffer

s0 u = soundImage $ pan (10 * sin (userTime u)) bounceS
   

snd0 u = donut0 u `over`
         soundImage (bufferSound bounceBuffer)

-- Left-to-right panning
snd1 u = move (vector2XY (sin (userTime u)) 0) (snd0 u)

snd1' u = move (mouseMotion u) (snd0 u)

-- shrink/fade
snd2 u = stretch (sin (userTime u / 5)) (snd0 u)

snd3' u = stringBIm (constantB "Move the mouse around")

snd3 u = stringBIm msg `over`
         soundImage (pitch y (volume x (bufferSound planeBuffer)))
 where
  msg = constantB "Move the mouse around"
  (x, y) = vector2XYCoords (mouse u .-. point2XY (-1) (-1.5))

snd4 u = accum u `untilB` nextUser_ (keyPress Win32.vK_ESCAPE) u ==> snd4
 where
  accum u = emptyImage `untilB` nextUser_ (keyPress Win32.vK_SPACE) u ==> \ u' ->
            accum u' `over` donut1 u'

snd5 u = soundImage (loop u)
 where
  loop  u = accum u `untilB` nextUser_ (keyPress Win32.vK_ESCAPE) u ==> loop
  accum u = silence `untilB` nextUser_ (keyPress Win32.vK_SPACE) u ==> \ u' ->
            bufferSound bounceBuffer `mix` accum u'

snd6 u = soundImage (loop u)
 where
  loop  u = accum u `untilB` nextUser_ (keyPress Win32.vK_ESCAPE) u ==> loop
  accum u = accumB mix silence (addSound u)
  addSound u = withTimeE (bounceButton u)  ==> bounce
  bounceButton u = nextUser_ (keyPress Win32.vK_SPACE) u
  bounce (u',te) = --trace ("bounce at " ++ show (userStartTime u', te) ++ "\n") $
                   bufferSound bounceBuffer


growHowTo :: User -> ImageB

growHowTo u = moveXY 0 (- winHeight / 2 + 0.1) $
              withColor yellow $
              stringBIm messageB
  where
    winHeight = snd (vector2XYCoords (viewSize u))
    messageB = selectLeftRight "Use mouse buttons to control pot's spin"
               "left" "right" u


grow, growExp :: User -> RealVal -> RealB

grow u x0 = size
 where 
  size = constantB x0 + atRate rate u 
  rate = bSign u

-- Yipes!! This one is blows the stack :-(

growExp u x0 = size
 where 
  size = constantB x0 + atRate rate u 
  rate = bSign u * size

{-
bSign :: User -> RealB

bSign u = 
 0 `untilB` lbp u ==> nonZero (-1) lbr .|. 
            rbp u ==> nonZero 1    rbr
 where
  nonZero :: RealB -> (User -> Event User) -> User -> RealB
  nonZero r stop u = 
   r `untilB` stop u ==> bSign
-}


selectLeftRight :: a -> a -> a -> User -> Behavior a

selectLeftRight none left right u = notPressed u
 where
  notPressed u =
   constantB none `untilB` 
     nextUser_ lbp u ==> pressed left  lbr .|. 
     nextUser_ rbp u ==> pressed right rbr 

  pressed x stop u = 
   constantB x `untilB` nextUser_ stop u ==> notPressed

bSign :: User -> RealB

bSign = selectLeftRight 0 (-1) 1


jumpPat u = buttonMonitor u `over`
            moveXY (bSign u) 0 pat

growPat u = buttonMonitor u `over`
            stretch (grow u 1) pat

growExpPat u = buttonMonitor u `over`
               stretch (growExp u 1) pat



buttonMonitor u =
  moveXY 0 (-1) $
  withColor white $
  stretch 2       $
  stringBIm (selectLeftRight "(press a button)" "left" "right" u)

-- Becky art


wildcat, horses :: ImageB

wildcat = importBitmap "../Media/wildcat.bmp"

horses = importBitmap "../Media/horses.bmp"


frolic u =
  move (mouseMotion u) (stretch wcSize wildcat) `over`
  horses
 where
  wcSize = 0.3


-- Testing mutually reactive behaviors


-- A "self reactive" behavior.

iRecReact u = withColor red (stretch x (donut0 u))
 where
  x = userTime u `untilB` predicate (x >=* 1) u -=> 1


-- Works fine

iTst6 u = withColor red (stretch x (donut0 u))
 where
  x = userTime u `untilB` userTimeIs 6 u `snapshot` x -=> 1

iTst7 u = withColor red (stretch x (donut0 u))
 where
  x = atRate dx u `untilB` userTimeIs 5 u `snapshot` x -=> 1
  dx = 0.2 :: Behavior RealVal

iTst8 u = withColor red (stretch x (donut0 u))
 where
  x = atRate dx u `untilB` userTimeIs 3 u `snapshot_` x ==> constantB
  dx = 0.3 :: Behavior RealVal

iTst9 u = withColor red (stretch x (donut0 u))
 where
  x = atRate dx u `untilB` predicate (x>=*1) u `snapshot` x -=> 1
  dx = 0.3 :: Behavior RealVal

iTst10 u = withColor red (stretch x (donut0 u))
 where
  x = atRate dx u `untilB` predicate (x>=*1) u `snapshot_` x ==> constantB
  dx = 0.3 :: Behavior RealVal


uPeriod u = showBIm (updatePeriod u)

-----------------------------------------------------------------
-- test 2D stuff
-----------------------------------------------------------------

l0 = line (point2XY (-1) (-1)) (point2XY 1 1)

l1 u = stretch wiggle circle
l2 u = polygon [point2XY 1 1, point2XY (- abs wiggle) 0,
		      point2XY 1 wiggle]
l3 u = line (point2XY 1 1) (point2XY wiggle wiggle)
l4 u = slower 2 $ stretch (wiggleRange 2 4) $
       stringBIm (lift0 text !!* roundB (wiggleRange 0 6))
 where
   text = words "Where Do You Want To Go Today?"
   strs = map stringIm text
l5 u = regularPolygon 6
l6 u = turn (userTime u / 15) $ star 3 10
l7 u = turn (userTime u / 3) $
       star (roundB (10 * wiggle)) 20
l8 u = turn (userTime u / 3) $
       slower 5 $ star 5 (roundB (wiggleRange 5 35))

pause :: (User -> ImageB) -> User -> ImageB
pause f u = f u `untilB`
	    lbp u ==> const 1		-- const 1 is redundant
	    `snapshot_` time 
	    `afterE` u ==> \ (t, u') ->
	    f u' `timeTransform` lift0 t `untilB` 
	    lbp u' ==> const (f u') 
	    `afterE_` u' ==>		-- const (...) is redundant too
	    pause f

l9 = pause l2


-- Crop tests.

flower = stretch 0.4 (importBitmap "../Media/rose medium.bmp")

cropFlower rect = crop rect (stretch 3 flower)

crop1 u = cropFlower (rectLLUR ll ur)
 where
   ll = point2XY (-0.5) (-0.5) .+^ vector2Polar 0.2 (2*time)
   ur = point2XY ( 0.5) ( 0.5) .+^ vector2Polar 0.3 (3*time)

crop2 u = cropFlower (rectLLUR (mousePos .-^ v) (mousePos .+^ v))
 where
   v = vector2XY 0.5 0.5
   mousePos = mouse u

crop2' = cropMagnify 1 0.5 (stretch 3 flower)

crop3 = cropFlower . rubberBandRect

crop4 u = cropMagnify 3 1 imB u `over` imB
 where
   imB = stretch 3 flower

crop5 u = cropMagnify 6 1 imB u `over` imB
 where
   imB = stretch 0.3 (stringIm str)
   str = "Animation can be fun.  Just say what the animation is and let Fran take care of checking events and sampling behaviors."

crop6 u = cropMagnify 3 1 imB u `over` imB
 where
   imB = donut4 u

rubberBandRect :: User -> RectB
rubberBandRect u = rectLLUR ll ur
 where
   mousePos = mouse u
   ll = stepper S.origin2 (lbp u `snapshot_` mousePos)
   ur = condB (leftButton u) mousePos lastReleasePos
   lastReleasePos = stepper S.origin2 (lbr u `snapshot_` mousePos)

cropMagnify :: RealB -> RealB -> ImageB -> User -> ImageB
cropMagnify factor size imB u =
  frame  `over`
  crop (rectLLUR (mousePos .-^ v) (mousePos .+^ v)) (
       stretchAtPoint factor mousePos imB
       -- Use solid black background, so that the transparent parts of the
       -- image are no longer transparent.
       `over` withColor black solidImage
       )
 where
   mousePos = mouse u
   v = vector2XY halfSize halfSize
   halfSize = size / 2
   frame' = withColor white $
            polyline [ mousePos .+^ halfSize *^ vector2XY x y
                     | (x,y) <- last corners : corners ]
   -- The following should be equivalent, but looks much better, because
   -- it moves at every frame (~50Hz) rather than ever update (~10Hz).
   frame = withColor white           $
           move (mousePos .-. origin2) $
           stretch halfSize          $
           polyline [ point2XY x y | (x,y) <- last corners : corners ]
   corners = [(-1,-1),(1,-1),(1,1),(-1,1)]

tstFrame u = withColor white $
             polygon [ pos .+^ 0.25 *^ vector2XY x y
                      | (x,y) <- last corners : corners ]
 where
   pos = mouse u
   --pos = point2Polar 0.5 time
   --pos = point2XY (userTime u / 5) 0
   corners = [(-1,-1),(1,-1),(1,1),(-1,1)]

stretchAtPoint :: Transformable2B bv => RealB -> Point2B -> bv -> bv
stretchAtPoint factor point = (uscaleAtPoint2 factor point *%)

uscaleAtPoint2 :: RealB -> Point2B -> Transform2B
uscaleAtPoint2 factor point =
  translate2 motion    `compose2`
  uscale2    factor    `compose2`
  translate2 (-motion)
 where
   motion = point .-. origin2
