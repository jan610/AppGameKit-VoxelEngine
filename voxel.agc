#import_plugin OpenSimplexNoise as Noise
#include "threadnoise.agc"

// Data Types able to represent any AGK mesh
type Vec4Data
	X#
	Y#
	Z#
	W#
endtype

type Vec3Data
	X#
	Y#
	Z#
endtype

type Vec2Data
	X#
	Y#
endtype

type RGBAData
	Red#
	Green#
	Blue#
	Alpha#
endtype

type VertexData
	Pos as Vec3Data
	UV as Vec2Data
	Color as RGBAData
	Normal as Vec3Data
	Tangent as Vec3Data
	Bitangent as Vec3Data
endtype

type ObjectData
	Vertex as VertexData[]
	Index as integer[]
endtype

#constant FaceFront	1
#constant FaceBack	2
#constant FaceLeft	3
#constant FaceRight	4
#constant FaceUp		5
#constant FaceDown	6


type WorldData
	HeightMap as HeightMapData[-1]
	HeightMapID as integer[-1,-1]
    Chunk as ChunkData[-1]
    ChunkID as integer[-1,-1,-1]
endtype

type ChunkData
    ObjectID as integer
    Blocks as BlockData[15,15,15]
    Lights as LightData[-1]
endtype

type HeightMapData
	Height as integer[15,15]
endtype

type BlockData
    BlockType as integer
    LightValue as integer
endtype

type LightData
	Position as vec2Data
	Value as integer
endtype

type SubimageData
	X as integer
	Y as integer
	Width as integer
	Height as integer
endtype

type FaceIndexData
	FrontID as integer
	BackID as integer
	UpID as integer
	DownID as integer
	LeftID as integer
	RightID as integer
endtype

type FaceimageData
	Subimages as SubimageData[]
	FaceimageIndices as FaceIndexData[]
endtype

type Int3Data
	X as integer
	Y as integer
	Z as integer
endtype

type BorderData
	Min as Int3Data
	Max as Int3Data
endtype

type MemblockData
	GrassMemblockID as integer
	CaveMemblockID as integer
	IronMemblockID as integer
	Position as Int3Data
endtype

type FrontierData
	X as integer
	Y as integer
	Z as integer
	LightValue as integer
endtype

global Voxel_Neighbors as Int3Data[5]
global Voxel_ChunkMemblock as MemblockData[]
global Voxel_ChunkRing as Int3Data[]
global Voxel_ChunkBuild as Int3Data[]
global Voxel_ChunkOutside as Int3Data[]
global TempBlocks as ChunkData
global TempSubimages as SubimageData[5]
global TempVertex as VertexData[3]
global TempHeightMap as HeightMapData
global AddLightFrontier as Int3Data[]
global RemoveLightFrontier as FrontierData[]


global Voxel_ChunkSize
global Voxel_WorldSizeX
global Voxel_WorldSizeY
global Voxel_WorldSizeZ
global Voxel_DiffuseImageID
global Voxel_NormalImageID
global Voxel_ShaderID
global Voxel_ChunkPositionX
global Voxel_ChunkPositionY
global Voxel_ChunkPositionZ
global Voxel_ChunkPositionDist

global Voxel_NoiseShaderID
global Voxel_NoiseRenderImageID
global Voxel_NoiseQuadID

global Voxel_OldCameraChunkX
global Voxel_OldCameraChunkY
global Voxel_OldCameraChunkZ

global Voxel_index

global Voxel_Frecueny2D#
global Voxel_Frecueny3DCave#
global Voxel_Frecueny3DIron#

global Voxel_DebugMeshBuildingTime#

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData,ChunkSize,WorldSizeX,WorldSizeY,WorldSizeZ,File$)
	Voxel_DiffuseImageID=LoadImage(File$)
//~	Voxel_NormalImageID=LoadImage(StringInsertAtDelemiter(File$,"_n.","."))
	
	Voxel_ShaderID=LoadShader("shader/vertex.vs","shader/fragment.ps")
	
	Voxel_ChunkSize=ChunkSize
	Voxel_WorldSizeX=WorldSizeX*Voxel_ChunkSize
	Voxel_WorldSizeY=WorldSizeY*Voxel_ChunkSize
	Voxel_WorldSizeZ=WorldSizeZ*Voxel_ChunkSize
		
	World.ChunkID.length=WorldSizeX
	for X=0 to World.ChunkID.length
		World.ChunkID[X].length=WorldSizeY
		for Y=0 to World.ChunkID[X].length
			World.ChunkID[X,Y].length=WorldSizeZ
			for Z=0 to World.ChunkID[X,Y].length
				World.ChunkID[X,Y,Z]=-1
			next Z
		next Y
	next X
	
	World.HeightMapID.length=WorldSizeX
	for X=0 to World.HeightMapID.length
		World.HeightMapID[X].length=WorldSizeZ
		for Z=0 to World.HeightMapID[X].length
			World.HeightMapID[X,Z]=-1
		next Z
	next X	
	
	Voxel_Frecueny2D#=32.0
	Voxel_Frecueny3DCave#=10.0
	Voxel_Frecueny3DIron#=2.0
	
	Voxel_Neighbors[0].x=1
	Voxel_Neighbors[0].y=0
	Voxel_Neighbors[0].z=0
	
	Voxel_Neighbors[1].x=0
	Voxel_Neighbors[1].y=1
	Voxel_Neighbors[1].z=0
	
	Voxel_Neighbors[2].x=0
	Voxel_Neighbors[2].y=0
	Voxel_Neighbors[2].z=1
	
	Voxel_Neighbors[3].x=-1
	Voxel_Neighbors[3].y=0
	Voxel_Neighbors[3].z=0
	
	Voxel_Neighbors[4].x=0
	Voxel_Neighbors[4].y=-1
	Voxel_Neighbors[4].z=0
	
	Voxel_Neighbors[5].x=0
	Voxel_Neighbors[5].y=0
	Voxel_Neighbors[5].z=-1
	
	Voxel_NoiseShaderID=LoadFullScreenShader("Shader/simplexnoise.ps")
	Voxel_NoiseRenderImageID=CreateRenderImage(ChunkSize,ChunkSize*4,0,0)
	Voxel_NoiseQuadID=CreateObjectQuad()
	SetObjectShader(Voxel_NoiseQuadID,Voxel_NoiseShaderID)
	
	Noise.Init(100)
endfunction

function Voxel_ReadFaceImages(FaceImagesFile$, Faceimages ref as FaceimageData)
	local string$ as string
	string$ = Voxel_JSON_Load(FaceImagesFile$)
	Faceimages.fromJSON(string$)
endfunction

function Voxel_SaveFaceImages(FaceIMagesFile$, Faceimages as FaceimageData)
	local string$ as string
	string$ = Faceimages.toJSON()
	Voxel_JSON_Save(string$ , FaceIMagesFile$)
endfunction

function Voxel_ReadWorld(WorldFile$, World ref as WorldData)
	local string$ as string
	string$ = Voxel_JSON_Load(WorldFile$)
	World.fromJSON(string$)
endfunction

function Voxel_SaveWorld(WorldFile$, World as WorldData)
	local string$ as string	
	string$ = World.toJSON()
	Voxel_JSON_Save(string$ , WorldFile$)
endfunction

