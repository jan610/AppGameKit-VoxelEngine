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
    Chunk as ChunkData[-1]
    ChunkID as integer[-1,-1,-1]
endtype

type ChunkData
    ObjectID as integer
    Blocks as BlockData[15,15,15]
endtype

type BlockData
    BlockType as integer
    LightValue as integer
endtype

//~type WorldData
//~	Terrain as TerrainData[0,0,0]
//~	Chunk as ChunkData[0,0,0]
//~endtype

//~type TerrainData
//~	BlockType as integer
//~	LightValue as integer
//~endtype

//~type ChunkData
//~	Border as BorderData
//~	ObjectID as integer
//~	Visible as integer
//~endtype

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

global Voxel_ChunkMemblock as MemblockData[]
global Voxel_ChunkPosition as Int3Data[]
global Voxel_Neighbors as Int3Data[5]
global TempBlocks as ChunkData

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
	
	Frecueny2D#=32.0
	Frecueny3DCave#=10.0
	Frecueny3DIron#=2.0
	
	local TempChunkMemblock as MemblockData
	for Dist=0 to ViewDistance
		ViewMinX=Voxel_Clamp(CameraChunkX-Dist,0,World.ChunkID.length)
		ViewMinY=Voxel_Clamp(CameraChunkY-Dist,0,World.ChunkID[0].length)
		ViewMinZ=Voxel_Clamp(CameraChunkZ-Dist,0,World.ChunkID[0,0].length)
		ViewMaxX=Voxel_Clamp(CameraChunkX+Dist,0,World.ChunkID.length)
		ViewMaxY=Voxel_Clamp(CameraChunkY+Dist,0,World.ChunkID[0].length)
		ViewMaxZ=Voxel_Clamp(CameraChunkZ+Dist,0 ,World.ChunkID[0,0].length)
		
		for ChunkY=ViewMinY to ViewMaxY
			for ChunkZ=ViewMinZ to ViewMaxZ
				for ChunkX=ViewMinX to ViewMaxX
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

						NoiseGrassMemblockID=TN_CreateMemblockNoise2D(Frecueny2D#,MinX,MinZ,Width,Depth)
						NoiseCaveMemblockID=TN_CreateMemblockNoise3D(Frecueny3DCave#,MinX,MinY,MinZ,Width,Height,Depth)
						NoiseIronMemblockID=TN_CreateMemblockNoise3D(Frecueny3DIron#,MinX,MinY,MinZ,Width,Height,Depth)

						TempChunkMemblock.GrassMemblockID=NoiseGrassMemblockID
						TempChunkMemblock.CaveMemblockID=NoiseCaveMemblockID
						TempChunkMemblock.IronMemblockID=NoiseIronMemblockID
						TempChunkMemblock.Position.X=ChunkX
						TempChunkMemblock.Position.Y=ChunkY
						TempChunkMemblock.Position.Z=ChunkZ
						Voxel_ChunkMemblock.insert(TempChunkMemblock)
					endif
				next ChunkX
			next ChunkZ
		next ChunkY
	next Dist
	
	DirtLayerHeight=3
	local TempChunkPosition as Int3Data
  	if Voxel_ChunkMemblock.length>-1
		NoiseGrassMemblockID=Voxel_ChunkMemblock[0].GrassMemblockID
		NoiseCaveMemblockID=Voxel_ChunkMemblock[0].CaveMemblockID
		NoiseIronMemblockID=Voxel_ChunkMemblock[0].IronMemblockID
		ChunkX=Voxel_ChunkMemblock[0].Position.X
		ChunkY=Voxel_ChunkMemblock[0].Position.Y
		ChunkZ=Voxel_ChunkMemblock[0].Position.Z
  		Voxel_ChunkMemblock.remove(0)
  		
		TempChunkPosition.X=ChunkX
		TempChunkPosition.Y=ChunkY
		TempChunkPosition.Z=ChunkZ
		Voxel_ChunkPosition.insert(TempChunkPosition)
		
		TN_WaitForNoise(NoiseGrassMemblockID)
		TN_WaitForNoise(NoiseCaveMemblockID)
		TN_WaitForNoise(NoiseIronMemblockID)
		
		Offset2D=0
		Offset3D=0
		ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
		for CubeX=0 to World.Chunk[ChunkID].Blocks.length
			for CubeZ=0 to World.Chunk[ChunkID].Blocks[0,0].length
				inc Offset2D,4
				for CubeY=0 to World.Chunk[ChunkID].Blocks[0].length
					inc Offset3D,4
					
					GrassNoise#=(GetMemblockFloat(NoiseGrassMemblockID,Offset2D)+1.0*0.25)*World.ChunkID[0].length*Voxel_ChunkSize
					GrassLayer=(World.ChunkID[0].length*Voxel_ChunkSize*0.4)+GrassNoise#/3.0
					
					if ChunkY*Voxel_ChunkSize+CubeY=GrassLayer
						World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=1
					elseif ChunkY*Voxel_ChunkSize+CubeY>GrassLayer-DirtLayerHeight and ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer
						World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=3
					elseif ChunkY*Voxel_ChunkSize+CubeY<=GrassLayer-DirtLayerHeight
						World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=2
						/*Offset3D=4+4*((X*Width*Height)+(Y*Height)+Z)
						IronNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
						if IronNoise#>0.68 then World.Chunk[CubeX,CubeY,CubeZ].BlockType=4*/
					endif
					
					CaveNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
					
					if CaveNoise#>0.5+CubeY/(World.ChunkID[0].length*Voxel_ChunkSize+0.0)
						World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
					endif
					
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=15
				next CubeY
			next CubeZ
		next CubeX
		
		DeleteMemblock(NoiseGrassMemblockID)
		DeleteMemblock(NoiseCaveMemblockID)
		DeleteMemblock(NoiseIronMemblockID)
	endif
	
//~	if Voxel_ChunkPosition.length>-1
	for index=0 to Voxel_ChunkPosition.length
		ChunkX=Voxel_ChunkPosition[index].X
		ChunkY=Voxel_ChunkPosition[index].Y
		ChunkZ=Voxel_ChunkPosition[index].Z
		
		ViewMinX=round(CameraChunkX-(ViewDistance-3))
		ViewMinY=round(CameraChunkY-(ViewDistance-3))
		ViewMinZ=round(CameraChunkZ-(ViewDistance-3))
		ViewMaxX=round(CameraChunkX+(ViewDistance-3))
		ViewMaxY=round(CameraChunkY+(ViewDistance-3))
		ViewMaxZ=round(CameraChunkZ+(ViewDistance-3))
//~		
		if ViewMinX<=ChunkX and ChunkX<=ViewMaxX and ViewMinY<=ChunkY and ChunkY<=ViewMaxY and ViewMinZ<=ChunkZ and ChunkZ<=ViewMaxZ
			Voxel_ChunkPosition.remove(index)
			
			ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
			if World.Chunk[ChunkID].ObjectID=0		
				ObjectID=Voxel_CreateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
				
				if GetObjectExists(ObjectID)
					Create3DPhysicsStaticBody(ObjectID)
					SetObjectShapeStaticPolygon(ObjectID)
				endif
			else
				Voxel_UpdateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
				
				Delete3DPhysicsBody(World.Chunk[ChunkID].ObjectID)
				Create3DPhysicsStaticBody(World.Chunk[ChunkID].ObjectID)
				SetObjectShapeStaticPolygon(World.Chunk[ChunkID].ObjectID)
			endif
			
			exit
		endif
	next index
//~	endif
endfunction

function Voxel_CreateThreadNoise(World ref as WorldData,ChunkX,ChunkY,ChunkZ)
	Frecueny2D#=32.0
	Frecueny3DCave#=10.0
	Frecueny3DIron#=2.0
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
	
	NoiseGrassMemblockID=CreateMemblock(4+4*((Width*Height)+Height+1))
	Noise.Write2DNoiseToMemblock(NoiseGrassMemblockID,Frecueny2D#,MinX,MinZ,Width,Depth)
	
	NoiseGrassMemblockID=TN_CreateMemblockNoise2D(Frecueny2D#,MinX,MinZ,Width,Depth)
	NoiseCaveMemblockID=TN_CreateMemblockNoise3D(Frecueny3DCave#,MinX,MinY,MinZ,Width,Height,Depth)
	NoiseIronMemblockID=TN_CreateMemblockNoise3D(Frecueny3DIron#,MinX,MinY,MinZ,Width,Height,Depth)
	
	TN_WaitForNoise(NoiseGrassMemblockID)
	TN_WaitForNoise(NoiseCaveMemblockID)
	TN_WaitForNoise(NoiseIronMemblockID)
				
	Offset2D=0
	Offset3D=0
	for CubeX=0 to World.Chunk[ChunkID].Blocks.length
		for CubeZ=0 to World.Chunk[ChunkID].Blocks[0].length
			inc Offset2D,4
			for CubeY=0 to World.Chunk[ChunkID].Blocks[0,0].length
				inc Offset3D,4

				GrassNoise#=(GetMemblockFloat(NoiseGrassMemblockID,Offset2D)+1.0*0.25)*World.ChunkID[0].length*Voxel_ChunkSize
				GrassLayer=(World.ChunkID[0].length*Voxel_ChunkSize*0.4)+GrassNoise#/3.0
				
				if CubeY*Voxel_ChunkSize=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=1
				elseif CubeY*Voxel_ChunkSize>GrassLayer-DirtLayerHeight and CubeY*Voxel_ChunkSize<=GrassLayer
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=3
				elseif CubeY*Voxel_ChunkSize<=GrassLayer-DirtLayerHeight
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=2

//~					Offset3D=4+4*((X*Width*Height)+(Y*Height)+Z)
//~					IronNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
//~					if IronNoise#>0.68 then World.Chunk[CubeX,CubeY,CubeZ].BlockType=4
				endif
				
				CaveNoise#=GetMemblockFloat(NoiseCaveMemblockID,Offset3D)+1.0*0.25
				
				if CaveNoise#>0.5
					World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
				endif
				
				World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=8
			next CubeY
			Y=0
		next CubeZ
		Z=0
	next CubeX
	X=0
	
	DeleteMemblock(NoiseGrassMemblockID)
	DeleteMemblock(NoiseCaveMemblockID)
	DeleteMemblock(NoiseIronMemblockID)
endfunction
/*
function Voxel_CreateGpuNoise(Border ref as BorderData,World ref as WorldData)		
	OffsetX=Border.Min.X/Voxel_ChunkSize
	OffsetY=(Border.Min.Y-1)/Voxel_ChunkSize
	OffsetZ=Border.Min.Z/Voxel_ChunkSize
	
	Voxel_RenderNoise(OffsetX,OffsetY,OffsetZ)
	MemblockID=CreateMemblockFromImage(Voxel_NoiseRenderImageID)
	Width=GetMemblockInt(MemblockID,0)
		
	for Z=0 to 12 step 4
		CubeZ=Border.Min.Z+Z
		for Y=0 to 15
			CubeY=Border.Min.Y+Y
			for X=0 to 15
				Offset=(4*((floor(Z/4.0)*Width*16)+(Y*Width)+X))+12
				CubeX=Border.Min.X+X
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

function Voxel_CreateSoftwareNoise(Border ref as BorderData,World ref as WorldData)	
	Frecueny2D#=32.0
	Frecueny3DCave#=10.0
	Frecueny3DIron#=2.0
	DirtLayerHeight=3
	WorldHeight=World.ChunkID[0].length
	GrassStart=WorldHeight*0.4
	for X=Border.Min.X-1 to Border.Max.X+1
		for Y=Border.Min.Y-1 to Border.Max.Y+1
			for Z=Border.Min.Z-1 to Border.Max.Z+1
				
				Value1#=Noise_Perlin2(X/Frecueny2D#,Z/Frecueny2D#)*WorldHeight
				GrassLayer=GrassStart+Value1#/3.0
				
				if Y=GrassLayer
					World.Chunk[X,Y,Z].BlockType=1
				elseif Y>=GrassLayer-DirtLayerHeight and Y<GrassLayer
					World.Chunk[X,Y,Z].BlockType=3
				elseif Y<GrassLayer-DirtLayerHeight
					World.Chunk[X,Y,Z].BlockType=2
					//Value3#=Noise_Perlin3(X/Frecueny3DIron#,Y/Frecueny3DIron#,Z/Frecueny3DIron#)
					//if Value3#>0.68 then World.Chunk[X,Y,Z].BlockType=4
				endif
				
				Value2#=Noise_Perlin3(X/Frecueny3DCave#,Y/Frecueny3DCave#,Z/Frecueny3DCave#)
				if Value2#>0.5
					World.Chunk[X,Y,Z].BlockType=0
				endif
				
				World.Chunk[X,Y,Z].LightValue=8
			next Z
		next Y
	next X
endfunction
*/

function Voxel_AddLight(World ref as WorldData,ChunkID,CubeX,CubeY,CubeZ)	
	if World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=11
//~		ChunkX=round((CubeX-1)/Voxel_ChunkSize)
//~		ChunkY=round((CubeY-1)/Voxel_ChunkSize)
//~		ChunkZ=round((CubeZ-1)/Voxel_ChunkSize)
//~		
//~		for X=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.X to World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.X
//~			for Y=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Y to World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Y
//~				for Z=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Z to World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Z
//~					World.Chunk[X,Y,Z].LightValue=2
//~				next Z
//~			next Y
//~		next X
		
		Voxel_IterativeAddLight(World,ChunkID,CubeX,CubeY,CubeZ,15)
	endif
endfunction

function Voxel_IterativeAddLight(World ref as WorldData,ChunkID,StartX,StartY,StartZ,StartLightValue as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]
	local TempChunkPosition as Int3Data

	FrontierTemp.X=StartX
	FrontierTemp.Y=StartY
	FrontierTemp.Z=StartZ
	Frontier.insert(FrontierTemp)
	
	World.Chunk[ChunkID].Blocks[StartX,StartY,StartZ].LightValue=StartLightValue
	
	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		
		if CubeX>0 and CubeX<World.ChunkID.length*Voxel_ChunkSize and CubeY>0 and CubeY<World.ChunkID[0].length*Voxel_ChunkSize and CubeZ>0 and CubeZ<World.ChunkID[0,0].length*Voxel_ChunkSize
			for NeighbourID=0 to Voxel_Neighbors.length
				NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
				
				ChunkX=trunc(NeighbourX/Voxel_ChunkSize)
				ChunkY=trunc(NeighbourY/Voxel_ChunkSize)
				ChunkZ=trunc(NeighbourZ/Voxel_ChunkSize)
				ChunkID=World.ChunkID[ChunkX,ChunkY,ChunkZ]
				
				NeighbourCubeX=Mod(NeighbourX,Voxel_ChunkSize)
				NeighbourCubeY=Mod(NeighbourY,Voxel_ChunkSize)
				NeighbourCubeZ=Mod(NeighbourZ,Voxel_ChunkSize)
				
				if World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=0
					NewLightValue=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue-1
					if World.Chunk[ChunkID].Blocks[NeighbourCubeX,NeighbourCubeY,NeighbourCubeZ].LightValue<=NewLightValue
						FrontierTemp.X=NeighbourX
						FrontierTemp.Y=NeighbourY
						FrontierTemp.Z=NeighbourZ
						Frontier.insert(FrontierTemp)
						World.Chunk[ChunkID].Blocks[NeighbourCubeX,NeighbourCubeY,NeighbourCubeZ].LightValue=NewLightValue
						
						TempChunkPosition.X=round(NeighbourX/Voxel_ChunkSize)
						TempChunkPosition.Y=round(NeighbourY/Voxel_ChunkSize)
						TempChunkPosition.Z=round(NeighbourZ/Voxel_ChunkSize)
						if Voxel_GetEntryInArray(Voxel_ChunkPosition,TempChunkPosition)=-1 then Voxel_ChunkPosition.insert(TempChunkPosition)
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
	
	Voxel_AddLight(World,ChunkID,CubeX,CubeY,CubeZ)
	
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
	
	Voxel_AddLight(World,ChunkID,CubeX,CubeY,CubeZ)
	
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
			
			Voxel_AddLight(World,ChunkID,CubeX,CubeY,CubeZ)
		
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
  	if World.Chunk[ChunkID].ObjectID=0
		
		Voxel_CreateThreadNoise(World,ChunkX,ChunkY,ChunkZ)
//~		Voxel_CreateGPUNoise(World.Chunk[ChunkX,ChunkY,ChunkZ].Border,World)
//~		Voxel_CreateSoftwareNoise(World.Chunk[ChunkX,ChunkY,ChunkZ].Border,World)

		ObjectID=Voxel_CreateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
		
		if GetObjectExists(ObjectID)
			Create3DPhysicsStaticBody(ObjectID)
			SetObjectShapeStaticPolygon(ObjectID)
		endif
	else
		Voxel_UpdateObject(Faceimages,World,ChunkX,ChunkY,ChunkZ)
		SetObjectVisible(World.Chunk[ChunkID].ObjectID,1)
		
		Delete3DPhysicsBody(World.Chunk[ChunkID].ObjectID)
		Create3DPhysicsStaticBody(World.Chunk[ChunkID].ObjectID)
		SetObjectShapeStaticPolygon(World.Chunk[ChunkID].ObjectID)
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
		
		local TempSubimages as SubimageData[5]
		TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]

//~		if World.Chunk[ChunkID].Blocks[X,Y,Z+1].BlockType=0
		if Voxel_GetBlockType(World,X,Y,Z+1)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X,Y,Z+1)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X,Y,Z+1)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X,Y,Z+1)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X,Y,Z+1)/15.0*255-AO3
			
			Voxel_AddFaceToObject(Object,TempSubimages[0],CubeX,CubeY,CubeZ,FaceFront,AO0,AO1,AO2,AO3,Flipped)
		endif
//~		if World.Chunk[ChunkID].Blocks[X,Y,Z-1].BlockType=0
		if Voxel_GetBlockType(World,X,Y,Z-1)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X,Y,Z-1)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X,Y,Z-1)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X,Y,Z-1)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X,Y,Z-1)/15.0*255-AO3
			
			Voxel_AddFaceToObject(Object,TempSubimages[1],CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3,Flipped)
		endif
