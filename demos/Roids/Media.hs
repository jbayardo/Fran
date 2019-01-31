-- Media for Roids.
-- 
-- Too bad we have to hardwire paths.  There should be a searching mechanism.


module Media where

import Fran
import qualified StaticTypes as S

-- All of the flipbooks.
[ donutBook, pyramidBook, sphereBook, cubeBook, shipBook, shipShieldBook ] =
 parseFlipBooks [(5,6), (10,4), (20,2), (20,2), (10,4), (10,4)] 0
                donutsSurface
 where
   donutsSurface = bitmapDDSurface "..\\..\\Media\\donuts.bmp"

roidBooks = [ donutBook, pyramidBook, sphereBook, cubeBook ]

roidImage :: Int -> ImageB
roidImage i = flipImage book (time * pageRate)
 where
   book     = roidBooks !! i
   pageRate = 30

-- Radius for collision detection
roidRadius :: Floating a => Int -> a
roidRadius i = fromDouble (map bookRadius roidBooks !! i)

shipRadius :: Floating a => a
shipRadius = bookRadius shipBook

bookRadius :: Floating a => HFlipBook -> a
bookRadius book = fromDouble (w/2)
 where
   S.Vector2XY w h = flipBookSize book

-- The fromDouble prevents the division from being carried out at each use
shipPagesPerRadian :: Floating a => a
shipPagesPerRadian =
  fromDouble (fromInt (flipBookPages shipBook) / (2*pi))



-- Spikeys.  These guys are pretty neat, but big, so I'm hesitant to
-- include them in the Fran distribution.
parseSpikeys = head . parseFlipBooks [(6,10)] 0 . bitmapDDSurface
spikeyBook    = parseSpikeys "spikeys60 small.bmp" -- 721Kb
spikeyBookBig = parseSpikeys "spikeys60 big.bmp"   -- 2.9Mb

engineSound   = importWave "..\\..\\Media\\sengine.wav"


-- Missile image and radius
missileImage :: RealB -> ImageB
missileImage = \ radius ->
  stretch radius (soundImage missileSound `over`
                  turn (2 * time) missileShape)
 where
   missileShape = withColor yellow $
                  star 3 7
   missileSound = pitch 100 $
                  volume 3  $
                  importWave "..\\..\\Media\\bounce.wav"


