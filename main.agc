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
SetWindowSize( 1280, 720, 0 )
SetWindowAllowResize( 1 ) // allow the user to resize the window

// set display properties
SetVirtualResolution( 1024, 768 ) // doesn't have to match the window
SetOrientationAllowed( 1, 1, 1, 1 ) // allow both portrait and landscape on mobile devices
SetSyncRate( 0, 0 ) // 30fps instead of 60 to save battery
SetScissor( 0,0,0,0 ) // use the maximum available screen space, no black borders
UseNewDefaultFonts( 1 )
SetPrintSize(16)

SetAntialiasMode(1)
SetCameraRange(1,0.25,150)
SetFogMode(1)
SetFogRange(128,150)
SetSkyBoxVisible(1)
SetGenerateMipmaps(0)
SetDefaultMinFilter(0)
SetDefaultMagFilter(0)


Voxel_LoadBlockAttributes(TERRAIN_JSON)

World as WorldData

Voxel_Init(World,16,256,64,256,TERRAIN_IMG,"TestWorld")

SetupNoise (1,1,2,0.5)


TemplateCubeID=CreateObjectBox(1,1,1)

//~ReadPath$=GetReadPath()
//~Filepath$="Raw:"+ReadPath$+"media/world.json"
//~Voxel_SaveWorld(WORLD_JSON, World)

SpawnX#=Voxel_BlockMax.X/2
SpawnY#=Voxel_BlockMax.Y
SpawnZ#=Voxel_BlockMax.Z/2
Voxel_SetSpawn(SpawnX#,SpawnY#,SpawnZ#)

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
	if ChunkUpdateSwitch=1 then Voxel_UpdateChunks(World,NewCameraX#,NewCameraZ#,4)

	BlockType=BlockType+GetRawMouseWheelDelta()/3.0
	BlockType=Core_Clamp(BlockType,1,Voxel_Blocks.Attributes.length)
	BlockName$=Voxel_Blocks.Attributes[BlockType-1].Name$

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

		ChunkX=trunc(HitInsideX/Voxel_ChunkSize)
		ChunkZ=trunc(HitInsideZ/Voxel_ChunkSize)
		ChunkX=Core_Clamp(ChunkX,0,Voxel_ChunkMax.X)
		ChunkZ=Core_Clamp(ChunkZ,0,Voxel_ChunkMax.Z)
		
		LocalX=Mod(HitInsideX,Voxel_ChunkSize)
		LocalY=HitInsideY
		LocalZ=Mod(HitInsideZ,Voxel_ChunkSize)
		if LocalX<0 then inc LocalX,Voxel_ChunkSize
		if LocalZ<0 then inc LocalZ,Voxel_ChunkSize
		
		InsideBlockLight=World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,LocalY,LocalZ]
//~		OutsideBlockLight=World.Chunk[ChunkX,ChunkZ].BlockLight[HitOutsideX,HitOutsideY,HitOutsideZ]
//~		OutsideSunLight=World.Chunk[ChunkX,ChunkZ].SunLight[HitOutsideX,HitOutsideY,HitOutsideZ]
		
		Height=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
		
//~		SetPointLightPosition(LightID,HitPositionX#+HitNormalX#,HitPositionY#+HitNormalY#,HitPositionZ#+HitNormalZ#)
	endif

    if GetRawMouseLeftPressed()=1
    	if HitObjectID>0
    		Voxel_AddCubeToObject(World,HitOutsideX,HitOutsideY,HitOutsideZ,BlockType)
    	endif
	endif

    if GetRawMouseRightPressed()=1
    	if HitObjectID>0
    		BlockType=Voxel_RemoveCubeFromObject(World,HitInsideX,HitInsideY,HitInsideZ)
    	endif
	endif
	
	if GetRawKeyPressed(KEY_SPACE)
		if HitObjectID>0
			ExplosionRadius=2
			
			CubeList as Core_Int3Data[]
			TempCubePos as Core_Int3Data
			for GlobalX=HitInsideX-ExplosionRadius to HitInsideX+ExplosionRadius
				for GlobalY=HitInsideY-ExplosionRadius to HitInsideY+ExplosionRadius
					for GlobalZ=HitInsideZ-ExplosionRadius to HitInsideZ+ExplosionRadius
						DistX=GlobalX-HitInsideX
						DistY=GlobalY-HitInsideY
						DistZ=GlobalZ-HitInsideZ
						Dist#=sqrt(DistX*DistX+DistY*DistY+DistZ*DistZ)
						if Dist#<=ExplosionRadius+0.5 and Voxel_GetBlockType(World,GlobalX,GlobalY,GlobalZ)>0
							TempCubePos.X=GlobalX
							TempCubePos.Y=GlobalY
							TempCubePos.Z=GlobalZ
							CubeList.insert(TempCubePos)
						endif
					next GlobalZ
				next GlobalY
			next GlobalX
			
			Voxel_RemoveCubeListFromObject(World,CubeList)
			CubeList.length=-1
		endif
	endif

 	// TODO: Needs a click to reload
 	
	if GetRawKeyPressed(KEY_F4)
		local filest$ as string
		filest$ = TERRAIN_JSON
		Voxel_SaveBlockAttributes(filest$)
		Message("Textures / subimages saved in " + filest$)
	endif
	
	if GetRawKeyPressed(KEY_F5)
		local filert$ as string
		filert$ = TERRAIN_JSON
		Voxel_LoadBlockAttributes(filert$)
		Message("Textures / subimages loaded from " + filert$)
	endif

	// TODO A complete Logging by pressing any key
    print("FPS: "+str(ScreenFPS(),0)+ ", FrameTime: "+str(GetFrameTime(),5))
	print("Local; "+str(LocalX)+","+str(LocalY)+","+str(LocalZ))
	print("HitInside; "+str(HitInsideX)+","+str(HitInsideY)+","+str(HitInsideZ))
	print("HitOutside; "+str(HitOutsideX)+","+str(HitOutsideY)+","+str(HitOutsideZ))
	print("Height; "+str(Height))
	print("Chunk; "+str(ChunkX)+","+str(ChunkZ))
	print("Object ID: "+str(HitObjectID))
	print("Block Type: "+str(BlockType))
	print("Block Name: "+BlockName$)
	print("Inside Block Light: "+str(InsideBlockLight))
//~	print("OutsideBlock Light: "+str(OutsideBlockLight))
//~	print("Outside Sun Light: "+str(OutsideSunLight))
	print("Chunk Updating: "+str(ChunkUpdateSwitch))
	print("Chunks in List: "+str(Voxel_LoadChunkList.length))
	Print("Chunk Time: "+str(Voxel_DebugChunkTime#))
	Print("Mesh Time: "+str(Voxel_DebugMeshTime#))
	print("Noise Time: "+str(Voxel_DebugNoiseTime#))
	print("Save Time: "+str(Voxel_DebugSaveTime#))
	print("Load Time: "+str(Voxel_DebugLoadTime#))
	print("Sun Time: "+str(Voxel_DebugSunTime#))
	print("Frontier Itterations: "+str(Voxel_DebugIterations))	
	
    Sync()
loop
