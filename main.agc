// Project: AppGameKit-VoxelEngine
// Created: 20-07-31

// #option_explicit

// show all errors
SetErrorMode(2)

//~#include ".\..\Templates\ShaderPack\Includes\ShaderPack.agc"
#include "constants.agc"
#include "core.agc"
#include "json.agc"
#include "noise.agc"
#include "voxel.agc"
#include "terrain.agc"
#include "controller.agc"
#include "logger.agc"

global Faceimages as FaceimageData
global World as WorldData

// set window properties
SetWindowTitle( "VoxelEngine" )
SetWindowSize( 1024, 768, 0 )
SetWindowAllowResize( 1 ) // allow the user to resize the window

// set display properties
SetVirtualResolution( 1024, 768 ) // doesn't have to match the window
SetOrientationAllowed( 1, 1, 1, 1 ) // allow both portrait and landscape on mobile devices
SetSyncRate( 0, 0 ) // 30fps instead of 60 to save battery
SetScissor( 0,0,0,0 ) // use the maximum available screen space, no black borders
UseNewDefaultFonts( 1 )

SetAntialiasMode(1)
SetCameraRange(1,0.25,100)
SetFogMode(1)
SetFogRange(80,99)
SetSkyBoxVisible(1)
SetGenerateMipmaps(0)
SetDefaultMinFilter(0)
SetDefaultMagFilter(0)

//~local Subimages as SubimageData[]
//~Voxel_ReadSubimages("terrain subimages.txt", Subimages)

Voxel_ReadFaceImages(VOXEL_TERRAIN_JSON, Faceimages)

Voxel_Init(World,16,128,32,128,"terrain.png")

Voxel_Generate_Terrain(257) // Generates the terrain by noise seed

//~ReadPath$=GetReadPath()
//~Filepath$="Raw:"+ReadPath$+"media/"+ WORLD_JSON

//Voxel_SaveWorld(VOXEL_WORLD_JSON, World)

SpawnX#=World.Terrain.length/2
SpawnY#=World.Terrain[0].length
SpawnZ#=World.Terrain[0,0].length/2
SetCameraPosition(1,SpawnX#,SpawnY#,SpawnZ#)


PreviewImageID=LoadImage("preview.png")
SetImageMinFilter(PreviewImageID,1)
SetImageMagFilter(PreviewImageID,1)
PreviewObjectID=CreateObjectBox(1.01,1.01,1.01)
SetObjectImage(PreviewObjectID,PreviewImageID,0)
SetObjectAlphaMask(PreviewObjectID,1)
SetObjectCollisionMode(PreviewObjectID,0)

//~LightID=1
//~CreatePointLight(LightID,0,0,0,10,255,255,255)
//~SetAmbientColor(8,8,8)


ChunkUpdateSwitch=1
do
    OldCameraX#=GetCameraX(1)
    OldCameraY#=GetCameraY(1)
    OldCameraZ#=GetCameraZ(1)

    Voxel_Controller_Camera()

    NewCameraX#=GetCameraX(1)
    NewCameraY#=GetCameraY(1)
    NewCameraZ#=GetCameraZ(1)

//~ if ObjectSphereSlide(0,OldCameraX#,OldCameraY#,OldCameraZ#,NewCameraX#,NewCameraY#,NewCameraZ#,0.25)>0
//~		NewCameraX#=GetObjectRayCastSlideX(0)
//~		NewCameraY#=GetObjectRayCastSlideY(0)
//~		NewCameraZ#=GetObjectRayCastSlideZ(0)

//~		SetCameraPosition(1,NewCameraX#,NewCameraY#,NewCameraZ#)
//~	endif

	if GetRawKeyPressed(KEY_F8) then ChunkUpdateSwitch=1-ChunkUpdateSwitch
	if ChunkUpdateSwitch=1 then Voxel_UpdateObjects(Faceimages,World,NewCameraX#,NewCameraY#,NewCameraZ#,2)

	BlockType=BlockType+GetRawMouseWheelDelta()/3.0
	BlockType=Voxel_Clamp(BlockType,1,Faceimages.FaceimageIndices.length)

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

		HitGridX=Round(HitPositionX#-HitNormalX#*0.5)
		HitGridY=Round(HitPositionY#-HitNormalY#*0.5)
		HitGridZ=Round(HitPositionZ#-HitNormalZ#*0.5)

		SetObjectPosition(PreviewObjectID,HitGridX,HitGridY,HitGridZ)

		ChunkX=Round((HitGridX-1)/Voxel_ChunkSize)
		ChunkY=Round((HitGridY-1)/Voxel_ChunkSize)
		ChunkZ=Round((HitGridZ-1)/Voxel_ChunkSize)
		
		CubeX=1+Mod(HitGridX-1,Voxel_ChunkSize)
		CubeY=1+Mod(HitGridY-1,Voxel_ChunkSize)
		CubeZ=1+Mod(HitGridZ-1,Voxel_ChunkSize)
		
		LightValue=World.Terrain[HitGridX,HitGridY+1,HitGridZ].LightValue
		
//~		SetPointLightPosition(LightID,HitPositionX#+HitNormalX#,HitPositionY#+HitNormalY#,HitPositionZ#+HitNormalZ#)
	endif

    if GetRawMouseLeftPressed()=1
    	if HitObjectID>0
			HitGridX=Round(HitPositionX#+HitNormalX#*0.5)
			HitGridY=Round(HitPositionY#+HitNormalY#*0.5)
			HitGridZ=Round(HitPositionZ#+HitNormalZ#*0.5)

			Voxel_AddCubeToObject(Faceimages,World,HitGridX,HitGridY,HitGridZ,BlockType)
		endif
	endif

    if GetRawMouseRightPressed()=1
    	if HitObjectID>0
			HitGridX=Round(HitPositionX#-HitNormalX#*0.5)
			HitGridY=Round(HitPositionY#-HitNormalY#*0.5)
			HitGridZ=Round(HitPositionZ#-HitNormalZ#*0.5)

			BlockType=Voxel_RemoveCubeFromObject(Faceimages,World,HitGridX,HitGridY,HitGridZ)
		endif
	endif

    Print("FPS: "+Str(ScreenFPS(),0))
    
	Voxel_Controller_Keyboard()

	if GetRawKeyState(KEY_F1)
		Print("Cube Position; "+str(CubeX)+","+str(CubeY)+","+str(CubeZ))
		Print("Object ID: "+str(HitObjectID))
		Print("Block Type: "+str(BlockType))
		Print("Light Value: "+str(LightValue))
		Print("Chunk Updating: "+str(ChunkUpdateSwitch))
	endif
    Sync()
loop