//~		if World.Chunk[ChunkID].Blocks[X+1,Y,Z].BlockType=0
		if Voxel_GetBlockType(World,X+1,Y,Z)=0
			side1=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X+1,Y,Z)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X+1,Y,Z)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X+1,Y,Z)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X+1,Y,Z)/15.0*255-AO3
			
			Voxel_AddFaceToObject(Object,TempSubimages[2],CubeX,CubeY,CubeZ,FaceRight,AO0,AO1,AO2,AO3,Flipped)
		endif
//~		if World.Chunk[ChunkID].Blocks[X-1,Y,Z].BlockType=0
		if Voxel_GetBlockType(World,X-1,Y,Z)=0
			side1=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z+1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y,Z-1)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X-1,Y,Z)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X-1,Y,Z)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X-1,Y,Z)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X-1,Y,Z)/15.0*255-AO3
			
			Voxel_AddFaceToObject(Object,TempSubimages[3],CubeX,CubeY,CubeZ,FaceLeft,AO0,AO1,AO2,AO3,Flipped)
		endif
//~		if World.Chunk[ChunkID].Blocks[X,Y+1,Z].BlockType=0	
		if Voxel_GetBlockType(World,X,Y+1,Z)=0
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y+1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y+1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y+1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y+1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X,Y+1,Z)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X,Y+1,Z)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X,Y+1,Z)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X,Y+1,Z)/15.0*255-AO3
			
			Voxel_AddFaceToObject(Object,TempSubimages[4],CubeX,CubeY,CubeZ,FaceUp,AO0,AO1,AO2,AO3,Flipped)
		endif
