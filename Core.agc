// File: core.agc
type Core_Vec4Data
	X# as float
	Y# as float
	Z# as float
	W# as float
endtype

type Core_Vec3Data
    X# as float
    Y# as float
    Z# as float
endtype
 
type Core_Vec2Data
    X# as float
    Y# as float
endtype
 
type Core_ColorData
    Red as integer
    Green as integer
    Blue as integer
    Alpha as integer
endtype
 
type Core_Int3Data
    X as integer
    Y as integer
    Z as integer
endtype
 
type Core_Int2Data
    X as integer
    Y as integer
endtype

type Core_Int2XZData
	X as integer
	Z as integer
endtype

function Core_Vector3DTo2D(Vector3D as Core_Vec3Data)
	local Vector2D as Core_Vec2Data
	Vector2D.X#=Vector3D.X#
	Vector2D.Y#=Vector3D.Z#
endfunction Vector2D

function Core_GetPointer3D(Pointer as Core_Vec2Data)
	Pointer3D as Core_Vec3Data
 	Pointer3D.X#=Get3DVectorXFromScreen(Pointer.X#,Pointer.Y#)
	Pointer3D.Y#=Get3DVectorYFromScreen(Pointer.X#,Pointer.Y#)
	Pointer3D.Z#=Get3DVectorZFromScreen(Pointer.X#,Pointer.Y#)
endfunction Pointer3D

function Core_GetAngleBetween(Start as Core_Vec2Data, Stop as Core_Vec2Data)
	Dist as Core_Vec2Data
	Dist.X#=Stop.X#-Start.X#
	Dist.Y#=Stop.Y#-Start.Y#
	Angle#=atanfull(Dist.X#,-Dist.Y#)
endfunction Angle#

function Core_StringInsertAtDelemiter(String$,Insert$,Delemiter$)
    Left$=GetStringToken(String$,Delemiter$,1)
    Right$=GetStringToken(String$,Delemiter$,2)
    NewString$=Left$+Insert$+Right$
endfunction NewString$

function Core_GetMask(Mask,Check)
	local Result as integer
	Result=Mask&&Check > 0
endfunction Result

function Core_AddMask(Mask,Add)
	local Result as integer
	Result=Mask||Add
endfunction Result

function Core_RemoveMask(Mask,Remove)
	local Result as integer
	Result=Mask&&!Remove
endfunction Result

function Core_SwitchMask(Mask,Switch)
    if Core_GetMask(Mask,Switch)=1
        dec Mask,Switch
    else
        inc Mask,Switch
    endif
endfunction Mask
 