function Voxel_GetEntryInArray(Array ref as Int3Data[],Entry as Int3Data)
	local Index as integer
	for Index=0 to Array.length
		if Array[Index].X=Entry.X and Array[Index].Y=Entry.Y and Array[Index].Z=Entry.Z then exitfunction Index
	next Index
endfunction -1

function Voxel_UpdateObjects(FaceImages ref as FaceimageData,World ref as WorldData,PosX,PosY,PosZ,ViewDistance)
	CameraChunkX=round(PosX/Voxel_ChunkSize)
	CameraChunkY=round(PosY/Voxel_ChunkSize)
	CameraChunkZ=round(PosZ/Voxel_ChunkSize)
	
	local TempChunkMemblock as MemblockData
	local TempChunkElement as Int3Data
	
	
//~	if CameraChunkX<>Voxel_OldCameraChunkX and CameraChunkY<>Voxel_OldCameraChunkY and CameraChunkZ<>Voxel_OldCameraChunkZ
//~		Voxel_OldCameraChunkX=CameraChunkX
//~		Voxel_OldCameraChunkY=CameraChunkY
//~		Voxel_OldCameraChunkZ=CameraChunkZ
		
//~		for Dist=1 to ViewDistance+1
			Dist=ViewDistance+1
			NoiseMinX=Voxel_Clamp(CameraChunkX-Dist,0,World.ChunkID.length)
//~			NoiseMinY=Voxel_Clamp(CameraChunkY-Dist,0,World.ChunkID[0].length)
			NoiseMinZ=Voxel_Clamp(CameraChunkZ-Dist,0,World.ChunkID[0,0].length)
			NoiseMaxX=Voxel_Clamp(CameraChunkX+Dist,0,World.ChunkID.length)
//~			NoiseMaxY=Voxel_Clamp(CameraChunkY+Dist,0,World.ChunkID[0].length)
			NoiseMaxZ=Voxel_Clamp(CameraChunkZ+Dist,0,World.ChunkID[0,0].length)

			for ChunkX=NoiseMinX to NoiseMaxX
				for ChunkZ=NoiseMinZ to NoiseMaxZ
					