//~		if World.Chunk[ChunkID].Blocks[X,Y-1,Z].BlockType=0
		if Voxel_GetBlockType(World,X,Y-1,Z)=0
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z+1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X+1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X+1,Y-1,Z-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(Voxel_GetBlockType(World,X,Y-1,Z-1)=0)
			side2=(Voxel_GetBlockType(World,X-1,Y-1,Z)=0)
			corner=(Voxel_GetBlockType(World,X-1,Y-1,Z-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			AO0=Voxel_GetBlockLight(World,X,Y-1,Z)/15.0*255-AO0
			AO1=Voxel_GetBlockLight(World,X,Y-1,Z)/15.0*255-AO1
			AO2=Voxel_GetBlockLight(World,X,Y-1,Z)/15.0*255-AO2
			AO3=Voxel_GetBlockLight(World,X,Y-1,Z)/15.0*255-AO3
			
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
	if CubeX<0 then CubeX=Voxel_ChunkSize+CubeX
	if CubeY<0 then CubeY=Voxel_ChunkSize+CubeY
	if CubeZ<0 then CubeZ=Voxel_ChunkSize+CubeZ
	BlockType=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType
endfunction BlockType

function Voxel_GetBlockType(World ref as WorldData,X,Y,Z)
	ChunkID=Voxel_GetChunkID(World,X,Y,Z)
	if ChunkID=-1 then exitfunction -1
	BlockType=Voxel_GetBlockTypeFromChunk(World,ChunkID,X,Y,Z)
endfunction BlockType

function Voxel_SetBlockType(World ref as WorldData,X,Y,Z,BlockType)
	ChunkID=Voxel_GetChunkID(World,X,Y,Z)
	if ChunkID=-1 then exitfunction 0
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then CubeX=Voxel_ChunkSize+CubeX
	if CubeY<0 then CubeY=Voxel_ChunkSize+CubeY
	if CubeZ<0 then CubeZ=Voxel_ChunkSize+CubeZ
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].BlockType=BlockType
endfunction 1

function Voxel_GetBlockLight(World ref as WorldData,X,Y,Z)
	ChunkID=Voxel_GetChunkID(World,X,Y,Z)
	if ChunkID=-1 then exitfunction 0
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then CubeX=Voxel_ChunkSize+CubeX
	if CubeY<0 then CubeY=Voxel_ChunkSize+CubeY
	if CubeZ<0 then CubeZ=Voxel_ChunkSize+CubeZ
	LightValue=World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue
endfunction LightValue

function Voxel_SetBlockLight(World ref as WorldData,X,Y,Z,LightValue)
	ChunkID=Voxel_GetChunkID(World,X,Y,Z)
	if ChunkID=-1 then exitfunction
	CubeX=Mod(X,Voxel_ChunkSize)
	CubeY=Mod(Y,Voxel_ChunkSize)
	CubeZ=Mod(Z,Voxel_ChunkSize)
	if CubeX<0 then CubeX=Voxel_ChunkSize+CubeX
	if CubeY<0 then CubeY=Voxel_ChunkSize+CubeY
	if CubeZ<0 then CubeZ=Voxel_ChunkSize+CubeZ
	World.Chunk[ChunkID].Blocks[CubeX,CubeY,CubeZ].LightValue=LightValue
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
endfunction 3 - (side1 + side2 + corner)

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as ObjectData,Subimages ref as SubimageData,X,Y,Z,FaceDir,AO0,AO1,AO2,AO3,Flipped)
	TempVertex as VertexData[3]
	HalfFaceSize#=0.5	
	TileCount=16
	TextureSize#=256
	TileSize#=TextureSize#/TileCount
	TexelHalfSize#=(1/TileSize#/16)*0.5
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
			
			Voxel_SetObjectFaceTangent(TempVertex[0],-1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[1],-1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[2],-1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[3],-1,0,0)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,1)
			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,1)
			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,1)
			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,1)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,-1)
			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,-1)
			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,-1)
			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,-1)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,1,0)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,1,0)
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,0,1)
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
			
			Left#=Subimages.X/TextureSize#
			Top#=Subimages.Y/TextureSize#
			Right#=(Subimages.X+Subimages.Width)/TextureSize#
			Bottom#=(Subimages.Y+Subimages.Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,255)
		
			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
			
			Voxel_SetObjectFaceBitangent(TempVertex[0],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[1],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[2],0,0,1)
			Voxel_SetObjectFaceBitangent(TempVertex[3],0,0,1)
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

