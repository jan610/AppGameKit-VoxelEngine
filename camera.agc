function ControlCamera()	
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
	if GetRawKeyState(16) then speed#=50*GetFrameTime()
	VelocityZ#=Core_CurveValue(VelocityZ#,0,10.0)
	VelocityX#=Core_CurveValue(VelocityX#,0,10.0)
	VelocityY#=Core_CurveValue(VelocityY#,0,10.0)

	// move the camera with keys
	if GetKeyboardExists()=1
		if(GetRawKeyState(KEY_W)) then VelocityZ#=Core_CurveValue(VelocityZ#,speed#,10.0)
		if(GetRawKeyState(KEY_S)) then VelocityZ#=Core_CurveValue(VelocityZ#,-speed#,10.0)
		if(GetRawKeyState(KEY_A)) then VelocityX#=Core_CurveValue(VelocityX#,-speed#,10.0)
		if(GetRawKeyState(KEY_D)) then VelocityX#=Core_CurveValue(VelocityX#,speed#,10.0)
		if(GetRawKeyState(KEY_Q)) then VelocityY#=Core_CurveValue(VelocityY#,-speed#,10.0)
		if(GetRawKeyState(KEY_E)) then VelocityY#=Core_CurveValue(VelocityY#,speed#,10.0)
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
	if GetKeyboardExists()=1
	    if GetRawMouseMiddlePressed()=1
	        PointerStartX#=PointerX#
	        PointerStartY#=PointerY#
			CameraAngleX#=GetCameraAngleX(1)
			CameraAngleY#=GetCameraAngleY(1)
	    endif
	
	    if GetRawMouseMiddleState()=1
	        PointerDragX#=(PointerX#-PointerStartX#)
	        PointerDragY#=(PointerY#-PointerStartY#)
	    endif
	else
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
	endif
    
    CameraAngleNewX#=Core_CurveAngle(CameraAngleNewX#,Core_Clamp(CameraAngleX#+PointerDragY#,-89.0,89.0),7.0)
    CameraAngleNewY#=Core_CurveAngle(CameraAngleNewY#,CameraAngleY#+PointerDragX#,7.0)
    SetCameraRotation(1,CameraAngleNewX#,CameraAngleNewY#,0)
    Print(GetCameraAngleX(1))
endfunction