//~					if World.HeightMapID[ChunkX,ChunkZ]=-1
//~						World.HeightMap.insert(TempHeightMap)
//~						HeightMapID=World.HeightMap.length
//~						World.HeightMapID[ChunkX,ChunkZ]=HeightMapID
//~					endif
					
					for ChunkY=World.ChunkID[0].length-1 to 0 step -1
						if World.ChunkID[ChunkX,ChunkY,ChunkZ]=-1

							World.Chunk.insert(TempBlocks)
							ChunkID=World.Chunk.length
							World.ChunkID[ChunkX,ChunkY,ChunkZ]=ChunkID
							
							MinX=ChunkX*Voxel_ChunkSize
							MinY=ChunkY*Voxel_ChunkSize
							MinZ=ChunkZ*Voxel_ChunkSize
							MaxX=MinX+Voxel_ChunkSize
							MaxY=MinY+Voxel_ChunkSize
							MaxZ=MinZ+Voxel_ChunkSize
							Width=MaxX-MinX
							Height=MaxY-MinY
							Depth=MaxZ-MinZ

							NoiseGrassMemblockID=TN_CreateMemblockNoise2D(Voxel_Frecueny2D#,MinX,MinZ,Width,Depth)
							NoiseCaveMemblockID=TN_CreateMemblockNoise3D(Voxel_Frecueny3DCave#,MinX,MinY,MinZ,Width,Height,Depth)
							NoiseIronMemblockID=TN_CreateMemblockNoise3D(Voxel_Frecueny3DIron#,MinX,MinY,MinZ,Width,Height,Depth)

							TempChunkMemblock.GrassMemblockID=NoiseGrassMemblockID
							TempChunkMemblock.CaveMemblockID=NoiseCaveMemblockID
							TempChunkMemblock.IronMemblockID=NoiseIronMemblockID
							
							TempChunkMemblock.Position.X=ChunkX
							TempChunkMemblock.Position.Y=ChunkY
							TempChunkMemblock.Position.Z=ChunkZ
							Voxel_ChunkMemblock.insert(TempChunkMemblock)
						endif
					next ChunkY
				next ChunkZ
			next ChunkX
//~		next Dist
//~	endif

	
	DirtLayerHeight=3
//~	if Voxel_ChunkMemblock.length>-1
  	for index=0 to Voxel_ChunkMemblock.length
  		
//~  		ChunkX=Voxel_ChunkMemblock[index].Position.X
//~			ChunkY=Voxel_ChunkMemblock[index].Position.Y
//~			ChunkZ=Voxel_ChunkMemblock[index].Position.Z
//~			Voxel_ChunkMemblock.remove(index)
//~			
//~			Voxel_CreateGpuNoise(World,ChunkX,ChunkY,ChunkZ)	
//~			
//~			TempChunkElement.X=ChunkX
//~			TempChunkElement.Y=ChunkY
//~			TempChunkElement.Z=ChunkZ
//~			Voxel_ChunkRing.insert(TempChunkElement)
  		
  		
		NoiseGrassMemblockID=Voxel_ChunkMemblock[index].GrassMemblockID
		NoiseCaveMemblockID=Voxel_ChunkMemblock[index].CaveMemblockID
		NoiseIronMemblockID=Voxel_ChunkMemblock[index].IronMemblockID
		
		if TN_GetNoiseReady(NoiseGrassMemblockID) and TN_GetNoiseReady(NoiseCaveMemblockID) and TN_GetNoiseReady(NoiseIronMemblockID)
			ChunkX=Voxel_ChunkMemblock[index].Position.X
			ChunkY=Voxel_ChunkMemblock[index].Position.Y
			ChunkZ=Voxel_ChunkMemblock[index].Position.Z
			Voxel_ChunkMemblock.remove(index)
		
			Offset2D=0
			Offset3D=0
//~			HeightMapID=World.HeightMapID[ChunkX,ChunkZ]
			ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
			for CubeX=0 to Voxel_ChunkSize-1
				for CubeZ=0 to Voxel_ChunkSize-1
					inc Offset2D,4
					for CubeY=0 to Voxel_ChunkSize-1
						inc Offset3D,4

						GrassNoise#=(GetMemblockFloat(NoiseGrassMemblockID,Offset2D)+1.0*0.25)*World.ChunkID[0].length*Voxel_ChunkSize
						GrassLayer=(World.ChunkID[0].length*Voxel_ChunkSize*0.4)+GrassNoise#/3.0
						
						if ChunkY*Voxel_ChunkSize+CubeY=GrassLayer
							World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=1
						elseif ChunkY*Voxel_ChunkSize+CubeY>GrassLayer-DirtLayerHeight and ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer
							World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=3
						elseif ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer-DirtLayerHeight
							World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=2
							IronNoise#=GetMemblockFloat(NoiseIronMemblockID,Offset3D)+1.0*0.25
							if IronNoise#>0.68 then World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=4
						endif
						
						CaveNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
						
						if CaveNoise#>0.8//+CubeY/(World.ChunkID[0].length*Voxel_ChunkSize+0.0)
							World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
						endif
						
						World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=8
					next CubeY
					/*
					if World.HeightMap[HeightMapID].Height[CubeX,CubeZ]=0
//~						WorldX=CubeX+ChunkX*Voxel_ChunkSize
//~						WorldZ=CubeZ+ChunkZ*Voxel_ChunkSize
//~						for WorldY=Voxel_WorldSizeY to 0 step -1
//~							if Voxel_GetBlockType(World,WorldX,WorldY,WorldZ)=0 then exit
//~						next WorldY
						World.HeightMap[HeightMapID].Height[CubeX,CubeZ]=GrassLayer
					endif
					*/
				next CubeZ
			next CubeX
			
			DeleteMemblock(NoiseGrassMemblockID)
			DeleteMemblock(NoiseCaveMemblockID)
			DeleteMemblock(NoiseIronMemblockID)
			
			TempChunkElement.X=ChunkX
			TempChunkElement.Y=ChunkY
			TempChunkElement.Z=ChunkZ
			Voxel_ChunkRing.insert(TempChunkElement)
		endif
	next index
//~	endif

	if Voxel_ChunkMemblock.length=-1
		ViewMinX=Voxel_Clamp(CameraChunkX-ViewDistance,0,World.ChunkID.length)
		ViewMinZ=Voxel_Clamp(CameraChunkZ-ViewDistance,0,World.ChunkID[0,0].length)
		ViewMaxX=Voxel_Clamp(CameraChunkX+ViewDistance,0,World.ChunkID.length)
		ViewMaxZ=Voxel_Clamp(CameraChunkZ+ViewDistance,0,World.ChunkID[0,0].length)
			
		for index=0 to Voxel_ChunkRing.length
			ChunkX=Voxel_ChunkRing[index].X
			ChunkY=Voxel_ChunkRing[index].Y
			ChunkZ=Voxel_ChunkRing[index].Z
			
			if ChunkX>=ViewMinX and ChunkX<=ViewMaxX and ChunkZ>=ViewMinZ and ChunkZ<=ViewMaxZ
				Voxel_ChunkRing.remove(index)
				
				TempChunkElement.X=ChunkX
				TempChunkElement.Y=ChunkY
				TempChunkElement.Z=ChunkZ
				Voxel_ChunkBuild.insert(TempChunkElement)
			endif
		next index
	endif

	if Voxel_ChunkBuild.length>-1
		ChunkX=Voxel_ChunkBuild[0].X
		ChunkY=Voxel_ChunkBuild[0].Y
		ChunkZ=Voxel_ChunkBuild[0].Z
		Voxel_ChunkBuild.remove(0)
		
		ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
		if World.Chunk[ChunkID].ObjectID=0	
			
//~			Voxel_UpdateSunLight(World,ChunkX,ChunkY,ChunkZ)
//~			Voxel_UpdatePointLights(World,8)
			
//~			Voxel_DebugMeshBuildingTime#=Timer()
			ObjectID=Voxel_CreateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
//~			message(str(Timer()-Voxel_DebugMeshBuildingTime#))

//~			if GetObjectExists(ObjectID)
//~				Create3DPhysicsStaticBody(ObjectID)
//~				SetObjectShapeStaticPolygon(ObjectID)
//~			endif
		else
			Voxel_UpdateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
			
//~			Delete3DPhysicsBody(World.Chunk[ChunkID].ObjectID)
//~			Create3DPhysicsStaticBody(World.Chunk[ChunkID].ObjectID)
//~			SetObjectShapeStaticPolygon(World.Chunk[ChunkID].ObjectID)
		endif
	endif
	
	Voxel_UpdatePointLights(World,8)
	
	print(Voxel_ChunkMemblock.length)
	print(Voxel_ChunkRing.length)
	print(Voxel_ChunkBuild.length)
endfunction

function Voxel_CreateThreadNoise(World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	DirtLayerHeight=3
	
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	MinX=ChunkX*Voxel_ChunkSize
	MinY=ChunkY*Voxel_ChunkSize
	MinZ=ChunkZ*Voxel_ChunkSize
	MaxX=ChunkX*Voxel_ChunkSize+Voxel_ChunkSize
	MaxY=ChunkY*Voxel_ChunkSize+Voxel_ChunkSize
	MaxZ=ChunkZ*Voxel_ChunkSize+Voxel_ChunkSize
	Width=MaxX-MinX
	Height=MaxY-MinY
	Depth=MaxZ-MinZ
	
	NoiseGrassMemblockID=TN_CreateMemblockNoise2D(Voxel_Frecueny2D#,MinX,MinZ,Width,Depth)
	NoiseCaveMemblockID=TN_CreateMemblockNoise3D(Voxel_Frecueny3DCave#,MinX,MinY,MinZ,Width,Height,Depth)
	NoiseIronMemblockID=TN_CreateMemblockNoise3D(Voxel_Frecueny3DIron#,MinX,MinY,MinZ,Width,Height,Depth)
	
	TN_WaitForNoise(NoiseGrassMemblockID)
	TN_WaitForNoise(NoiseCaveMemblockID)
	TN_WaitForNoise(NoiseIronMemblockID)
				
	Offset2D=0
	Offset3D=0
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	for CubeX=0 to Voxel_ChunkSize-1
		for CubeZ=0 to Voxel_ChunkSize-1
			inc Offset2D,4
			for CubeY=0 to Voxel_ChunkSize-1
				inc Offset3D,4
				
				GrassNoise#=(GetMemblockFloat(NoiseGrassMemblockID,Offset2D)+1.0*0.25)*World.ChunkID[0].length*Voxel_ChunkSize
				GrassLayer=(World.ChunkID[0].length*Voxel_ChunkSize*0.4)+GrassNoise#/3.0
				
				if ChunkY*Voxel_ChunkSize+CubeY=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=1
				elseif ChunkY*Voxel_ChunkSize+CubeY>GrassLayer-DirtLayerHeight and ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=3
				elseif ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer-DirtLayerHeight
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=2
					IronNoise#=GetMemblockFloat(NoiseIronMemblockID,Offset3D)+1.0*0.25
					if IronNoise#>0.68 then World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=4
				endif
				
				CaveNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
				
				if CaveNoise#>0.8//+CubeY/(World.ChunkID[0].length*Voxel_ChunkSize+0.0)
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
				endif
				
				World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=8
			next CubeY
		next CubeZ
	next CubeX
	
	DeleteMemblock(NoiseGrassMemblockID)
	DeleteMemblock(NoiseCaveMemblockID)
	DeleteMemblock(NoiseIronMemblockID)
endfunction

function Voxel_CreateGpuNoise(World ref as WorldData,ChunkX,ChunkY,ChunkZ)			
	Voxel_RenderNoise(ChunkX,ChunkY,ChunkZ)
	MemblockID=CreateMemblockFromImage(Voxel_NoiseRenderImageID)
	Width=GetMemblockInt(MemblockID,0)
		
	for Z=0 to 12 step 4
		CubeZ=ChunkX*Voxel_ChunkSize+Z
		for Y=0 to 15
			CubeY=ChunkY*Voxel_ChunkSize+Y
			for X=0 to 15
				Offset=(4*((floor(Z/4.0)*Width*16)+(Y*Width)+X))+12
				CubeX=ChunkX*Voxel_ChunkSize+X
				Color=GetMemblockInt(MemblockID,Offset)
				
				if GetColorRed(Color)>0.5 then Voxel_SetBlockType(World,CubeX,CubeY,CubeZ+0,2)
				if GetColorGreen(Color)>0.5 then Voxel_SetBlockType(World,CubeX,CubeY,CubeZ+1,2)
				if GetColorBlue(Color)>0.5 then Voxel_SetBlockType(World,CubeX,CubeY,CubeZ+2,2)
				if GetColorAlpha(Color)>0.5 then Voxel_SetBlockType(World,CubeX,CubeY,CubeZ+3,2)
				
				Voxel_SetBlockLight(World,CubeX,CubeY,CubeZ+0,8)
				Voxel_SetBlockLight(World,CubeX,CubeY,CubeZ+1,8)
				Voxel_SetBlockLight(World,CubeX,CubeY,CubeZ+2,8)
				Voxel_SetBlockLight(World,CubeX,CubeY,CubeZ+3,8)
			next X
		next Y
	next Z
endfunction

function Voxel_RenderNoise(OffsetX,OffsetY,OffsetZ)
	SetShaderConstantByName(Voxel_NoiseShaderID,"uvOffset",OffsetX,OffsetY,OffsetZ,0)
	SetRenderToImage(Voxel_NoiseRenderImageID,0)
	ClearScreen()
	DrawObject(Voxel_NoiseQuadID)
	SetRenderToScreen()
endfunction

function Voxel_CreateSoftwareNoise(World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	DirtLayerHeight=3
	
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	for CubeX=0 to Voxel_ChunkSize-1
		for CubeZ=0 to Voxel_ChunkSize-1
			for CubeY=0 to Voxel_ChunkSize-1
				
				GrassNoise#=Noise_Perlin2(CubeX/Voxel_Frecueny2D#,CubeZ/Voxel_Frecueny2D#)*World.ChunkID[0].length*Voxel_ChunkSize
				GrassLayer=(World.ChunkID[0].length*Voxel_ChunkSize*0.4)+GrassNoise#/3.0
				
				if ChunkY*Voxel_ChunkSize+CubeY=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=1
				elseif ChunkY*Voxel_ChunkSize+CubeY>GrassLayer-DirtLayerHeight and ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=3
				elseif ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer-DirtLayerHeight
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=2
					IronNoise#=Noise_Perlin3(CubeX/Voxel_Frecueny3DIron#,CubeY/Voxel_Frecueny3DIron#,CubeZ/Voxel_Frecueny3DIron#)
					if IronNoise#>0.68 then World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=4
				endif
				
				CaveNoise#=Noise_Perlin3(CubeX/Voxel_Frecueny3DCave#,CubeY/Voxel_Frecueny3DCave#,CubeZ/Voxel_Frecueny3DCave#)
				
				if CaveNoise#>0.8//+CubeY/(World.ChunkID[0].length*Voxel_ChunkSize+0.0)
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
				endif
				
				World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=8
			next CubeY
		next CubeZ
	next CubeX
endfunction

function Voxel_UpdateSunLight(World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	local TempAddFrontier as Int3Data
	
	WorldChunkX=ChunkX*Voxel_ChunkSize
	WorldChunkY=ChunkY*Voxel_ChunkSize
	WorldChunkZ=ChunkZ*Voxel_ChunkSize
	
	HeightMapID=World.HeightMapID[ChunkX,ChunkZ]
	for CubeX=0 to Voxel_ChunkSize-1
		for CubeZ=0 to Voxel_ChunkSize-1
				WorldY=World.HeightMap[HeightMapID].Height[CubeX,CubeZ]+1
				Voxel_SetBlockLight(World,WorldChunkX+CubeX,WorldY,WorldChunkZ+CubeZ,15)
				
				TempAddFrontier.X=WorldChunkX+CubeX
				TempAddFrontier.Y=WorldY
				TempAddFrontier.Z=WorldChunkZ+CubeZ
				if Voxel_GetEntryInArray(AddLightFrontier,TempAddFrontier)=-1 then AddLightFrontier.insert(TempAddFrontier)
		next CubeZ
	next CubeX
endfunction

function Voxel_AddLight(World ref as WorldData,ChunkX,ChunkY,ChunkZ,CubeX,CubeY,CubeZ,BlockType)
	if BlockType=11
		X=CubeX+ChunkX*Voxel_ChunkSize
		Y=CubeY+ChunkY*Voxel_ChunkSize
		Z=CubeZ+ChunkZ*Voxel_ChunkSize
		LightValue=14
		Voxel_StartAddLight(World,X,Y,Z,LightValue)
	endif
endfunction

function Voxel_StartAddLight(World ref as WorldData,StartX,StartY,StartZ,StartLightValue)
	local TempFrontier as Int3Data
	local TempChunkElement as Int3Data

	TempFrontier.X=StartX
	TempFrontier.Y=StartY
	TempFrontier.Z=StartZ
	AddLightFrontier.insert(TempFrontier)
	
	Voxel_SetBlockLight(World,StartX,StartY,StartZ,StartLightValue)
endfunction

function Voxel_RemoveLight(World ref as WorldData,ChunkX,ChunkY,ChunkZ,CubeX,CubeY,CubeZ,BlockType)
	if BlockType=11
		X=CubeX+ChunkX*Voxel_ChunkSize
		Y=CubeY+ChunkY*Voxel_ChunkSize
		Z=CubeZ+ChunkZ*Voxel_ChunkSize
		LightValue=8
		Voxel_StartRemoveLight(World,X,Y,Z,LightValue)
	endif
endfunction

function Voxel_StartRemoveLight(World ref as WorldData,StartX,StartY,StartZ,StartLightValue)
	local TempFrontier as FrontierData

	TempFrontier.X=StartX
	TempFrontier.Y=StartY
	TempFrontier.Z=StartZ
	TempFrontier.LightValue=Voxel_GetBlockLight(World,StartX,StartY,StartZ)
	RemoveLightFrontier.insert(TempFrontier)
	
	Voxel_SetBlockLight(World,StartX,StartY,StartZ,StartLightValue)
endfunction

function Voxel_UpdatePointLights(World ref as WorldData,AmbientLightValue)
	local TempAddFrontier as Int3Data
	local TempRemoveFrontier as FrontierData
	local TempChunkElement as Int3Data

	while RemoveLightFrontier.length>=0
		CubeX=RemoveLightFrontier[0].X
		CubeY=RemoveLightFrontier[0].Y
		CubeZ=RemoveLightFrontier[0].Z
		CurrentLightValue=RemoveLightFrontier[0].LightValue
		RemoveLightFrontier.remove(0)
		
		if CubeX>=0 and CubeX<=Voxel_WorldSizeX and CubeY>=0 and CubeY<=Voxel_WorldSizeY and CubeZ>=0 and CubeZ<=Voxel_WorldSizeZ
			for NeighbourID=0 to Voxel_Neighbors.length
				NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
//~				if Voxel_GetBlockType(World,NeighbourX,NeighbourY,NeighbourZ)=0
					NeigbourLightValue=Voxel_GetBlockLight(World,NeighbourX,NeighbourY,NeighbourZ)
					if NeigbourLightValue<>0 and NeigbourLightValue<CurrentLightValue
						TempRemoveFrontier.X=NeighbourX
						TempRemoveFrontier.Y=NeighbourY
						TempRemoveFrontier.Z=NeighbourZ
						TempRemoveFrontier.LightValue=NeigbourLightValue
						RemoveLightFrontier.insert(TempRemoveFrontier)
						Voxel_SetBlockLight(World,NeighbourX,NeighbourY,NeighbourZ,AmbientLightValue)
						
						TempChunkElement.X=round(NeighbourX/Voxel_ChunkSize)
						TempChunkElement.Y=round(NeighbourY/Voxel_ChunkSize)
						TempChunkElement.Z=round(NeighbourZ/Voxel_ChunkSize)
						if Voxel_GetEntryInArray(Voxel_ChunkBuild,TempChunkElement)=-1 then Voxel_ChunkBuild.insert(TempChunkElement)
					else
						TempAddFrontier.X=NeighbourX
						TempAddFrontier.Y=NeighbourY
						TempAddFrontier.Z=NeighbourZ
						if Voxel_GetEntryInArray(AddLightFrontier,TempAddFrontier)=-1 then AddLightFrontier.insert(TempAddFrontier)
					endif
//~				endif
			next NeighbourID
		endif
	endwhile
	
	while AddLightFrontier.length>=0
		CubeX=AddLightFrontier[0].X
		CubeY=AddLightFrontier[0].Y
		CubeZ=AddLightFrontier[0].Z
		AddLightFrontier.remove(0)
		
		if CubeX>=0 and CubeX<=Voxel_WorldSizeX and CubeY>=0 and CubeY<=Voxel_WorldSizeY and CubeZ>=0 and CubeZ<=Voxel_WorldSizeZ			
			NewLightValue=Voxel_GetBlockLight(World,CubeX,CubeY,CubeZ)-1
			for NeighbourID=0 to Voxel_Neighbors.length
				NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
				if Voxel_GetBlockType(World,NeighbourX,NeighbourY,NeighbourZ)=0
					if Voxel_GetBlockLight(World,NeighbourX,NeighbourY,NeighbourZ)<=NewLightValue
						TempAddFrontier.X=NeighbourX
						TempAddFrontier.Y=NeighbourY
						TempAddFrontier.Z=NeighbourZ
						AddLightFrontier.insert(TempAddFrontier)
						Voxel_SetBlockLight(World,NeighbourX,NeighbourY,NeighbourZ,NewLightValue)
						
						TempChunkElement.X=round(NeighbourX/Voxel_ChunkSize)
						TempChunkElement.Y=round(NeighbourY/Voxel_ChunkSize)
						TempChunkElement.Z=round(NeighbourZ/Voxel_ChunkSize)
						if Voxel_GetEntryInArray(Voxel_ChunkBuild,TempChunkElement)=-1 then Voxel_ChunkBuild.insert(TempChunkElement)
					endif
				endif
			next NeighbourID
		endif
	endwhile
endfunction

function Voxel_AddCubeToObject(Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z,BlockType)
	X=Voxel_Clamp(X,0,World.ChunkID.length*Voxel_ChunkSize)
	Y=Voxel_Clamp(Y,0,World.ChunkID[0].length*Voxel_ChunkSize)
	Z=Voxel_Clamp(Z,0,World.ChunkID[0,0].length*Voxel_ChunkSize)
	
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=BlockType
	
	Voxel_AddLight(World,ChunkX,ChunkY,ChunkZ,CubeX,CubeY,CubeZ,BlockType)
	
	Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
	
	if CubeX=Voxel_ChunkSize-1
		if ChunkX+1<=World.ChunkID.length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX+1,ChunkY,ChunkZ)
	endif
	if CubeX=0
		if ChunkX-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX-1,ChunkY,ChunkZ)
	endif
	if CubeY=Voxel_ChunkSize-1
		if ChunkY+1<=World.ChunkID[0].length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY+1,ChunkZ)
	endif
	if CubeY=0
		if ChunkY-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY-1,ChunkZ)
	endif
	if CubeZ=Voxel_ChunkSize-1
		if ChunkZ+1<=World.ChunkID[0,0].length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ+1)
	endif
	if CubeZ=0
		if ChunkZ-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ-1)
	endif
endfunction

function Voxel_RemoveCubeFromObject(Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z)
	X=Voxel_Clamp(X,0,World.ChunkID.length*Voxel_ChunkSize)
	Y=Voxel_Clamp(Y,0,World.ChunkID[0].length*Voxel_ChunkSize)
	Z=Voxel_Clamp(Z,0,World.ChunkID[0,0].length*Voxel_ChunkSize)
	
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
	
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
	
	Voxel_RemoveLight(World,ChunkX,ChunkY,ChunkZ,CubeX,CubeY,CubeZ, BlockType)
	
	Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)

	if CubeX=Voxel_ChunkSize-1
		if ChunkX+1<=World.ChunkID.length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX+1,ChunkY,ChunkZ)
	endif
	if CubeX=0
		if ChunkX-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX-1,ChunkY,ChunkZ)
	endif
	if CubeY=Voxel_ChunkSize-1
		if ChunkY+1<=World.ChunkID[0].length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY+1,ChunkZ)
	endif
	if CubeY=0
		if ChunkY-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY-1,ChunkZ)
	endif
	if CubeZ=Voxel_ChunkSize-1
		if ChunkZ+1<=World.ChunkID[0,0].length*Voxel_ChunkSize then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ+1)
	endif
	if CubeZ=0
		if ChunkZ-1>=0 then Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ-1)
	endif
