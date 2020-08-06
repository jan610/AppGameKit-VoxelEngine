// Project: agk_wurfelcraft 
// Created: 20-07-31

// show all errors

SetErrorMode(2)

#include "voxel.agc"
#include "camera.agc"
#include "noise.agc"

// set window properties
SetWindowTitle( "agk_wurfelcraft" )
SetWindowSize( 1024, 768, 0 )
SetWindowAllowResize( 1 ) // allow the user to resize the window

// set display properties
SetVirtualResolution( 1024, 768 ) // doesn't have to match the window
SetOrientationAllowed( 1, 1, 1, 1 ) // allow both portrait and landscape on mobile devices
SetSyncRate( 0, 0 ) // 30fps instead of 60 to save battery
SetScissor( 0,0,0,0 ) // use the maximum available screen space, no black borders
UseNewDefaultFonts( 1 )

SetSkyBoxVisible(1)
SetDefaultMinFilter(0)
SetDefaultMagFilter(0)
SetDefaultWrapU(1)
SetDefaultWrapU(1)
SetGenerateMipmaps(0)

World as WorldData[18,18,18]

Noise_Init()
Noise_Seed(257)

freq#=6.0
for X=1 to World.length-1
	for Y=1 to World[0].length-1
		for Z=1 to World[0,0].length-1
			Value#=abs(Noise_Perlin3(X/freq#,Y/freq#,Z/freq#))
			if Value#>0.3 then World[X,Y,Z].CubeType=1
		next Z
	next Y
next X

Voxel_InitWorld(World)

do
    Print("FPS: "+str(ScreenFPS(),0))
    print(HitGridX)
    print(HitGridY)
    print(HitGridZ)
    
    ControlCamera()
    
    if GetRawMouseRightPressed()=1
	 	PointerX#=Get3DVectorXFromScreen(GetPointerX(),GetPointerY())
		PointerY#=Get3DVectorYFromScreen(GetPointerX(),GetPointerY())
		PointerZ#=Get3DVectorZFromScreen(GetPointerX(),GetPointerY())
	
		HitObjectID=ObjectRayCast(0,GetCameraX(1),GetCameraY(1),GetCameraZ(1),PointerX#*9999,PointerY#*9999,PointerZ#*9999)
		if HitObjectID>0
			HitPositionX#=GetObjectRayCastX(0)
			HitPositionY#=GetObjectRayCastY(0)
			HitPositionZ#=GetObjectRayCastZ(0)
			
			HitNormalX#=GetObjectRayCastNormalX(0)
			HitNormalY#=GetObjectRayCastNormalY(0)
			HitNormalZ#=GetObjectRayCastNormalZ(0)
			
			HitGridX=round(HitPositionX#-HitNormalX#*0.5)
			HitGridY=round(HitPositionY#-HitNormalY#*0.5)
			HitGridZ=round(HitPositionZ#-HitNormalZ#*0.5)
			
			Voxel_RemoveCubeFromObject(HitObjectID,World,HitGridX,HitGridY,HitGridZ)
		endif
	endif
    
    Sync()
loop
