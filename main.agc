// Project: AppGameKit-VoxelEngine
// Created: 20-07-31

// show all errors
//~#include ".\..\Templates\ShaderPack\Includes\ShaderPack.agc"
SetErrorMode(2)

#include "constants.agc"
#include "core.agc"
#include "json.agc"
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
SetPrintSize(16)

SetAntialiasMode(1)
SetCameraRange(1,0.25,100)
SetFogMode(1)
SetFogRange(80,99)
SetSkyBoxVisible(1)
SetGenerateMipmaps(0)
SetDefaultMinFilter(0)
SetDefaultMagFilter(0)

//~Create3DPhysicsWorld(5)

//~local Subimages as SubimageData[]
//~Voxel_ReadSubimages("terrain subimages.txt", Subimages)

global Faceimages as FaceimageData
Voxel_ReadFaceImages(TERRAIN_JSON, Faceimages)

World as WorldData

Voxel_Init(World,16,512,64,512,TERRAIN_IMG,"TestWorld")

SetupNoise (1,1,2,0.5)


TemplateCubeID=CreateObjectBox(1,1,1)

//~ReadPath$=GetReadPath()
//~Filepath$="Raw:"+ReadPath$+"media/world.json"
//~Voxel_SaveWorld(WORLD_JSON, World)

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
	if ChunkUpdateSwitch=1 then Voxel_UpdateChunks(Faceimages,World,NewCameraX#,NewCameraZ#,3)

	BlockType=BlockType+GetRawMouseWheelDelta()/3.0
	BlockType=Core_Clamp(BlockType,1,Faceimages.FaceimageIndices.length)

	Pointer2DX#=GetPointerX()
	Pointer2DY#=GetPointerY()
	
 	Pointer3DX#=Get3DVectorXFromScreen(Pointer2DX#,Pointer2DY#)
	Pointer3DY#=Get3DVectorYFromScreen(Pointer2DX#,Pointer2DY#)
	Pointer3DZ#=Get3DVectorZFromScreen(Pointer2DX#,Pointer2DY#)

	HitObjectID=ObjectRayCast(0,NewCameraX#,NewCameraY#,NewCameraZ#,NewCameraX#+Pointer3DX#*99,NewCameraY#+Pointer3DY#*99,NewCameraZ#+Pointer3DZ#*99)
	if HitObjectID>0
		HitPositionX#=GetObjectRayCastX(0)
		HitPositionY#=GetObjectRayCastY(0)
		HitPositionZ#=GetObjectRayCastZ(0)

		HitNormalX#=GetObjectRayCastNormalX(0)
		HitNormalY#=GetObjectRayCastNormalY(0)
		HitNormalZ#=GetObjectRayCastNormalZ(0)

		HitInsideX=round(HitPositionX#-HitNormalX#*0.5)
		HitInsideY=round(HitPositionY#-HitNormalY#*0.5)
		HitInsideZ=round(HitPositionZ#-HitNormalZ#*0.5)
		
		HitOutsideX=round(HitPositionX#+HitNormalX#*0.5)
		HitOutsideY=round(HitPositionY#+HitNormalY#*0.5)
		HitOutsideZ=round(HitPositionZ#+HitNormalZ#*0.5)
		
		SetObjectPosition(PreviewObjectID,HitInsideX,HitInsideY,HitInsideZ)

		ChunkX=trunc((HitInsideX-1)/Voxel_ChunkSize)
		ChunkZ=trunc((HitInsideZ-1)/Voxel_ChunkSize)
		
		CubeX=1+Mod(HitInsideX-1,Voxel_ChunkSize)
		CubeY=HitInsideY
		CubeZ=1+Mod(HitInsideZ-1,Voxel_ChunkSize)
		
		InsideBlockLight=World.Terrain[HitInsideX,HitInsideY,HitInsideZ].BlockLight
		OutsideBlockLight=World.Terrain[HitOutsideX,HitOutsideY,HitOutsideZ].BlockLight
		OutsideSunLight=World.Terrain[HitOutsideX,HitOutsideY,HitOutsideZ].SunLight
		
		Height=World.Height[HitInsideX,HitInsideZ]
		
//~		SetPointLightPosition(LightID,HitPositionX#+HitNormalX#,HitPositionY#+HitNormalY#,HitPositionZ#+HitNormalZ#)
	endif

    if GetRawMouseLeftPressed()=1
    	if HitObjectID>0 then Voxel_AddCubeToObject(World,HitOutsideX,HitOutsideY,HitOutsideZ,BlockType)
	endif

    if GetRawMouseRightPressed()=1
    	if HitObjectID>0 then BlockType=Voxel_RemoveCubeFromObject(World,HitInsideX,HitInsideY,HitInsideZ)
	endif
	
	if GetRawKeyPressed(KEY_SPACE)
		if HitObjectID>0
			ExplosionRadius=2
			
			CubeList as Int3Data[]
			TempCubePos as Int3Data
			for CubeX=HitInsideX-ExplosionRadius to HitInsideX+ExplosionRadius
				for CubeY=HitInsideY-ExplosionRadius to HitInsideY+ExplosionRadius
					for CubeZ=HitInsideZ-ExplosionRadius to HitInsideZ+ExplosionRadius
						DistX=CubeX-HitInsideX
						DistY=CubeY-HitInsideY
						DistZ=CubeZ-HitInsideZ
						Dist#=sqrt(DistX*DistX+DistY*DistY+DistZ*DistZ)
						if Dist#<=ExplosionRadius+0.5 and World.Terrain[CubeX,CubeY,CubeZ].BlockType>0
							TempCubePos.X=CubeX
							TempCubePos.Y=CubeY
							TempCubePos.Z=CubeZ
							CubeList.insert(TempCubePos)
						endif
					next CubeZ
				next CubeY
			next CubeX
			
			Voxel_RemoveCubeListFromObject(World,CubeList)
			CubeList.length=-1
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
    print("FPS: "+str(ScreenFPS(),0)+ ", FrameTime: "+str(GetFrameTime(),5))
	print("Cube; "+str(CubeX)+","+str(CubeY)+","+str(CubeZ))
	print("HitInside; "+str(HitInsideX)+","+str(HitInsideY)+","+str(HitInsideZ))
	print("HitOutside; "+str(HitOutsideX)+","+str(HitOutsideY)+","+str(HitOutsideZ))
	print("Height; "+str(Height))
	print("Chunk; "+str(ChunkX)+","+str(ChunkZ))
	print("Object ID: "+str(HitObjectID))
	print("Block Type: "+str(BlockType))
	print("Inside Block Light: "+str(InsideBlockLight))
	print("OutsideBlock Light: "+str(OutsideBlockLight))
	print("Outside Sun Light: "+str(OutsideSunLight))
	print("Chunk Updating: "+str(ChunkUpdateSwitch))
	print("Chunks in List: "+str(Voxel_LoadChunkList.length))
	Print("Mesh Update Time: "+str(Voxel_DebugMeshBuildingTime#))
	print("Save Time#: "+str(Voxel_DebugSaveTime#))
	
    Sync()
loop