endfunction BlockType

function Voxel_RemoveCubeListFromObject(Faceimages ref as FaceimageData,World ref as WorldData,CubeList as Int3Data[])
	if CubeList.length>=0
		for index=0 to CubeList.length
			X=Voxel_Clamp(CubeList[index].X,0,World.ChunkID.length*Voxel_ChunkSize)
			Y=Voxel_Clamp(CubeList[index].Y,0,World.ChunkID[0].length*Voxel_ChunkSize)
			Z=Voxel_Clamp(CubeList[index].Z,0,World.ChunkID[0,0].length*Voxel_ChunkSize)
			
			ChunkX=trunc(X/Voxel_ChunkSize)
			ChunkY=trunc(Y/Voxel_ChunkSize)
			ChunkZ=trunc(Z/Voxel_ChunkSize)
			ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
			CubeX=Mod(X,Voxel_ChunkSize)
			CubeY=Mod(Y,Voxel_ChunkSize)
			CubeZ=Mod(Z,Voxel_ChunkSize)
			BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
			World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
			
			Voxel_RemoveLight(World,ChunkX,ChunkY,ChunkZ,CubeX,CubeY,CubeZ,BlockType)
		
			ChunkList as Int3Data[]
			TempChunk as Int3Data
		
			if CubeX=Voxel_ChunkSize
				if ChunkX+1<=World.ChunkID.length
					TempChunk.X=ChunkX+1
					TempChunk.Y=ChunkY
					TempChunk.Z=ChunkZ
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
			if CubeX=0
				if ChunkX-1>=0
					TempChunk.X=ChunkX-1
					TempChunk.Y=ChunkY
					TempChunk.Z=ChunkZ
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
			if CubeY=Voxel_ChunkSize
				if ChunkY+1<=World.ChunkID[0].length
					TempChunk.X=ChunkX
					TempChunk.Y=ChunkY+1
					TempChunk.Z=ChunkZ
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
			if CubeY=0
				if ChunkY-1>=0
					TempChunk.X=ChunkX
					TempChunk.Y=ChunkY-1
					TempChunk.Z=ChunkZ
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
			if CubeZ=Voxel_ChunkSize
				if ChunkZ+1<=World.ChunkID[0,0].length
					TempChunk.X=ChunkX
					TempChunk.Y=ChunkY
					TempChunk.Z=ChunkZ+1
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
			if CubeZ=0
				if ChunkZ-1>=0
					TempChunk.X=ChunkX
					TempChunk.Y=ChunkY
					TempChunk.Z=ChunkZ-1
					if Voxel_GetEntryInArray(ChunkList,TempChunk)=-1 then ChunkList.insert(TempChunk)
				endif
			endif
		next index
		
		Voxel_BuildObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
		for ChunkIndex=ChunkList.length to 0 step -1
			Voxel_BuildObject(Faceimages,World,ChunkList[ChunkIndex].X,ChunkList[ChunkIndex].Y,ChunkList[ChunkIndex].Z)
			ChunkList.remove(ChunkIndex)
		next ChunkIndex
	endif
