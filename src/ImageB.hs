-- "Image behavior" type defined directly, i.e., without Image or Behavior.

module ImageB where

import qualified HSpriteLib as SL
import BaseTypes
import qualified StaticTypes as S
import Behavior
import Vector2B
import ColorB
import Point2B
import TextB
import Transform2B
import Event
import qualified RenderImage as R
import SoundB
import Maybe (fromMaybe)
import Concurrent			-- MVar
import Trace

infixl 6 `over`

defaultColor = red

data ImageB
 = EmptyImage
 | SolidImage                           -- solid color
 | FlipImage  SL.HFlipBook RealB        -- page # behavior
 | RenderImage RenderIO                 -- renders to a DDSurface
 | SoundI     SoundB                    -- embedded sound
 | Over       ImageB   ImageB           -- overlay
 | TransformI Transform2B ImageB        -- transformed image
 | WithColor  ColorB ImageB             -- colored image
 | UntilI     ImageB (Event ImageB)	-- "untilB" on ImageB
 | TimeTransI ImageB  TimeB             -- timeTransform on ImageB
 deriving Show

-- Primitives

-- The empty ImageB
emptyImage :: ImageB
emptyImage = EmptyImage

-- Solid color image.  Useful for background for now and later with
-- stenciling.  Use with "withColor".
solidImage :: ImageB
solidImage = SolidImage

-- Flipbook-based ImageB, given page # behavior
flipImage :: SL.HFlipBook -> RealB -> ImageB
flipImage = FlipImage

-- renders to a DDSurface
renderImage :: RenderIO -> ImageB
renderImage = RenderImage

-- Embed a sound
soundImage :: SoundB -> ImageB
soundImage = SoundI

-- overlay
over :: ImageB -> ImageB -> ImageB

-- colored image
withColor :: ColorB -> ImageB -> ImageB
withColor = WithColor

instance Transformable2B ImageB where (*%) = TransformI

-- Here's an example of an optimization.  More are possible.
-- ## Why don't these guys kick in more often, e.g., in lotsODonuts?
EmptyImage `over` imb2 = --trace "(EmptyImage `over`) optimization\n" $
                         imb2
imb1 `over` EmptyImage = --trace "(`over` EmptyImage) optimization\n" $
                         imb1
imb1 `over` imb2       = imb1 `Over` imb2


-- Perhaps move this SyncVar stuff elsewhere.

-- Synchronization variables.  These guys always come in request/reply
-- pairs.  True means continue with next step, while False means stop.
-- Use is take a request, do one step of action, and put a reply.
-- Question: could I package up this pattern into a combinator?

type SyncVar = MVar Bool

-- Forward requests to replies.
forwardSyncVars :: SyncVar -> SyncVar -> IO ()
forwardSyncVars requestV replyV = do
  --putStrLn "forwardSyncVars"
  let forward = do --putStrLn "forwarding"
                   continue <- takeMVar requestV
                   putMVar replyV continue
                   if continue then forward else return ()
  forkIO forward


