// Project: AppGameKit-VoxelEngine
// File: controller.agc
// Created: 20-09-06

global CameraAngleNewX# as float
global CameraAngleNewY# as float

global PointerX# as float
global PointerY# as float

global PointerStartX# as float
global PointerStartY# as float

global PointerDragX# as float
global PointerDragY# as float

global CameraAngleX# as float
global CameraAngleY# as float

global VelocityZ# as float
global VelocityX# as float
global VelocityY# as float

/* The camera doesnt need to be updated on loading or any gui screen */
function Voxel_Controller_Camera()	
	local speed# as float
	local JoystickSize# as float

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

	// Rotate the camera
	PointerX#=GetPointerX()
	PointerY#=GetPointerY()

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
    
    CameraAngleNewX#=Core_CurveAngle(CameraAngleNewX#,CameraAngleX#+PointerDragY#,7.0)
    CameraAngleNewY#=Core_CurveAngle(CameraAngleNewY#,CameraAngleY#+PointerDragX#,7.0)
    SetCameraRotation(1,CameraAngleNewX#,CameraAngleNewY#,0)
endfunction

function Voxel_Controller_Keyboard()
 	// Needs a click to reload
 	
	if GetRawKeyPressed(KEY_F4)
		Voxel_SaveFaceImages(VOXEL_TERRAIN_JSON, FaceImages)
		Message("Textures / subimages saved in " + VOXEL_TERRAIN_JSON)
	endif
	
	if GetRawKeyPressed(KEY_F5)
		Voxel_ReadFaceImages(VOXEL_TERRAIN_JSON, FaceImages)
		Message("Textures / subimages loaded from " + VOXEL_TERRAIN_JSON)
	endif

	if GetRawKeyPressed(KEY_F6)
	 	Voxel_SaveWorld(VOXEL_WORLD_JSON, World)
	 	Message("World saved in " + VOXEL_WORLD_JSON)
	endif
	
	if GetRawKeyPressed(KEY_F7)
	 	Voxel_ReadWorld(VOXEL_WORLD_JSON, World)
	 	Message("World loaded from " + VOXEL_WORLD_JSON)
	endif
endfunction