endfunction

function Voxel_DeleteObject(Chunk ref as ChunkData)	
	DeleteObject(Chunk.ObjectID)
	Chunk.ObjectID=0
endfunction

function Voxel_BuildObject(FaceImages ref as FaceimageData,World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	if ChunkID=-1 then exitfunction 0
  	if World.Chunk[ChunkID].ObjectID=0
		Voxel_CreateThreadNoise(World,ChunkX,ChunkY,ChunkZ)
//~		Voxel_CreateGPUNoise(World.Chunk[ChunkX,ChunkY,ChunkZ].Border,World)
//~		Voxel_CreateSoftwareNoise(World.Chunk[ChunkX,ChunkY,ChunkZ].Border,World)

		ObjectID=Voxel_CreateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
		
//~		if GetObjectExists(ObjectID)
//~			Create3DPhysicsStaticBody(ObjectID)
//~			SetObjectShapeStaticPolygon(ObjectID)
//~		endif
	else
		Voxel_UpdateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
		SetObjectVisible(World.Chunk[ChunkID].ObjectID,1)
		
//~		Delete3DPhysicsBody(World.Chunk[ChunkID].ObjectID)
//~		Create3DPhysicsStaticBody(World.Chunk[ChunkID].ObjectID)
//~		SetObjectShapeStaticPolygon(World.Chunk[ChunkID].ObjectID)
	endif
endfunction ObjectID

function Voxel_CreateObject(FaceImages ref as FaceimageData,World ref as WorldData,ChunkX,ChunkY,ChunkZ)	
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	
	local Object as ObjectData
	for CubeX=0 to Voxel_ChunkSize-1
		for CubeZ=0 to Voxel_ChunkSize-1
			for CubeY=0 to Voxel_ChunkSize-1
				Voxel_GenerateCubeFaces(Object,Faceimages,World,ChunkX*Voxel_ChunkSize+CubeX,ChunkY*Voxel_ChunkSize+CubeY,ChunkZ*Voxel_ChunkSize+CubeZ)
			next CubeY
		next CubeZ
	next CubeX
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)		
		World.Chunk[ChunkID].ObjectID=CreateObjectFromMeshMemblock(MemblockID)
		DeleteMemblock(MemblockID)
		Object.Index.length=-1
		Object.Vertex.length=-1
		
		SetObjectPosition(World.Chunk[ChunkID].ObjectID,ChunkX*Voxel_ChunkSize,ChunkY*Voxel_ChunkSize,ChunkZ*Voxel_ChunkSize)
		SetObjectImage(World.Chunk[ChunkID].ObjectID,Voxel_DiffuseImageID,0)