function Core_CurveValue(current# as float, destination# as float, speed# as float)
    local diff# as float
    if  speed# < 1.0  then speed# = 1.0
    diff# = destination# - current#
    current# = current# + ( diff# / speed# )
endfunction current#
 
function Core_CurveValueOnFrame(current# as float, destination# as float, speed# as float, frametime# as float)
    local diff# as float
    diff# = destination# - current#
    current# = current# + ( diff# / speed# ) * frametime#
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
 
function Core_CurveAngleOnFrame(current# as float, destination# as float, speed# as float, frametime# as float)
    local diff# as float
    destination# = Core_WrapAngle( destination# )
    current# = Core_WrapAngle( current# )
    diff# = destination# - current#
    if diff# <- 180.0 then diff# = ( destination# + 360.0 ) - current#
    if diff# > 180.0 then diff# = destination# - ( current# + 360.0 )
    current# = current# + ( diff# / speed# ) * frametime#
    current# = Core_WrapAngle( current# )
endfunction current#

function Core_WrapAngle( angle# as float)
    if angle#=>0
        angle#=fmod(angle#,360.0)
    else
        angle#=360.0 + fmod(angle#,-360.0)
    endif
endfunction angle#

function Core_WrapInteger(Value, Range)
    Result=Mod(Value, Range)
    if Result<0 then Result=Result+Range
endfunction Result
 
function Core_ManhattanDistance2D(StartX,StartY,EndX,EndY)
    DistX=abs(EndX-StartX)
    DistY=abs(EndY-StartY)
    Dist=DistX+DistY
endfunction Dist
 
function Core_Distance2D(StartX#,StartY#,EndX#,EndY#)
    DistX#=EndX#-StartX#
    DistY#=EndY#-StartY#
    Dist#=sqrt(DistX#*DistX#+DistY#*DistY#)
endfunction Dist#
 
function Core_Distance3D(StartX#,StartY#,StartZ#,EndX#,EndY#,EndZ#)
    DistX#=EndX#-StartX#
    DistY#=EndY#-StartY#
    DistZ#=EndZ#-StartZ#
    Dist#=sqrt(DistX#*DistX#+DistY#*DistY#+DistZ#*DistZ#)
endfunction Dist#
 
function Core_Lerp(Value#,Start#,End#)
endfunction Start#+Value#*(End#-Start#)
 
function Core_InverseLerp(Value#,Start#,End#)
endfunction (Value#-Start#)/(End#-Start#)
 
function Core_Map(Value#,InMin#,InMax#,OutMin#,OutMax#)
    Value#=Core_InverseLerp(Value#,InMin#,InMax#)
    Result#=Core_Lerp(Value#,OutMin#,OutMax#)
endfunction Result#
 
function Core_Clamp(Value#,Min#,Max#)
    if Value#>Max# then Value#=Max#
    if Value#<Min# then Value#=Min#
endfunction Value#

function Core_Max(ValueA#,ValueB#)
    if ValueB#>ValueA# then exitfunction ValueB#
endfunction ValueA#

function Core_Min(ValueA#,ValueB#)
    if ValueB#<ValueA# then exitfunction ValueB#
endfunction ValueA#
 
function Core_Sign(Value#)
    Result = ((Value#>0)*2)-1
endfunction Result

function Core_TriangleCCW(x1,y1,x2,y2,x3,y3)
endfunction ((x1-x2)*(y3-y2))-((y1-y2)*(x3-x2))>0

function Core_PointInTriangle(PointX,PointY,x1,y1,x2,y2,x3,y3)
   AB#=((PointY-y1)*(x2-x1))-((PointX-x1)*(y2-y1))
   BC#=((PointY-y2)*(x3-x2))-((PointX-x2)*(y3-y2))
   if AB#*BC#<=0 then exitfunction 0

   CA#=((PointY-y3)*(x1-x3))-((PointX-x3)*(y1-y3))
   if BC#*CA#<=0 then exitfunction 0
endfunction 1
 
function Core_FillTextEndWithSpaces(String$,MaxWidth#,Size#,Spacing#)
    StringTextID=CreateText(String$)
    SetTextSize(StringTextID,Size#)
    SetTextSpacing(StringTextID,Spacing#)
    StringWidth#=GetTextTotalWidth(StringTextID)
     
    SpaceTextID=CreateText(" ")
    SetTextSize(SpaceTextID,Size#)
    SetTextSpacing(SpaceTextID,Spacing#)
    SpaceWidth#=GetTextTotalWidth(SpaceTextID)
     
    RemainingWidth#=MaxWidth#-StringWidth#
    SpaceCount=round(RemainingWidth#/SpaceWidth#)
    String$=String$+Spaces(SpaceCount)
     
    DeleteText(StringTextID)
    DeleteText(SpaceTextID)
endfunction String$
 
function Core_FillEndWithSpaces(String$,MaxLength)
    Length=len(String$)
    SpaceLength=MaxLength-Length
    String$=String$+Spaces(SpaceLength)
endfunction String$
 
function Core_RequestString(String$) 
    EditBoxID=CreateEditBox()
    SetEditBoxPosition(EditBoxID,25,50)
    SetEditBoxSize(EditBoxID,50,15)
    FixEditBoxToScreen(EditBoxID,1)
    SetEditBoxDepth(EditBoxID,1)
    SetEditBoxFocus(EditBoxID,1)
    SetEditBoxText(EditBoxID,String$)
    while GetEditBoxHasFocus(EditBoxID)
        sync()
    endwhile
    String$=GetEditBoxText(EditBoxID)
    DeleteEditBox(EditBoxID)
endfunction String$

function Core_FileLoad(Filename$)
	if GetFileExists(Filename$)
		MemblockID=CreateMemblockFromFile(Filename$)
		String$=GetMemblockString(MemblockID,0,GetMemblockSize(MemblockID))
		DeleteMemblock(MemblockID)
	endif
endfunction String$

function Core_FileSave(String$,Filename$)
    FileID=OpenToWrite(Filename$) 
    WriteString(FileID,String$)
    CloseFile(FileID)
endfunction