/*
ChunkMidX#=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.X+(World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.X-World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.X)/2.0
ChunkMidY#=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Y+(World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Y-World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Y)/2.0
ChunkMidZ#=World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Z+(World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Z-World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Z)/2.0

OldCameraX#=GetCameraX(1)
OldCameraY#=GetCameraY(1)
OldCameraZ#=GetCameraZ(1)

ChunkDirX#=ChunkMidX#-OldCameraX#
ChunkDirY#=ChunkMidY#-OldCameraY#
ChunkDirZ#=ChunkMidZ#-OldCameraZ#

ChunkDist#=sqrt(ChunkDirX#*ChunkDirX#+ChunkDirY#*ChunkDirY#+ChunkDirZ#*ChunkDirZ#)

ChunkDirX#=ChunkDirX#/ChunkDist#
ChunkDirY#=ChunkDirY#/ChunkDist#
ChunkDirZ#=ChunkDirZ#/ChunkDist#

MoveCameraLocalZ(1,1)

NewCameraX#=GetCameraX(1)
NewCameraY#=GetCameraY(1)
NewCameraZ#=GetCameraZ(1)

MoveCameraLocalZ(1,-1)

CameraDirX#=NewCameraX#-OldCameraX#
CameraDirY#=NewCameraY#-OldCameraY#
CameraDirZ#=NewCameraZ#-OldCameraZ#

Dot#=ChunkDirX#*CameraDirX#+ChunkDirY#*CameraDirY#+ChunkDirZ#*CameraDirZ#
*/