//~		SetObjectNormalMap(World.Chunk[ChunkID].ObjectID,Voxel_NormalImageID)
		SetObjectShader(World.Chunk[ChunkID].ObjectID,Voxel_ShaderID)
	endif
endfunction World.Chunk[ChunkID].ObjectID

function Voxel_UpdateObject(Faceimages ref as FaceimageData,World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	
	local Object as ObjectData
	for CubeX=0 to Voxel_ChunkSize-1
		for CubeZ=0 to Voxel_ChunkSize-1
			for CubeY=0 to Voxel_ChunkSize-1
				Voxel_GenerateCubeFaces(Object,Faceimages,World,ChunkX*Voxel_ChunkSize+CubeX,ChunkY*Voxel_ChunkSize+CubeY,ChunkZ*Voxel_ChunkSize+CubeZ)
			next CubeY
		next CubeZ
	next CubeX
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)
		SetObjectMeshFromMemblock(World.Chunk[ChunkID].ObjectID,1,MemblockID)
		DeleteMemblock(MemblockID)
		Object.Index.length=-1
		Object.Vertex.length=-1
	endif
endfunction

function Voxel_GenerateCubeFaces(Object ref as ObjectData,Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]

	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then CubeX=Voxel_ChunkSize+CubeX
	if CubeY<0 then CubeY=Voxel_ChunkSize+CubeY
	if CubeZ<0 then CubeZ=Voxel_ChunkSize+CubeZ
	BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
	
	if BlockType>0
		Index=BlockType-1
		TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]
		if Voxel_GetBlockType(World,X,Y,Z+1)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X,Y,Z+1)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[0],CubeX,CubeY,CubeZ,FaceFront,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,X,Y,Z-1)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X,Y,Z-1)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[1],CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,X+1,Y,Z)=0
			side1=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X+1,Y,Z)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[2],CubeX,CubeY,CubeZ,FaceRight,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,X-1,Y,Z)=0
			side1=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X-1,Y,Z)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[3],CubeX,CubeY,CubeZ,FaceLeft,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,X,Y+1,Z)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X,Y+1,Z)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[4],CubeX,CubeY,CubeZ,FaceUp,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,X,Y-1,Z)=0
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			Ambient=Voxel_GetBlockLight(World,X,Y-1,Z)
			AO0=(Ambient-AO0)*17
			AO1=(Ambient-AO1)*17
			AO2=(Ambient-AO2)*17
			AO3=(Ambient-AO3)*17
			
			Voxel_AddFaceToObject(Object,TempSubimages[5],CubeX,CubeY,CubeZ,FaceDown,AO0,AO1,AO2,AO3,Flipped)
		endif
	endif
endfunction