-- Renderer creator (should be forkIO'd).  See Spritify.hs
type RenderIO = Maybe ColorB -> Transform2B -> Time -> Time
             -> [Time] -> [Time] -> SyncVar -> SyncVar -> SL.SpriteTreeChain
             -> IO SL.HSimpleSprite


syntheticImage :: (Maybe ColorB -> Transform2B -> SurfaceULB) -> ImageB

syntheticImage f = RenderImage renderIO
 where
  renderIO mbColorB xfB t0 xt0 ts xts requestV replyV above = do
    let surfaceULB = f mbColorB xfB
        (surf0,ulX0,ulY0,motX0,motY0):_ = surfaceULB `ats` [xt0]
    hSimpleSprite <- SL.newSimpleSprite
                       surf0 ulX0 ulY0 motX0 motY0 1 1 above
    --putStrLn "Made new SimpleSprite"
    let update ~(t:ts') ~((surf,ulX,ulY,motX,motY):surfaceULs') = do
          --putStrLn "updating simple sprite"
          continue <- takeMVar requestV
          if continue then do
            --putStrLn "renderIO got request"
            --putStrLn $ "surf is " ++ show surf
            --putStrLn "setting surface"
	    -- scale 1 1 for now and (ulX, ulY) is upper-left corner
	    -- of the bounding box in Fran coord system
	    SL.updateSimpleSprite hSimpleSprite t surf ulX ulY motX motY 1 1
            --putStrLn "renderIO replying"
            putMVar replyV True
            update ts' surfaceULs'
           else
            putMVar replyV False
    forkIO $ update ts (surfaceULB `ats` xts)
    return hSimpleSprite


instance TimeTransformable ImageB where timeTransform = TimeTransI

instance  GBehavior ImageB  where
  untilB     = UntilI
  afterTimes = afterTimesI
  -- To do: move timeTransform into GBehavior and overload here
  -- timeTransform = TTransI


afterTimesI :: ImageB -> [Time] -> [ImageB]

EmptyImage `afterTimesI` _ = repeat EmptyImage

SolidImage `afterTimesI` _ = repeat SolidImage

FlipImage book page `afterTimesI` ts =
 map (FlipImage book) (page `afterTimes` ts)

-- Is this one right???
-- im@(SyntheticImageIO f) `afterTimesI` t = im

-- ## I don't think this one is right
im@(RenderImage f) `afterTimesI` ts =
  -- im
  error "afterTimesI not yet supported for RenderImage, sorry."

SoundI snd `afterTimesI` ts = map SoundI (snd `afterTimes` ts)

(imb `Over` imb') `afterTimesI` ts =
  zipWith Over (imb `afterTimesI` ts) (imb' `afterTimesI` ts)

TransformI xfb imb `afterTimesI` ts =
  zipWith TransformI (xfb `afterTimes` ts) (imb `afterTimesI` ts)

WithColor c imb `afterTimesI` ts =
  zipWith WithColor (c `afterTimes` ts) (imb `afterTimesI` ts)

-- ## This one is essentially copied from Behavior.hs, and is almost
-- identical to the GeometryB and SoundB versions.  Figure out how to
-- consolidate.
(imb `UntilI` e) `afterTimesI` ts =
  loop ts (imb `afterTimesI` ts) (e `occs` ts) (e `afterTimes` ts)
 where
   -- ## should the bAfter and eAfter list patterns be lazy??
   loop ts _ (Just (_, imb') : _) _ = imb' `afterTimes` ts

   loop (_:ts') (imbAfter : imbAfters')
        (Nothing : mbOccs') (eAfter : eAfters') =
     (imbAfter `UntilI` eAfter) : loop ts' imbAfters' mbOccs' eAfters'


-- utilities

-- Overlay of list of ImageB's.  First one is on top
overs :: [ImageB] -> ImageB
overs = foldr over emptyImage

-- circle

circleSurface :: Maybe ColorB -> Transform2B -> SurfaceULB
circleSurface mbColorB stretchB =
  lift2 R.renderCircle (fromMaybe defaultColor mbColorB) stretchB

circle :: ImageB
circle = syntheticImage circleSurface

-----------------------------------------------------------------
-- Naming convection: the ones that are directly lifted are
-- suffixed with a "B" and those that are more frequently used are
-- without.
-----------------------------------------------------------------

-- poly: polygon, polyline, polyBezier

polygonSurfaceB    :: Behavior [S.Point2] -> Maybe ColorB -> Transform2B
		   -> SurfaceULB
polylineSurfaceB   :: Behavior [S.Point2] -> Maybe ColorB -> Transform2B
		   -> SurfaceULB
polyBezierSurfaceB :: Behavior [S.Point2] -> Maybe ColorB -> Transform2B
		   -> SurfaceULB

polygonSurfaceB    = polySurface R.renderPolygon
polylineSurfaceB   = polySurface R.renderPolyline
polyBezierSurfaceB = polySurface R.renderPolyBezier

polygonSurface    :: [Point2B] -> Maybe ColorB -> Transform2B -> SurfaceULB
polylineSurface   :: [Point2B] -> Maybe ColorB -> Transform2B -> SurfaceULB
polyBezierSurface :: [Point2B] -> Maybe ColorB -> Transform2B -> SurfaceULB

polygonSurface    pts = polySurface R.renderPolygon    (liftL id pts)
polylineSurface   pts = polySurface R.renderPolyline   (liftL id pts)
polyBezierSurface pts = polySurface R.renderPolyBezier (liftL id pts)

polySurface :: ([S.Point2] -> S.Color -> S.Transform2 -> R.SurfaceUL)
	    -> Behavior [S.Point2] -> Maybe ColorB -> Transform2B
	    -> SurfaceULB
polySurface renderF pts mbColorB stretchB =
  lift3 renderF pts (fromMaybe defaultColor mbColorB) stretchB

polygonB    :: Behavior [S.Point2] -> ImageB
polylineB   :: Behavior [S.Point2] -> ImageB
polyBezierB :: Behavior [S.Point2] -> ImageB

-- These ones allow the number of vertices to change
polygonB    pts = syntheticImage (polygonSurfaceB    pts)
polylineB   pts = syntheticImage (polylineSurfaceB   pts)
polyBezierB pts = syntheticImage (polyBezierSurfaceB pts)

-- These ones are more convenient in the common case
polygon    :: [Point2B] -> ImageB
polyline   :: [Point2B] -> ImageB
polyBezier :: [Point2B] -> ImageB

polygon    pts = syntheticImage (polygonSurface    pts)
polyline   pts = syntheticImage (polylineSurface   pts)
polyBezier pts = syntheticImage (polyBezierSurface pts)

bezier :: Point2B -> Point2B -> Point2B -> Point2B -> ImageB
bezier p1 p2 p3 p4 = polyBezier [p1,p2,p3,p4]

-- square, regularPolygon, star

square :: ImageB
square = polygon $ map f [0 .. 3]
  where
    f i = let theta = pi / 4 * (1 + 2 * fromIntegral i)
	  in  point2Polar 1 theta

-- A regular polygon with given number of vertices
regularPolygon :: IntB -> ImageB
regularPolygon vertices = star 1 vertices

-- Star figure.  Arguments: skip and vertices.  For instance, (star 7 3)
-- is a seven-pointed star connecting every third vertex of what would be
-- a regular 7-gon.
star :: IntB -> IntB -> ImageB
star skip vertices = polygonB pts
  where
    pts = lift2 f vertices skip

    f :: Int -> Int -> [S.Point2]
    f v s = let theta = 2 * pi * fromInt s / fromInt v
	    in  [ S.point2Polar 1 (theta * fromInt i) | i <- [0 .. v] ]

-- line

lineSurface :: Point2B -> Point2B -> Maybe ColorB -> Transform2B -> SurfaceULB
lineSurface p0 p1 mbColorB stretchB =
  lift4 R.renderLine p0 p1 (fromMaybe defaultColor mbColorB) stretchB

line :: Point2B -> Point2B -> ImageB
line p0 p1 = syntheticImage (lineSurface p0 p1)

-- textB, colorB, stretchB

textSurface :: TextB -> Maybe ColorB -> Transform2B -> SurfaceULB
textSurface textB mbColorB xfB =
  lift3 R.renderText
	textB
	(fromMaybe defaultColor mbColorB)
	xfB

textImage :: TextB -> ImageB
textImage textB = syntheticImage (textSurface textB)

type SurfaceULB = Behavior R.SurfaceUL

-- pixelsPerLength

importPixelsPerLength = R.importPixelsPerLength
screenPixelsPerLength = R.screenPixelsPerLength
