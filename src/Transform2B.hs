-- Transform behaviors
-- 
-- Last modified Wed Jul 09 16:57:23 1997

module Transform2B where

import qualified Transform2 as T
import Behavior

-- Hugs bug (?) workaround.  See comment in VectorSpaceB.
-- infixr 7 *%, `compose2`         -- transform apply and compose

type Transform2B = Behavior T.Transform2

identity2  = constantB T.identity2
rotate2    = lift1 T.rotate2
compose2   = lift2 T.compose2
inverse2   = lift1 T.inverse2
uscale2    = lift1 T.uscale2

translate2 :: T.Translateable2 a => Behavior a -> Transform2B
translate2 =  lift1 T.translate2

scale2 :: T.Scaleable2 a => Behavior a -> Transform2B
scale2 =  lift1 T.scale2

{- Needs generalization to handle native ImageB type.

(*%) ::  T.Transformable2 a => Transform2B -> Behavior a -> Behavior a
(*%) =  lift2 (T.*%)

-}

class Transformable2B a where
  (*%)  ::  Transform2B -> a -> a

instance  T.Transformable2 a =>  Transformable2B (Behavior a) where
  (*%) =  lift2 (T.*%)