function Voxel_AddChunk(World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	if World.ChunkID[ChunkX,ChunkY,ChunkZ]=-1
		TempBlocks as ChunkData
		World.Chunk.insert(TempBlocks)
		World.ChunkID[ChunkX,ChunkY,ChunkZ]=World.Chunk.length
	endif
endfunction

function Voxel_GetChunkID(World ref as WorldData,X,Y,Z)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
endfunction ChunkID

function Voxel_GetBlockTypeFromChunk(World ref as WorldData,ChunkID,X,Y,Z)
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then inc CubeX,Voxel_ChunkSize
	if CubeY<0 then inc CubeY,Voxel_ChunkSize
	if CubeZ<0 then inc CubeZ,Voxel_ChunkSize
	BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
endfunction BlockType

function Voxel_GetBlockType(World ref as WorldData,X,Y,Z)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	if ChunkID=-1 then exitfunction -1
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then inc CubeX,Voxel_ChunkSize
	if CubeY<0 then inc CubeY,Voxel_ChunkSize
	if CubeZ<0 then inc CubeZ,Voxel_ChunkSize
	BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
endfunction BlockType

function Voxel_SetBlockType(World ref as WorldData,X,Y,Z,BlockType)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	if ChunkID=-1 then exitfunction 0
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then inc CubeX,Voxel_ChunkSize
	if CubeY<0 then inc CubeY,Voxel_ChunkSize
	if CubeZ<0 then inc CubeZ,Voxel_ChunkSize
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=BlockType
endfunction 1

function Voxel_GetBlockLight(World ref as WorldData,X,Y,Z)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	if ChunkID=-1 then exitfunction 0
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then inc CubeX,Voxel_ChunkSize
	if CubeY<0 then inc CubeY,Voxel_ChunkSize
	if CubeZ<0 then inc CubeZ,Voxel_ChunkSize
	LightValue=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue
endfunction LightValue

function Voxel_SetBlockLight(World ref as WorldData,X,Y,Z,LightValue)
	ChunkX=trunc(X/Voxel_ChunkSize)
	ChunkY=trunc(Y/Voxel_ChunkSize)
	ChunkZ=trunc(Z/Voxel_ChunkSize)
	ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
	if ChunkID=-1 then exitfunction
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then inc CubeX,Voxel_ChunkSize
	if CubeY<0 then inc CubeY,Voxel_ChunkSize
	if CubeZ<0 then inc CubeZ,Voxel_ChunkSize
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=LightValue
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
endfunction (3-(side1+side2+corner))

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as ObjectData,Subimages ref as SubimageData,X,Y,Z,FaceDir,AO0,AO1,AO2,AO3,Flipped)
	HalfFaceSize#=0.5	
	TileCount=16
	TextureSize#=256
	TileSize#=TextureSize#/TileCount
	TexelHalfSize#=(1/TileSize#/16)*0.5	
	
	Left#=Subimages.X/TextureSize#
	Top#=Subimages.Y/TextureSize#
	Right#=(Subimages.X+Subimages.Width)/TextureSize#
	Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
	
	Select FaceDir
		case FaceFront
			Voxel_SetObjectFacePosition(TempVertex[0],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],0,0,1)
			Voxel_SetObjectFaceNormal(TempVertex[1],0,0,1)
			Voxel_SetObjectFaceNormal(TempVertex[2],0,0,1)
			Voxel_SetObjectFaceNormal(TempVertex[3],0,0,1)

			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
			
