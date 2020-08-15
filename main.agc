// Project: AppGameKit-VoxelEngine
// Created: 20-07-31

// show all errors
//~#include ".\..\Templates\ShaderPack\Includes\ShaderPack.agc"
SetErrorMode(2)

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
SetGenerateMipmaps(1)
SetDefaultMinFilter(0)
SetDefaultMagFilter(0)

//~local Subimages as SubimageData[]
//~Voxel_ReadSubimages("terrain subimages.txt", Subimages)

global Faceimages as FaceimageData
Voxel_ReadFaceImages("terrain subimages.txt","face indices.txt", Faceimages)

World as WorldData[257,33,257]

Noise_Init()
Noise_Seed(257)

//~for X=1 to World.length-1
//~	for Y=1 to World[0].length-1
//~		for Z=1 to World[0,0].length-1
//~			World[X,Y,Z].BlockType=1
//~		next Z
//~	next Y
//~next X

//~freq1#=32.0
//~freq2#=12.0
//~freq3#=4.0
//~for X=1 to World.length-1
//~	for Y=1 to World[0].length-1
//~		for Z=1 to World[0,0].length-1
//~			Value#=Noise_Perlin2(X/freq1#,Z/freq1#))*World[0].length
//~			MaxGrass=(World[0].length*0.7)+Value#/2
//~			MaxDirt=(World[0].length*0.64)+Value#/2
//~			MaxStone=(World[0].length*0.4)+Value#/2
//~			if Y>MaxDirt and Y<=MaxGrass
//~				World[X,Y,Z].BlockType=1
//~			elseif Y>MaxStone and Y<=MaxDirt
//~				World[X,Y,Z].BlockType=3
//~			elseif Y<=MaxStone
//~				World[X,Y,Z].BlockType=2

//~				ValueIron#=abs(Noise_Perlin3(X/freq3#,Y/freq3#,Z/freq3#))
//~				if ValueIron#>0.65 then World[X,Y,Z].BlockType=4
//~			endif

//~			ValueCaves#=abs(Noise_Perlin3(X/freq2#,Y/freq2#,Z/freq2#))
//~			if ValueCaves#>0.5 then World[X,Y,Z].BlockType=0
//~		next Z
//~	next Y
//~next X

Voxel_Init(World,"Terrain.png")

//~for ChunkX=0 to WorldSizeX
//~	for ChunkY=0 to WorldSizeY
//~		for ChunkZ=0 to WorldSizeZ
//~			Voxel_CreateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
//~		next ChunkZ
//~	next ChunkY
//~next ChunkX

SpawnX#=World.length/2
SpawnY#=World[0].length
SpawnZ#=World[0,0].length/2
SetCameraPosition(1,SpawnX#,SpawnY#,SpawnZ#)

LightID=1
CreatePointLight(LightID,0,0,0,12,255,255,255)

do
    print("FPS: "+str(ScreenFPS(),0))
	print(str(CubeX)+","+str(CubeY)+","+str(CubeZ))
//~	print(str(ChunkX)+","+str(ChunkY)+","+str(ChunkZ))
//~	print(str(ChunkEndX)+","+str(ChunkEndY)+","+str(ChunkEndZ))
//~	print(str(HitObjectID)+"/"+str(NeighbourObjectID))
	print(BlockType)


    OldCameraX#=GetCameraX(1)
    OldCameraY#=GetCameraY(1)
    OldCameraZ#=GetCameraZ(1)

    ControlCamera()

    NewCameraX#=GetCameraX(1)
    NewCameraY#=GetCameraY(1)
    NewCameraZ#=GetCameraZ(1)

//~    if ObjectSphereSlide(0,OldCameraX#,OldCameraY#,OldCameraZ#,NewCameraX#,NewCameraY#,NewCameraZ#,0.25)>0
//~		NewCameraX#=GetObjectRayCastSlideX(0)
//~		NewCameraY#=GetObjectRayCastSlideY(0)
//~		NewCameraZ#=GetObjectRayCastSlideZ(0)

//~		SetCameraPosition(1,NewCameraX#,NewCameraY#,NewCameraZ#)
//~	endif

//~	SetPointLightPosition(LightID,NewCameraX#,NewCameraY#,NewCameraZ#)

	Voxel_UpdateObjects(Faceimages,World,NewCameraX#,NewCameraY#,NewCameraZ#,3)

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

		X=HitGridX
		Y=HitGridY
		Z=HitGridZ

		ChunkX=round((X-1)/ChunkSize)
		ChunkY=round((Y-1)/ChunkSize)
		ChunkZ=round((Z-1)/ChunkSize)
		ChunkEndX=trunc(World.length/ChunkSize)
		ChunkEndY=trunc(World[0].length/ChunkSize)
		ChunkEndZ=trunc(World[0,0].length/ChunkSize)
		CubeX=1+Mod(X-1,ChunkSize)
		CubeY=1+Mod(Y-1,ChunkSize)
		CubeZ=1+Mod(Z-1,ChunkSize)
		NeighbourObjectID=1+(ChunkX)+ChunkY*ChunkSize+ChunkZ*ChunkSize*ChunkSize
	endif

	BlockType=BlockType+GetRawMouseWheelDelta()/3.0
	Voxel_Clamp(BlockType,1,Faceimages.FaceimageIndices.length)

    if GetRawMouseLeftPressed()=1
    	HitObjectID=ObjectRayCast(0,GetCameraX(1),GetCameraY(1),GetCameraZ(1),PointerX#*9999,PointerY#*9999,PointerZ#*9999)
    	if HitObjectID>0
			HitPositionX#=GetObjectRayCastX(0)
			HitPositionY#=GetObjectRayCastY(0)
			HitPositionZ#=GetObjectRayCastZ(0)

			HitNormalX#=GetObjectRayCastNormalX(0)
			HitNormalY#=GetObjectRayCastNormalY(0)
			HitNormalZ#=GetObjectRayCastNormalZ(0)

			HitGridX=round(HitPositionX#+HitNormalX#*0.5)
			HitGridY=round(HitPositionY#+HitNormalY#*0.5)
			HitGridZ=round(HitPositionZ#+HitNormalZ#*0.5)

			Voxel_AddCubeToObject(HitObjectID,Faceimages,World,HitGridX,HitGridY,HitGridZ,BlockType)
		endif
	endif

    if GetRawMouseRightPressed()=1
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

			BlockType=Voxel_RemoveCubeFromObject(HitObjectID,Faceimages,World,HitGridX,HitGridY,HitGridZ)
		endif
	endif

    Sync()
loop
