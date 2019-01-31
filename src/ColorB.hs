-- Color behaviors
--
-- Last modified Fri Oct 24 08:51:20 1997

module ColorB where

import BaseTypes
import qualified Color as C
import Behavior
import HSpriteLib (D3DColor)

type ColorB = Behavior C.Color

colorHSL              = lift3 C.colorHSL
colorRGB              = lift3 C.colorRGB
colorHSLCoordsB       = lift1 C.colorHSLCoords
colorRGBCoordsB       = lift1 C.colorRGBCoords
grey		      = lift1 C.grey
asColorRef	      = lift1 C.asColorRef
interpolateColorRGB   = lift3 C.interpolateColorRGB
interpolateColorHSL   = lift3 C.interpolateColorHSL
stronger	      = lift2 C.stronger
duller		      = lift2 C.duller
darker		      = lift2 C.darker
brighter	      = lift2 C.brighter
shade		      = lift2 C.shade

white     = constantB C.white
black     = constantB C.black
red       = constantB C.red
green     = constantB C.green
blue      = constantB C.blue
lightBlue = constantB C.lightBlue
royalBlue = constantB C.royalBlue
yellow    = constantB C.yellow
brown     = constantB C.brown

type FractionB = Behavior Fraction

colorRGBCoords :: ColorB -> (FractionB, FractionB, FractionB)
colorRGBCoords = tripleBSplit . colorRGBCoordsB

colorHSLCoords :: ColorB -> (RealB, FractionB, FractionB)
colorHSLCoords = tripleBSplit . colorHSLCoordsB

colorToD3DColor :: ColorB -> Behavior D3DColor
colorToD3DColor = lift1 C.colorToD3DColor