//~			Voxel_SetObjectFaceTangent(TempVertex[0],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],-1,0,0)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
		endcase
		case FaceBack
			Voxel_SetObjectFacePosition(TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],0,0,-1)
			Voxel_SetObjectFaceNormal(TempVertex[1],0,0,-1)
			Voxel_SetObjectFaceNormal(TempVertex[2],0,0,-1)
			Voxel_SetObjectFaceNormal(TempVertex[3],0,0,-1)
			
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
		endcase
		case FaceRight
			Voxel_SetObjectFacePosition(TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[1],1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[2],1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[3],1,0,0)

			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,1)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
		endcase
		case FaceLeft
			Voxel_SetObjectFacePosition(TempVertex[0],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],-1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[1],-1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[2],-1,0,0)
			Voxel_SetObjectFaceNormal(TempVertex[3],-1,0,0)
			
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,-1)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
		endcase
		case FaceUp
			Voxel_SetObjectFacePosition(TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],0,1,0)
			Voxel_SetObjectFaceNormal(TempVertex[1],0,1,0)
			Voxel_SetObjectFaceNormal(TempVertex[2],0,1,0)
			Voxel_SetObjectFaceNormal(TempVertex[3],0,1,0)

			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,0,1)
		endcase
		case FaceDown
			Voxel_SetObjectFacePosition(TempVertex[0],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[1],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(TempVertex[0],0,-1,0)
			Voxel_SetObjectFaceNormal(TempVertex[1],0,-1,0)
			Voxel_SetObjectFaceNormal(TempVertex[2],0,-1,0)
			Voxel_SetObjectFaceNormal(TempVertex[3],0,-1,0)

			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBitangent(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBitangent(TempVertex[3],0,0,1)
		endcase
	endselect
	
	Object.Vertex.insert(TempVertex[0])
	Object.Vertex.insert(TempVertex[1])
	Object.Vertex.insert(TempVertex[2])
	Object.Vertex.insert(TempVertex[3])
	
	VertexID=Object.Vertex.length-3
	if Flipped=0
		Object.Index.insert(VertexID+0)
		Object.Index.insert(VertexID+1)
		Object.Index.insert(VertexID+2)
		Object.Index.insert(VertexID+2)
		Object.Index.insert(VertexID+3)
		Object.Index.insert(VertexID+0)
	else
		Object.Index.insert(VertexID+3)
		Object.Index.insert(VertexID+0)
		Object.Index.insert(VertexID+1)
		Object.Index.insert(VertexID+1)
		Object.Index.insert(VertexID+2)
		Object.Index.insert(VertexID+3)
	endif
endfunction

function Voxel_SetObjectFacePosition(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Pos.X#=X#
	Vertex.Pos.Y#=Y#
	Vertex.Pos.Z#=Z#
endfunction

function Voxel_SetObjectFaceNormal(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Normal.X#=X#
	Vertex.Normal.Y#=Y#
	Vertex.Normal.Z#=Z#
endfunction

function Voxel_SetObjectFaceUV(Vertex ref as VertexData,U#,V#)
	Vertex.UV.X#=U#
	Vertex.UV.Y#=V#
endfunction

function Voxel_SetObjectFaceColor(Vertex ref as VertexData,Red,Green,Blue,Alpha)
	Vertex.Color.Red#=Red/255.0
	Vertex.Color.Green#=Green/255.0
	Vertex.Color.Blue#=Blue/255.0
	Vertex.Color.Alpha#=Alpha/255.0
endfunction

function Voxel_SetObjectFaceTangent(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Tangent.X#=X#
	Vertex.Tangent.Y#=Y#
	Vertex.Tangent.Z#=Z#
endfunction

function Voxel_SetObjectFaceBitangent(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Bitangent.X#=X#
	Vertex.Bitangent.Y#=Y#
	Vertex.Bitangent.Z#=Z#
endfunction

// Generate the mesh header for a simple one sided plane
// Position,Normal,UV,Color,Tangent and Bitangent Data
function Voxel_CreateMeshMemblock(VertexCount,IndexCount)
	Attributes=6
	VertexSize=60
	VertexSize=3*4+3*4+2*4+4*1+3*4+3*4
	VertexOffset=100
	IndexOffset=VertexOffset+(VertexCount*VertexSize)

	MemblockID=Creatememblock(IndexOffset+(IndexCount*4))
	SetMemblockInt(MemblockID,0,VertexCount)
	SetMemblockInt(MemblockID,4,IndexCount)
	SetMemblockInt(MemblockID,8,Attributes)
	SetMemblockInt(MemblockID,12,VertexSize)
	SetMemblockInt(MemblockID,16,VertexOffset)
	SetMemblockInt(MemblockID,20,IndexOffset)
	
	SetMemblockByte(MemblockID,24,0)
	SetMemblockByte(MemblockID,24+1,3)
	SetMemblockByte(MemblockID,24+2,0)
	SetMemblockByte(MemblockID,24+3,12)
	SetMemblockString(MemblockID,24+4,"position"+chr(0))	

	SetMemblockByte(MemblockID,40,0)
	SetMemblockByte(MemblockID,40+1,3)
	SetMemblockByte(MemblockID,40+2,0)
	SetMemblockByte(MemblockID,40+3,8)
	SetMemblockString(MemblockID,40+4,"normal"+chr(0))

	SetMemblockByte(MemblockID,52,0)
	SetMemblockByte(MemblockID,52+1,2)
	SetMemblockByte(MemblockID,52+2,0)
	SetMemblockByte(MemblockID,52+3,4) 
	SetMemblockString(MemblockID,52+4,"uv"+chr(0))
	
	SetMemblockByte(MemblockID,60,1)
	SetMemblockByte(MemblockID,60+1,4)
	SetMemblockByte(MemblockID,60+2,1)
	SetMemblockByte(MemblockID,60+3,8)
	SetMemblockString(MemblockID,60+4,"color"+chr(0))

	SetMemblockByte(MemblockID,72,0)
	SetMemblockByte(MemblockID,72+1,3)
	SetMemblockByte(MemblockID,72+2,0)
	SetMemblockByte(MemblockID,72+3,8)
	SetMemblockString(MemblockID,72+4,"tangent"+chr(0))

	SetMemblockByte(MemblockID,84,0)
	SetMemblockByte(MemblockID,84+1,3)
	SetMemblockByte(MemblockID,84+2,0)
	SetMemblockByte(MemblockID,84+3,12)
	SetMemblockString(MemblockID,84+4,"bitangent"+chr(0))
endfunction MemblockID

function Voxel_WriteMeshMemblock(MemblockID,Object ref as ObjectData)
	VertexCount=Object.Vertex.length+1
	VertexSize=60
	VertexSize=3*4+3*4+2*4+4*1+3*4+3*4
	VertexOffset=100
	IndexOffset=VertexOffset+(VertexCount*VertexSize)
	TangentOffset=3*4+3*4+2*4+4*1
	BitangentOffset=3*4+3*4+2*4+4*1+3*4
	for VertexID=0 to Object.Vertex.length
		Offset=VertexOffset+(VertexID*VertexSize)
		SetMeshMemblockVertexPosition(MemblockID,VertexID,Object.Vertex[VertexID].Pos.X#,Object.Vertex[VertexID].Pos.Y#,Object.Vertex[VertexID].Pos.Z#)
		SetMeshMemblockVertexNormal(MemblockID,VertexID,Object.Vertex[VertexID].Normal.X#,Object.Vertex[VertexID].Normal.Y#,Object.Vertex[VertexID].Normal.Z#)
		SetMeshMemblockVertexUV(MemblockID,VertexID,Object.Vertex[VertexID].UV.X#,Object.Vertex[VertexID].UV.Y#)
		SetMeshMemblockVertexColor(MemblockID,VertexID,Object.Vertex[VertexID].Color.Red#*255,Object.Vertex[VertexID].Color.Green#*255,Object.Vertex[VertexID].Color.Blue#*255,Object.Vertex[VertexID].Color.Alpha#*255)
		Offset=VertexOffset+(VertexID*VertexSize)+TangentOffset
		Voxel_SetMemblockVec3(MemblockID,Offset,Object.Vertex[VertexID].Tangent.X#,Object.Vertex[VertexID].Tangent.Y#,Object.Vertex[VertexID].Tangent.Z#)
		Offset=VertexOffset+(VertexID*VertexSize)+BitangentOffset
		Voxel_SetMemblockVec3(MemblockID,Offset,Object.Vertex[VertexID].Bitangent.X#,Object.Vertex[VertexID].Bitangent.Y#,Object.Vertex[VertexID].Bitangent.Z#)
	next VertexID
	
	for IndexID=0 to Object.Index.length
		Offset=IndexOffset+IndexID*4
		SetMemblockInt(MemblockID,Offset,Object.Index[IndexID])
    next IndexID
endfunction

// just print the mesh header
function Voxel_PrintMeshMemblock(MemblockID)
	local VertexCount as integer
	local IndexCount as integer
	local Attributes as integer
	local VertexSize as integer
	local VertexOffset as integer
	local IndexOffset as integer
	local AttributeOffset as integer
	local ID as integer
	local Stringlength as integer

	VertexCount=GetMemblockInt(MemblockID,0)
	IndexCount=GetMemblockInt(MemblockID,4)
	Attributes=GetMemblockInt(MemblockID,8)
	VertexSize=GetMemblockInt(MemblockID,12)
	VertexOffset=GetMemblockInt(MemblockID,16)
	IndexOffset=GetMemblockInt(MemblockID,20)
	AttributeOffset=24

	message("VertexCount: "+str(VertexCount)+chr(10)+"IndexCount: "+str(IndexCount)+chr(10)+"Attributes: "+str(Attributes)+chr(10)+"VertexSize: "+str(VertexSize)+chr(10)+"VertexOffset: "+str(VertexOffset)+chr(10)+"IndexOffset: "+str(IndexOffset))

	for ID=1 to Attributes
		Stringlength=GetMemblockByte(MemblockID,AttributeOffset+3) // string length
		message("type: "+str(GetMemblockByte(MemblockID,AttributeOffset))+chr(10)+"components: "+str(GetMemblockByte(MemblockID,AttributeOffset+1))+chr(10)+"normalize: "+str(GetMemblockByte(MemblockID,AttributeOffset+2))+chr(10)+"length: "+str(Stringlength)+chr(10)+"string: "+GetMemblockString(MemblockID,AttributeOffset+4,Stringlength)) // string
		inc AttributeOffset,4+StringLength
	next
endfunction

function Voxel_SetMemblockVec4(MemblockID,Offset,x#,y#,z#,w#)
	SetMemblockFloat(MemblockID,Offset,x#)
	SetMemblockFloat(MemblockID,Offset+4,y#)
	SetMemblockFloat(MemblockID,Offset+8,z#)
	SetMemblockFloat(MemblockID,Offset+12,w#)
endfunction

function Voxel_SetMemblockVec3(MemblockID,Offset,x#,y#,z#)
	SetMemblockFloat(MemblockID,Offset,x#)
	SetMemblockFloat(MemblockID,Offset+4,y#)
	SetMemblockFloat(MemblockID,Offset+8,z#)
endfunction

function Voxel_SetMemblockVec2(MemblockID,Offset,u#,v#)
	SetMemblockFloat(MemblockID,Offset,u#)
	SetMemblockFloat(MemblockID,Offset+4,v#)
endfunction

function Voxel_SetMemblockByte4(MemblockID,Offset,r,g,b,a)
	SetMemblockByte(MemblockID,Offset,r)
	SetMemblockByte(MemblockID,Offset+1,g)
	SetMemblockByte(MemblockID,Offset+2,b)
	SetMemblockByte(MemblockID,Offset+3,a)
endfunction

function Voxel_SetMemblockInt4(MemblockID,Offset,x#,y#,z#,w#)
	SetMemblockInt(MemblockID,Offset,x#)
	SetMemblockInt(MemblockID,Offset+4,y#)
	SetMemblockInt(MemblockID,Offset+8,z#)
	SetMemblockInt(MemblockID,Offset+12,w#)
endfunction

function Voxel_Clamp(Value#,Min#,Max#)
	if Min#>Max# then exitfunction Value#
	if Value#>Max# then Value#=Max#
	if Value#<Min# then Value#=Min#
endfunction Value#