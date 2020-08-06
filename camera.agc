function ControlCamera()
	#constant KEY_ESC				27
	#constant KEY_PAGEUP			33
	#constant KEY_PAGEDOWN		34
	#constant KEY_LEFT			37
	#constant KEY_UP				38
	#constant KEY_RIGHT			39
	#constant KEY_DOWN			40
	#constant KEY_END				35
	#constant KEY_HOME			36
	#constant KEY_SHIFT			16
	#constant KEY_S				83
	
	local speed# as float
	local JoystickSize# as float

	global CameraAngleNewX# as float
	global CameraAngleNewY# as float
	global PointerX#
	global PointerY#
	global PointerStartX#
	global PointerStartY#
	global PointerDragX#
	global PointerDragY#
	global CameraAngleX#
	global CameraAngleY#
	global VelocityZ#
	global VelocityX#
	global VelocityY#

	speed#=20*GetFrameTime()
	if GetRawKeyState(KEY_SHIFT) then speed#=50*GetFrameTime()
	VelocityZ#=CurveValue(VelocityZ#,0,10.0)
	VelocityX#=CurveValue(VelocityX#,0,10.0)
	VelocityY#=CurveValue(VelocityY#,0,10.0)

	// move the camera with keys
	if GetKeyboardExists()=1
		if(GetRawKeyState(87)) then VelocityZ#=CurveValue(VelocityZ#,speed#,10.0)
		if(GetRawKeyState(83)) then VelocityZ#=CurveValue(VelocityZ#,-speed#,10.0)
		if(GetRawKeyState(65)) then VelocityX#=CurveValue(VelocityX#,-speed#,10.0)
		if(GetRawKeyState(68)) then VelocityX#=CurveValue(VelocityX#,speed#,10.0)
		if(GetRawKeyState(81)) then VelocityY#=CurveValue(VelocityY#,-speed#,10.0)
		if(GetRawKeyState(69)) then VelocityY#=CurveValue(VelocityY#,speed#,10.0)
	else
		JoystickSize#=GetVirtualHeight()*0.25
		SetJoystickScreenPosition(GetScreenBoundsLeft()+JoystickSize#*0.5,GetScreenBoundsBottom()-JoystickSize#*0.5,JoystickSize#)
		MoveCameraLocalZ( 1, -GetJoystickY() * speed# )
		MoveCameraLocalX( 1, GetJoystickX() * speed# )
	endif
	
	MoveCameraLocalZ(1, VelocityZ# )
	MoveCameraLocalX(1, VelocityX# )
	MoveCameraLocalY(1, VelocityY# )

	// rotate the camera
	PointerX#=GetPointerX()
	PointerY#=GetPointerY()

    if GetPointerPressed()=1
        PointerStartX#=PointerX#
        PointerStartY#=PointerY#
		CameraAngleX#=GetCameraAngleX(1)
		CameraAngleY#=GetCameraAngleY(1)
    endif

    if GetPointerState()=1
        PointerDragX#=(PointerX#-PointerStartX#)
        PointerDragY#=(PointerY#-PointerStartY#)
    endif
    
    CameraAngleNewX#=CurveAngle(CameraAngleNewX#,CameraAngleX#+PointerDragY#,7.0)
    CameraAngleNewY#=CurveAngle(CameraAngleNewY#,CameraAngleY#+PointerDragX#,7.0)
    SetCameraRotation(1,CameraAngleNewX#,CameraAngleNewY#,0)
endfunction

function CurveValue(current# as float, destination# as float, speed# as float)
    local diff# as float
    if  speed# < 1.0  then speed# = 1.0
    diff# = destination# - current#
    current# = current# + ( diff# / speed# )
endfunction current#

function CurveAngle(current# as float, destination# as float, speed# as float)
    local diff# as float
    if speed# < 1.0 then speed# = 1.0
    destination# = WrapAngle( destination# )
    current# = WrapAngle( current# )
    diff# = destination# - current#
    if diff# <- 180.0 then diff# = ( destination# + 360.0 ) - current#
    if diff# > 180.0 then diff# = destination# - ( current# + 360.0 )
    current# = current# + ( diff# / speed# )
    current# = WrapAngle( current# )
endfunction current#

function WrapAngle( angle# as float) 
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

function Lerp(Start#,End#,Time#)
endfunction Start#+Time#*(End#-Start#)

function Clamp(Value#,Min#,Max#)
	if Value#>Max# then Value#=Max#
	if Value#<Min# then Value#=Min#
endfunction Value#