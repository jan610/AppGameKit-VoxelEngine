// Project: AppGameKit-VoxelEngine
// Created: 20-07-31

// show all errors
//~#include ".\..\Templates\ShaderPack\Includes\ShaderPack.agc"
SetErrorMode(2)

#include "constants.agc"
#include "core.agc"
#include "json.agc"
#include "noise.agc"
#include "voxel.agc"
#include "camera.agc"

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

global Faceimages as FaceimageData
Voxel_ReadFaceImages(TERRAIN_JSON, Faceimages)

World as WorldData

Voxel_Init(World,16,128,32,128,TERRAIN_IMG)

Noise_Init()
Noise_Seed(257)

freq1#=32.0
freq2#=12.0
freq3#=2.0
for X=0 to World.Terrain.length
	for Y=0 to World.Terrain[0].length
		for Z=0 to World.Terrain[0,0].length
			Value1#=Noise_Perlin2(X/freq1#,Z/freq1#)*World.Terrain[0].length
			Value2#=Noise_Perlin3(X/freq2#,Y/freq2#,Z/freq2#)
			MaxGrass=(World.Terrain[0].length*0.7)+Value1#/2
			MaxDirt=(World.Terrain[0].length*0.64)+Value1#/2
			MaxStone=(World.Terrain[0].length*0.4)+Value1#/2
			if Y>MaxDirt and Y<=MaxGrass
				World.Terrain[X,Y,Z].BlockType=1
			elseif Y>MaxStone and Y<=MaxDirt
				World.Terrain[X,Y,Z].BlockType=3
			elseif Y<=MaxStone
				World.Terrain[X,Y,Z].BlockType=2
				Value3#=Noise_Perlin3(X/freq3#,Y/freq3#,Z/freq3#)
				if Value3#>0.68 then World.Terrain[X,Y,Z].BlockType=4
			endif
			if Value2#>0.5 then World.Terrain[X,Y,Z].BlockType=0
			World.Terrain[X,Y,Z].LightValue=15
		next Z
	next Y
next X
/*
for ChunkX=0 to World.Chunk.length
	for ChunkY=0 to World.Chunk[0].length
		for ChunkZ=0 to World.Chunk[0,0].length
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.X=ChunkX*Voxel_ChunkSize+1
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Y=ChunkY*Voxel_ChunkSize+1
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Z=ChunkZ*Voxel_ChunkSize+1
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.X=ChunkX*Voxel_ChunkSize+Voxel_ChunkSize
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Y=ChunkY*Voxel_ChunkSize+Voxel_ChunkSize
			World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Z=ChunkZ*Voxel_ChunkSize+Voxel_ChunkSize
//~			Voxel_UpdateLight(World.Chunk[ChunkX,ChunkY,ChunkZ],World)
			Voxel_CreateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ],World)
		next ChunkZ
	next ChunkY
next ChunkX
*/

//~ReadPath$=GetReadPath()
//~Filepath$="Raw:"+ReadPath$+"media/world.json"
Voxel_SaveWorld(WORLD_JSON, World)

SpawnX#=World.Terrain.length/2
SpawnY#=World.Terrain[0].length
SpawnZ#=World.Terrain[0,0].length/2
SetCameraPosition(1,SpawnX#,SpawnY#,SpawnZ#)


PreviewImageID=LoadImage(PREVIEW_IMG)
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

    ControlCamera()

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

		HitGridX=round(HitPositionX#-HitNormalX#*0.5)
		HitGridY=round(HitPositionY#-HitNormalY#*0.5)
		HitGridZ=round(HitPositionZ#-HitNormalZ#*0.5)

		SetObjectPosition(PreviewObjectID,HitGridX,HitGridY,HitGridZ)

		ChunkX=round((HitGridX-1)/Voxel_ChunkSize)
		ChunkY=round((HitGridY-1)/Voxel_ChunkSize)
		ChunkZ=round((HitGridZ-1)/Voxel_ChunkSize)
		
		CubeX=1+Mod(HitGridX-1,Voxel_ChunkSize)
		CubeY=1+Mod(HitGridY-1,Voxel_ChunkSize)
		CubeZ=1+Mod(HitGridZ-1,Voxel_ChunkSize)
		
		LightValue=World.Terrain[HitGridX,HitGridY+1,HitGridZ].LightValue
		
//~		SetPointLightPosition(LightID,HitPositionX#+HitNormalX#,HitPositionY#+HitNormalY#,HitPositionZ#+HitNormalZ#)
	endif

    if GetRawMouseLeftPressed()=1
    	if HitObjectID>0
			HitGridX=round(HitPositionX#+HitNormalX#*0.5)
			HitGridY=round(HitPositionY#+HitNormalY#*0.5)
			HitGridZ=round(HitPositionZ#+HitNormalZ#*0.5)

			Voxel_AddCubeToObject(Faceimages,World,HitGridX,HitGridY,HitGridZ,BlockType)
		endif
	endif

    if GetRawMouseRightPressed()=1
    	if HitObjectID>0
			HitGridX=round(HitPositionX#-HitNormalX#*0.5)
			HitGridY=round(HitPositionY#-HitNormalY#*0.5)
			HitGridZ=round(HitPositionZ#-HitNormalZ#*0.5)

			BlockType=Voxel_RemoveCubeFromObject(Faceimages,World,HitGridX,HitGridY,HitGridZ)
		endif
	endif

 	// TODO: Needs a click to reload
 	
	if GetRawKeyPressed(KEY_F4)
		local filest$ as string
		filest$ = TERRAIN_JSON
		Voxel_SaveFaceImages(filest$, FaceImages)
		Message("Textures / subimages saved in " + filest$)
	endif
	
	if GetRawKeyPressed(KEY_F5)
		local filert$ as string
		filert$ = TERRAIN_JSON
		Voxel_ReadFaceImages(filert$, FaceImages)
		Message("Textures / subimages loaded from " + filert$)
	endif

	if GetRawKeyPressed(KEY_F6)
 		local filesw$ as string
	 	filesw$ = WORLD_JSON
	 	Voxel_SaveWorld(filesw$, World)
	 	Message("World saved in " + filesw$)
	endif
	
	if GetRawKeyPressed(KEY_F7)
 		local filerw$ as string
	 	filerw$ = WORLD_JSON
	 	Voxel_ReadWorld(filerw$, World)
	 	Message("World loaded from " + filerw$)
	endif

	// TODO A complete Logging by pressing any key
    print("FPS: "+str(ScreenFPS(),0))
	print("Cube Position; "+str(CubeX)+","+str(CubeY)+","+str(CubeZ))
	print("Object ID: "+str(HitObjectID))
	print("Block Type: "+str(BlockType))
	print("Light Value: "+str(LightValue))
	print("Chunk Updating: "+str(ChunkUpdateSwitch))
	
    Sync()
loop
