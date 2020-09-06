// Project: AppGameKit-VoxelEngine
// File: core.agc
// Created: 20-07-31

function Core_StringInsertAtDelemiter(string$,insert$,delimiter$)
	local left$ as string
	local right$ as string
	local str$ as string
	left$=GetStringToken(string$,delimiter$,1)
	right$=GetStringToken(string$,delimiter$,2)
	str$=left$+insert$+right$
endfunction str$

function Core_CurveValue(current# as float, destination# as float, speed# as float)
    local diff# as float
    if  speed# < 1.0  then speed# = 1.0
    diff# = destination# - current#
    current# = current# + ( diff# / speed# )
endfunction current#

function Core_CurveAngle(current# as float, destination# as float, speed# as float)
    local diff# as float
    if speed# < 1.0 then speed# = 1.0
    destination# = Core_WrapAngle( destination# )
    current# = Core_WrapAngle( current# )
    diff# = destination# - current#
    if diff# <- 180.0 then diff# = ( destination# + 360.0 ) - current#
    if diff# > 180.0 then diff# = destination# - ( current# + 360.0 )
    current# = current# + ( diff# / speed# )
    current# = Core_WrapAngle( current# )
endfunction current#

function Core_WrapAngle( angle# as float) 
    local iChunkOut as integer
    local breakout as integer
    iChunkOut = angle#
    iChunkOut = iChunkOut - mod( iChunkOut, 360 )
    angle# = angle# - iChunkOut
    breakout = 10000
    while angle# < 0.0 or angle# >= 360.0 
        if angle# < 0.0 then angle# = angle# + 360.0
        if angle# >= 360.0 then angle# = angle# - 360.0
        dec breakout
        if  breakout = 0  then exit
    endwhile
    if  breakout = 0  then angle# = 0.0
endfunction angle#

function Core_Lerp(Start#,End#,Time#)
endfunction Start#+Time#*(End#-Start#)

function Core_Clamp(Value#,Min#,Max#)
	if Value#>Max# then Value#=Max#
	if Value#<Min# then Value#=Min#
endfunction Value#