/*
function Voxel_RecursiveLight(CubeX,CubeY,CubeZ,LightValue,World ref as WorldData)
	if CubeX>World.Chunk.length then exitfunction
	if CubeX<0 then exitfunction
	if CubeY>World.Chunk[0].length then exitfunction
	if CubeY<0 then exitfunction
	if CubeZ>World.Chunk[0,0].length then exitfunction
	if CubeZ<0 then exitfunction
	
	if World.Chunk[CubeX,CubeY,CubeZ].BlockType>0
		Attenuation=15
	else
		Attenuation=1
	endif

	LightValue=LightValue-Attenuation

	if LightValue<=World.Chunk[CubeX,CubeY,CubeZ].LightValue then exitfunction
	
	World.Chunk[CubeX,CubeY,CubeZ].LightValue=LightValue

	Voxel_RecursiveLight(CubeX,CubeY,CubeZ+1,LightValue,World)
	Voxel_RecursiveLight(CubeX,CubeY,CubeZ-1,LightValue,World)
	Voxel_RecursiveLight(CubeX,CubeY+1,CubeZ,LightValue,World)
	Voxel_RecursiveLight(CubeX,CubeY-1,CubeZ,LightValue,World)
	Voxel_RecursiveLight(CubeX+1,CubeY,CubeZ,LightValue,World)
	Voxel_RecursiveLight(CubeX-1,CubeY,CubeZ,LightValue,World)
endfunction
*/