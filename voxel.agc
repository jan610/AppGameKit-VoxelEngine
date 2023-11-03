//~#import_plugin OpenSimplexNoise as Noise
//~#include "threadnoise.agc"

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

type Int3Data
	X as integer
	Y as integer
	Z as integer
endtype

type Int2Data
	X as integer
	Z as integer
endtype

type RGBAData
	Red
	Green
	Blue
	Alpha
endtype

type VertexData
	Pos as Vec3Data
	UV as Vec2Data
	Color as RGBAData
	Normal as Vec3Data
	Tangent as Vec3Data
	Binormal as Vec3Data
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
	TerrainWidth as integer
	TerrainHeight as integer
	TerrainDepth as integer
	Terrain as TerrainData[-1,-1,-1]
	Chunk as ChunkData[-1,-1]
	Height as integer[-1,-1]
endtype

type TerrainData
	BlockType as integer
	BlockLight as integer
	SunLight as integer
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

type BorderData
	Min as Int2Data
	Max as Int2Data
endtype

type ChunkData
	Border as BorderData
	ObjectID as integer
	Visible as integer
endtype

type MemblockData
	GrassMemblockID as integer
	CaveMemblockID as integer
	IronMemblockID as integer
endtype

type ChunkListData
	Hash as integer
	X as integer
	Z as integer
endtype

type SpreadLightData
	X as integer
	Y as integer
	Z as Integer
	Light as Integer
endtype

global Voxel_ChunkMemblock as MemblockData[]
global Voxel_Neighbors as Int3Data[5]
global Voxel_LoadChunkList as ChunkListData[]
global Voxel_UnloadChunkList as ChunkListData[]
global Voxel_TempChunk as ChunkListData
global Voxel_TempSubimages as SubimageData[5]
global Voxel_WorldSize as Int2Data
global Voxel_ChunkView as BorderData
global Voxel_SpreadLight as SpreadLightData[]

global Voxel_AmbientLight as integer
global Voxel_ChunkSize as integer
global Voxel_DiffuseImageID as integer
global Voxel_NormalImageID as integer
global Voxel_ShaderID as integer
global Voxel_TempID as integer
global Voxel_UpdateTimer# as float
global Voxel_CameraChunkOldX as integer
global Voxel_CameraChunkOldZ as integer
global Voxel_WorldName$ as string
		
global Voxel_DebugMeshBuildingTime# as float
global Voxel_DebugSaveTime# as float
global Voxel_DebugCounter as integer

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData,ChunkSize,TerrainSizeX,TerrainSizeY,TerrainSizeZ,File$,WorldName$)
	Voxel_DiffuseImageID=LoadImage(File$)
//~	Voxel_NormalImageID=LoadImage(StringInsertAtDelemiter(File$,"_n.","."))
	
	Voxel_ShaderID=LoadShader("shader/vertex.vs","shader/fragment.ps")
	
	Voxel_WorldName$=WorldName$
	Voxel_ChunkSize=ChunkSize
	Voxel_WorldSize.X=trunc((TerrainSizeX+1)/Voxel_ChunkSize)-1
	Voxel_WorldSize.Z=trunc((TerrainSizeZ+1)/Voxel_ChunkSize)-1
	Voxel_AmbientLight=2
	
	World.TerrainWidth=TerrainSizeX
	World.TerrainHeight=TerrainSizeY
	World.TerrainDepth=TerrainSizeZ
	
	World.Height.length=World.TerrainWidth+1
	World.Terrain.length=World.TerrainWidth+1
	for X=0 to World.TerrainWidth+1
		World.Height[X].length=World.TerrainDepth+1
		World.Terrain[X].length=World.TerrainHeight+1
		for Y=0 to World.TerrainHeight+1
			World.Terrain[X,Y].length=World.TerrainDepth+1
		next Y
	next X
	
	World.Chunk.length=Voxel_WorldSize.X
	for X=0 to Voxel_WorldSize.X
		World.Chunk[X].length=Voxel_WorldSize.Z
	next X
	
	Voxel_Neighbors[0].x=0
	Voxel_Neighbors[0].y=1
	Voxel_Neighbors[0].z=0
	
	Voxel_Neighbors[1].x=0
	Voxel_Neighbors[1].y=-1
	Voxel_Neighbors[1].z=0
	
	Voxel_Neighbors[2].x=1
	Voxel_Neighbors[2].y=0
	Voxel_Neighbors[2].z=0
	
	Voxel_Neighbors[3].x=-1
	Voxel_Neighbors[3].y=0
	Voxel_Neighbors[3].z=0
	
	Voxel_Neighbors[4].x=0
	Voxel_Neighbors[4].y=0
	Voxel_Neighbors[4].z=1
	
	Voxel_Neighbors[5].x=0
	Voxel_Neighbors[5].y=0
	Voxel_Neighbors[5].z=-1
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

function Voxel_SaveChunk(World ref as WorldData,Border ref as BorderData,ChunkX,ChunkZ)
	StartTime#=Timer()
	local RunLength as integer
	local OldBlockType as integer
	OpenToWrite(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin",0) 
	for CubeX=Border.Min.X to Border.Max.X
        for CubeZ=Border.Min.Z to Border.Max.Z
            RunLength=0
            Height=World.Height[CubeX,CubeZ]
            WriteByte(1,Height)
            for CubeY=1 to Height
                inc RunLength
                if World.Terrain[CubeX,CubeY,CubeZ].BlockType<>OldBlockType
                    OldBlockType=World.Terrain[CubeX,CubeY,CubeZ].BlockType
                    WriteByte(1,RunLength)
                    WriteByte(1,World.Terrain[CubeX,CubeY,CubeZ].BlockType)
                    RunLength=0
                endif
            next CubeY
            WriteByte(1,RunLength)
            WriteByte(1,World.Terrain[CubeX,CubeY,CubeZ].BlockType)
        next CubeZ
	next CubeX
    CloseFile(1)
    Voxel_DebugSaveTime#=Timer()-StartTime#
endfunction

function Voxel_ChunkFileExists(ChunkX,ChunkZ)
	local Result as integer
	Result = GetFileExists(Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ))
endfunction Result

function Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	if ChunkX<Voxel_ChunkView.Min.X or ChunkX>Voxel_ChunkView.Max.X or ChunkZ<Voxel_ChunkView.Min.Z or ChunkZ>Voxel_ChunkView.Max.Z then exitfunction
	Voxel_TempChunk.X=ChunkX
	Voxel_TempChunk.Z=ChunkZ
	Voxel_TempChunk.Hash=ChunkX+(ChunkZ*Voxel_WorldSize.X)
	if Voxel_LoadChunkList.IndexOf(Voxel_TempChunk.Hash)=-1 and Voxel_UnloadChunkList.IndexOf(Voxel_TempChunk.Hash)=-1 then Voxel_LoadChunkList.insert(Voxel_TempChunk)
endfunction

function Voxel_AddChunktoUnloadList(ChunkX,ChunkZ)
	Voxel_TempChunk.X=ChunkX
	Voxel_TempChunk.Z=ChunkZ
	Voxel_TempChunk.Hash=ChunkX+(ChunkZ*Voxel_WorldSize.X)
	if Voxel_UnloadChunkList.IndexOf(Voxel_TempChunk.Hash)=-1 then Voxel_UnloadChunkList.insert(Voxel_TempChunk)
endfunction

function Voxel_UpdateChunks(FaceImages ref as FaceimageData,World ref as WorldData,CameraX,CameraZ,ViewDistance)	
	Voxel_CameraChunkX=trunc(CameraX/Voxel_ChunkSize)
	Voxel_CameraChunkZ=trunc(CameraZ/Voxel_ChunkSize)
	
	if Voxel_CameraChunkX<>Voxel_CameraChunkOldX or Voxel_CameraChunkZ<>Voxel_CameraChunkOldZ
		CameraDirX=Voxel_CameraChunkX-Voxel_CameraChunkOldX
		CameraDirZ=Voxel_CameraChunkZ-Voxel_CameraChunkOldZ
		Voxel_CameraChunkOldX=Voxel_CameraChunkX
		Voxel_CameraChunkOldZ=Voxel_CameraChunkZ
	
		for Dist=0 to ViewDistance
			Voxel_ChunkView.Min.X=Core_Clamp(Voxel_CameraChunkX-Dist,0,Voxel_WorldSize.X)
			Voxel_ChunkView.Min.Z=Core_Clamp(Voxel_CameraChunkZ-Dist,0,Voxel_WorldSize.Z)
			Voxel_ChunkView.Max.X=Core_Clamp(Voxel_CameraChunkX+Dist,0,Voxel_WorldSize.X)
			Voxel_ChunkView.Max.Z=Core_Clamp(Voxel_CameraChunkZ+Dist,0,Voxel_WorldSize.Z)
		
			for ChunkX=Voxel_ChunkView.Min.X to Voxel_ChunkView.Max.X
				for ChunkZ=Voxel_ChunkView.Min.Z to Voxel_ChunkView.Max.Z
					if World.Chunk[ChunkX,ChunkZ].ObjectID=0 then Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
				next ChunkZ
			next ChunkX
		next Dist
		
		//>--- unkomment this to unload chunks outside of the view range ----<
		
//~		MinX=Core_Clamp(Voxel_CameraChunkX-ViewDistance-1,0,Voxel_WorldSize.X)
//~		MinZ=Core_Clamp(Voxel_CameraChunkZ-ViewDistance-1,0,Voxel_WorldSize.Z)
//~		MaxX=Core_Clamp(Voxel_CameraChunkX+ViewDistance+1,0,Voxel_WorldSize.X)
//~		MaxZ=Core_Clamp(Voxel_CameraChunkZ+ViewDistance+1,0,Voxel_WorldSize.Z)
//~		if CameraDirX=1
//~			for ChunkZ=MinZ to MaxZ
//~				if World.Chunk[MinX,ChunkZ].Visible=1
//~					Voxel_AddChunktoUnloadList(MinX,ChunkZ)
//~					World.Chunk[MinX,ChunkZ].Visible=0
//~				endif
//~			next ChunkZ
//~		elseif CameraDirX-1
//~			for ChunkZ=MinZ to MaxZ
//~				if World.Chunk[MaxX,ChunkZ].Visible=1
//~					Voxel_AddChunktoUnloadList(MaxX,ChunkZ)
//~					World.Chunk[MaxX,ChunkZ].Visible=0
//~				endif
//~			next ChunkZ
//~		endif
//~		if CameraDirZ=1
//~			for ChunkX=MinX to MaxX
//~				if World.Chunk[ChunkX,MinZ].Visible=1
//~					Voxel_AddChunktoUnloadList(ChunkX,MinZ)
//~					World.Chunk[ChunkX,MinZ].Visible=0
//~				endif
//~			next ChunkX
//~		elseif CameraDirZ-1
//~			for ChunkX=MinX to MaxX
//~				if World.Chunk[ChunkX,MaxZ].Visible=1
//~					Voxel_AddChunktoUnloadList(ChunkX,MaxZ)
//~					World.Chunk[ChunkX,MaxZ].Visible=0
//~				endif
//~			next ChunkX
//~		endif
	endif
	
	Timer#=Timer()
	if Timer#>Voxel_UpdateTimer#
		Voxel_UpdateTimer#=Timer#+0.1
		
		if Voxel_LoadChunkList.length>-1
			ChunkX=Voxel_LoadChunkList[0].X
			ChunkZ=Voxel_LoadChunkList[0].Z
			
			if World.Chunk[ChunkX,ChunkZ].ObjectID=0
				World.Chunk[ChunkX,ChunkZ].Border.Min.X=ChunkX*Voxel_ChunkSize+1
				World.Chunk[ChunkX,ChunkZ].Border.Min.Z=ChunkZ*Voxel_ChunkSize+1
				World.Chunk[ChunkX,ChunkZ].Border.Max.X=ChunkX*Voxel_ChunkSize+Voxel_ChunkSize
				World.Chunk[ChunkX,ChunkZ].Border.Max.Z=ChunkZ*Voxel_ChunkSize+Voxel_ChunkSize
				
				Voxel_CreateTerrain(World.Chunk[ChunkX,ChunkZ].Border,World)
				
				Voxel_UpdateChunkSunLight(World.Chunk[ChunkX,ChunkZ].Border,World,15)
				
				Voxel_CreateChunk(Faceimages,World.Chunk[ChunkX,ChunkZ],World)
				World.Chunk[ChunkX,ChunkZ].Visible=1
			else
				Voxel_UpdateChunkSunLight(World.Chunk[ChunkX,ChunkZ].Border,World,15)
				
				Voxel_UpdateChunk(Faceimages,World.Chunk[ChunkX,ChunkZ],World)
			endif
			
			Voxel_LoadChunkList.remove(0)
		endif
		
		//>--- unkomment this to unload chunks outside of the view range ----<
		
//~		if Voxel_UnloadChunkList.length>-1
//~			ChunkX=Voxel_UnloadChunkList[0].X
//~			ChunkZ=Voxel_UnloadChunkList[0].Z
//~			Voxel_SaveChunk(World,World.Chunk[ChunkX,ChunkZ].Border,ChunkX,ChunkZ)
//~			Voxel_DeleteObject(World.Chunk[ChunkX,ChunkZ])
//~			Voxel_UnloadChunkList.remove(0)
//~		endif
	endif
endfunction

function Voxel_DeleteObject(Chunk ref as ChunkData)	
	DeleteObject(Chunk.ObjectID)
	Chunk.ObjectID=0
endfunction

function Voxel_CreateChunk(FaceImages ref as FaceimageData,Chunk ref as ChunkData,World ref as WorldData)	
	local Object as ObjectData
	for CubeX=Chunk.Border.Min.X to Chunk.Border.Max.X
		for CubeZ=Chunk.Border.Min.Z to Chunk.Border.Max.Z
			for CubeY=1 to World.Height[CubeX,CubeZ]
				Voxel_GenerateCubeFaces(Object,Faceimages,World,CubeX,CubeY,CubeZ)
			next CubeY
		next CubeZ
	next CubeX
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)		
		Chunk.ObjectID=CreateObjectFromMeshMemblock(MemblockID)
		DeleteMemblock(MemblockID)
		Object.Index.length=-1
		Object.Vertex.length=-1
		
		SetObjectPosition(Chunk.ObjectID,Chunk.Border.Min.X-1,0,Chunk.Border.Min.Z-1)
		SetObjectImage(Chunk.ObjectID,Voxel_DiffuseImageID,0)
		SetObjectShader(Chunk.ObjectID,Voxel_ShaderID)
		Chunk.Visible=1
	endif
endfunction Chunk.ObjectID

function Voxel_UpdateChunk(Faceimages ref as FaceimageData,Chunk ref as ChunkData,World ref as WorldData)
	StartTime#=Timer()
	local Object as ObjectData
	for CubeX=Chunk.Border.Min.X to Chunk.Border.Max.X
		for CubeZ=Chunk.Border.Min.Z to Chunk.Border.Max.Z
			for CubeY=1 to World.Height[CubeX,CubeZ]
				Voxel_GenerateCubeFaces(Object,Faceimages,World,CubeX,CubeY,CubeZ)
			next CubeY
		next CubeZ
	next CubeX
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)
		SetObjectMeshFromMemblock(Chunk.ObjectID,1,MemblockID)
		DeleteMemblock(MemblockID)
		Object.Index.length=-1
		Object.Vertex.length=-1
	endif
	Voxel_DebugMeshBuildingTime#=Timer()-StartTime#
endfunction

function Voxel_CreateTerrain(Border ref as BorderData,World ref as WorldData)	
	Frecueny2D#=32.0
	Frecueny3DCave#=12.0
	Frecueny3DIron#=2.0
	DirtLayerHeight=3
	WorldHeight=World.Terrain[0].length
	GrassStart=WorldHeight*0.4
	for X=Border.Min.X-1 to Border.Max.X+1
		for Z=Border.Min.Z-1 to Border.Max.Z+1
			Value1#=GetNoiseXY(X/Frecueny2D#,Z/Frecueny2D#)*WorldHeight
			GrassLayer=GrassStart+Value1#/12.0
			World.Height[X,Z]=GrassLayer
			
			for Y=World.Terrain[X].length to 1 step -1		
				if Y=GrassLayer
					World.Terrain[X,Y,Z].BlockType=1
				elseif Y>=GrassLayer-DirtLayerHeight and Y<GrassLayer
					World.Terrain[X,Y,Z].BlockType=3
				elseif Y<GrassLayer-DirtLayerHeight
					World.Terrain[X,Y,Z].BlockType=2
				endif
				
				Cave#=GetNoiseXYZ(X/Frecueny3DCave#,Y/Frecueny3DCave#,Z/Frecueny3DCave#)
				if Cave#>0.5
					World.Terrain[X,Y,Z].BlockType=0
					if Y=World.Height[X,Z] then World.Height[X,Z]=Y-1
				endif
				
				World.Terrain[X,Y,Z].SunLight=Voxel_AmbientLight
				World.Terrain[X,Y,Z].BlockLight=Voxel_AmbientLight
				if Y>World.Height[X,Z]
					World.Terrain[X,Y,Z].SunLight=15
				endif
			next Y
		next Z
	next X
endfunction

function Voxel_CreateBlockLight(World ref as WorldData,CubeX,CubeY,CubeZ)	
	LightIntensitiy=Voxel_IsLightBlock(World,CubeX,CubeY,CubeZ)
	if LightIntensitiy>Voxel_AmbientLight
		Voxel_UpdateBlockLight(World,CubeX,CubeY,CubeZ,LightIntensitiy)
	endif
endfunction

function Voxel_UpdateBlockLight(World ref as WorldData,StartX,StartY,StartZ,StartBlockLight as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]

	FrontierTemp.X=StartX
	FrontierTemp.Y=StartY
	FrontierTemp.Z=StartZ
	Frontier.insert(FrontierTemp)
	
	World.Terrain[StartX,StartY,StartZ].BlockLight=StartBlockLight
	
	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		for NeighbourID=0 to 5
			NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
			if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
				if World.Terrain[CubeX,CubeY,CubeZ].BlockLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].BlockLight+1
					FrontierTemp.X=NeighbourX
					FrontierTemp.Y=NeighbourY
					FrontierTemp.Z=NeighbourZ
					Frontier.insert(FrontierTemp)
					World.Terrain[NeighbourX,NeighbourY,NeighbourZ].BlockLight=World.Terrain[CubeX,CubeY,CubeZ].BlockLight-1
					
					ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
					ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
					Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
				endif
			endif
		next NeighbourID
	endwhile
endfunction

function Voxel_UpdateBlockShadow(World ref as WorldData,StartX,StartY,StartZ)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]
	local TempBlockLight as integer
	local TempSpreadLight as SpreadLightData

	FrontierTemp.X=StartX
	FrontierTemp.Y=StartY
	FrontierTemp.Z=StartZ
	Frontier.insert(FrontierTemp)
	
	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		TempBlockLight=World.Terrain[CubeX,CubeY,CubeZ].BlockLight
		if TempBlockLight<>Voxel_AmbientLight
			for NeighbourID=0 to 5
				NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
				if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
					if TempBlockLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].BlockLight
						FrontierTemp.X=NeighbourX
						FrontierTemp.Y=NeighbourY
						FrontierTemp.Z=NeighbourZ
						Frontier.insert(FrontierTemp)
						
						World.Terrain[CubeX,CubeY,CubeZ].BlockLight=Voxel_AmbientLight
						
						ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
						ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
					else
						TempSpreadLight.X=NeighbourX
						TempSpreadLight.Y=NeighbourY
						TempSpreadLight.Z=NeighbourZ
						TempSpreadLight.Light=World.Terrain[NeighbourX,NeighbourY,NeighbourZ].BlockLight
						Voxel_SpreadLight.insert(TempSpreadLight)
					endif
				endif
			next NeighbourID
		endif
	endwhile

	for ID=0 to Voxel_SpreadLight.length-1
		CubeX=Voxel_SpreadLight[ID].X
		CubeY=Voxel_SpreadLight[ID].Y
		CubeZ=Voxel_SpreadLight[ID].Z
		Light=Voxel_SpreadLight[ID].Light
		Voxel_UpdateBlockLight(World,CubeX,CubeY,CubeZ,Light)
	next ID
	Voxel_SpreadLight.length=-1
endfunction

function Voxel_UpdateSunLight(World ref as WorldData,StartX,StartY,StartZ,StartSunLight as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]

	FrontierTemp.X=StartX
	FrontierTemp.Y=StartY
	FrontierTemp.Z=StartZ
	Frontier.insert(FrontierTemp)
	
	World.Terrain[StartX,StartY,StartZ].SunLight=StartSunLight
	
	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		
		for NeighbourID=0 to 5
			NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
			if NeighbourY<=World.Height[NeighbourX,NeighbourZ]
				if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
					if World.Terrain[CubeX,CubeY,CubeZ].SunLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight+1
						FrontierTemp.X=NeighbourX
						FrontierTemp.Y=NeighbourY
						FrontierTemp.Z=NeighbourZ
						Frontier.insert(FrontierTemp)
						World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight=World.Terrain[CubeX,CubeY,CubeZ].SunLight-1
						
						ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
						ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
					endif
				endif
			endif
		next NeighbourID
	endwhile
endfunction

function Voxel_UpdateChunkSunLight(Border ref as BorderData,World ref as WorldData,StartSunLight as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]

	for CubeX=Border.Min.X to Border.Max.X
		for CubeZ=Border.Min.Z to Border.Max.Z
			CubeY=World.Height[CubeX,CubeZ]+1
			FrontierTemp.X=CubeX
			FrontierTemp.Y=CubeY
			FrontierTemp.Z=CubeZ
			Frontier.insert(FrontierTemp)
			
			World.Terrain[CubeX,CubeY,CubeZ].SunLight=StartSunLight
		next CubeZ
	next CubeX

	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		
		for NeighbourID=0 to 5
			NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
			if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
				if World.Terrain[CubeX,CubeY,CubeZ].SunLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight+1
					FrontierTemp.X=NeighbourX
					FrontierTemp.Y=NeighbourY
					FrontierTemp.Z=NeighbourZ
					Frontier.insert(FrontierTemp)
					World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight=World.Terrain[CubeX,CubeY,CubeZ].SunLight-1
					
					ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
					ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
					Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
				endif
			endif
		next NeighbourID
	endwhile
endfunction

function Voxel_UpdateSunShadow(World ref as WorldData,StartX,StartY,StartZ)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]
	local TempSunLight as integer
	local TempSpreadLight as SpreadLightData

	FrontierTemp.X=StartX
	FrontierTemp.Y=StartY
	FrontierTemp.Z=StartZ
	Frontier.insert(FrontierTemp)
	
	while Frontier.length>=0
		CubeX=Frontier[0].X
		CubeY=Frontier[0].Y
		CubeZ=Frontier[0].Z
		Frontier.remove(0)
		TempSunLight=World.Terrain[CubeX,CubeY,CubeZ].SunLight
		if TempSunLight<>Voxel_AmbientLight
			for NeighbourID=0 to 5
				NeighbourX=CubeX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=CubeY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=CubeZ+Voxel_Neighbors[NeighbourID].Z
				if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
					if TempSunLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight
						FrontierTemp.X=NeighbourX
						FrontierTemp.Y=NeighbourY
						FrontierTemp.Z=NeighbourZ
						Frontier.insert(FrontierTemp)
						
						World.Terrain[CubeX,CubeY,CubeZ].SunLight=Voxel_AmbientLight
						
						ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
						ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
					else
						TempSpreadLight.X=NeighbourX
						TempSpreadLight.Y=NeighbourY
						TempSpreadLight.Z=NeighbourZ
						TempSpreadLight.Light=World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight
						Voxel_SpreadLight.insert(TempSpreadLight)
					endif
				endif
			next NeighbourID
		endif
	endwhile

	for ID=0 to Voxel_SpreadLight.length-1
		CubeX=Voxel_SpreadLight[ID].X
		CubeY=Voxel_SpreadLight[ID].Y
		CubeZ=Voxel_SpreadLight[ID].Z
		Light=Voxel_SpreadLight[ID].Light
		Voxel_UpdateBlockLight(World,CubeX,CubeY,CubeZ,Light)
	next ID
	Voxel_SpreadLight.length=-1
endfunction

function Voxel_UpdateHeightAndSunlight(World ref as WorldData,X,Y,Z,LightValue)
	repeat
		World.Terrain[X,Y,Z].SunLight=LightValue
		Y=Y-1
		if Y<=1 then Exitfunction
	until Voxel_IsTransparentBlock(World,X,Y,Z)=0
	World.Height[X,Z]=Y
	if LightValue>Voxel_AmbientLight
		Voxel_UpdateSunLight(World,X,Y,Z,LightValue)
	else
		Voxel_UpdateSunShadow(World,X,Y,Z)
	endif
endfunction

function Voxel_IsLightBlock(World ref as WorldData,X,Y,Z)
	select World.Terrain[X,Y,Z].BlockType
		case 11
			exitfunction 14
		endcase
	endselect
endfunction 0

function Voxel_IsTransparentBlock(World ref as WorldData,X,Y,Z)
	select World.Terrain[X,Y,Z].BlockType
		case 0
			exitfunction 1
		endcase
	endselect
endfunction 0

function Voxel_AddCubeToObject(World ref as WorldData,X,Y,Z,BlockType)
	X=Core_Clamp(X,1,World.TerrainWidth-1)
	Y=Core_Clamp(Y,1,World.TerrainHeight-1)
	Z=Core_Clamp(Z,1,World.TerrainDepth-1)
	
	if Y>World.Height[X,Z]
		Voxel_UpdateHeightAndSunlight(World,X,Y,Z,Voxel_AmbientLight)
		World.Height[X,Z]=Y
	endif
	
	World.Terrain[X,Y,Z].BlockType=BlockType
//~	World.Terrain[X,Y,Z].BlockLight=Voxel_AmbientLight
//~	World.Terrain[X,Y,Z].SunLight=Voxel_AmbientLight
	Voxel_CreateBlockLight(World,X,Y,Z)
	
	ChunkX=trunc((X-1)/Voxel_ChunkSize)
	ChunkZ=trunc((Z-1)/Voxel_ChunkSize)
	Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	
	CubeX=1+Mod(X-1,Voxel_ChunkSize)
	CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
	
	if CubeX=Voxel_ChunkSize
		if ChunkX+1<=Voxel_WorldSize.X then Voxel_AddChunktoLoadList(ChunkX+1,ChunkZ)
	endif
	if CubeX=1
		if ChunkX-1>=0 then Voxel_AddChunktoLoadList(ChunkX-1,ChunkZ)
	endif
	if CubeZ=Voxel_ChunkSize
		if ChunkZ+1<=Voxel_WorldSize.Z then Voxel_AddChunktoLoadList(ChunkX,ChunkZ+1)
	endif
	if CubeZ=1
		if ChunkZ-1>=0 then Voxel_AddChunktoLoadList(ChunkX,ChunkZ-1)
	endif
endfunction

function Voxel_RemoveCubeFromObject(World ref as WorldData,X,Y,Z)
	X=Core_Clamp(X,1,World.TerrainWidth-1)
	Y=Core_Clamp(Y,1,World.TerrainHeight-1)
	Z=Core_Clamp(Z,1,World.TerrainDepth-1)
	
	if Y=World.Height[X,Z]
		Voxel_UpdateHeightAndSunlight(World,X,Y,Z,15)
	elseif Y<World.Height[X,Z]
		TempHeight=World.Height[X,Z]
		Voxel_UpdateHeightAndSunlight(World,X,Y,Z,Voxel_AmbientLight)
		World.Height[X,Z]=TempHeight
	endif
	BlockType=World.Terrain[X,Y,Z].BlockType
	World.Terrain[X,Y,Z].BlockType=0
	
	Voxel_UpdateBlockShadow(World,X,Y,Z)

	ChunkX=trunc((X-1)/Voxel_ChunkSize)
	ChunkZ=trunc((Z-1)/Voxel_ChunkSize)
	Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	
	CubeX=1+Mod(X-1,Voxel_ChunkSize)
	CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
	
	if CubeX=Voxel_ChunkSize
		if ChunkX+1<=Voxel_WorldSize.X then Voxel_AddChunktoLoadList(ChunkX+1,ChunkZ)
	endif
	if CubeX=1
		if ChunkX-1>=0 then Voxel_AddChunktoLoadList(ChunkX-1,ChunkZ)
	endif
	if CubeZ=Voxel_ChunkSize
		if ChunkZ+1<=Voxel_WorldSize.Z then Voxel_AddChunktoLoadList(ChunkX,ChunkZ+1)
	endif
	if CubeZ=1
		if ChunkZ-1>=0 then Voxel_AddChunktoLoadList(ChunkX,ChunkZ-1)
	endif
endfunction BlockType

function Voxel_RemoveCubeListFromObject(World ref as WorldData,CubeList as Int3Data[])
	for index=0 to CubeList.length
		X=Core_Clamp(CubeList[index].X,1,World.TerrainWidth-1)
		Y=Core_Clamp(CubeList[index].Y,1,World.TerrainHeight-1)
		Z=Core_Clamp(CubeList[index].Z,1,World.TerrainDepth-1)
		
		if Y=World.Height[X,Z] then Voxel_UpdateHeightAndSunlight(World,X,Y,Z,15)
		World.Terrain[X,Y,Z].BlockType=0
		
		ChunkX=trunc((X-1)/Voxel_ChunkSize)
		ChunkZ=trunc((Z-1)/Voxel_ChunkSize)
		Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
		
		CubeX=1+Mod(X-1,Voxel_ChunkSize)
		CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
	
		if CubeX=Voxel_ChunkSize
			if ChunkX+1<=Voxel_WorldSize.X then Voxel_AddChunktoLoadList(ChunkX+1,ChunkZ)
		endif
		if CubeX=1
			if ChunkX-1>=0 then Voxel_AddChunktoLoadList(ChunkX-1,ChunkZ)
		endif
		if CubeZ=Voxel_ChunkSize
			if ChunkZ+1<=Voxel_WorldSize.Z then Voxel_AddChunktoLoadList(ChunkX,ChunkZ+1)
		endif
		if CubeZ=1
			if ChunkZ-1>=0 then Voxel_AddChunktoLoadList(ChunkX,ChunkZ-1)
		endif
	next index
endfunction

function Voxel_GenerateCubeFaces(Object ref as ObjectData,Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z)	
	if World.Terrain[X,Y,Z].BlockType>0
		
		Index=World.Terrain[X,Y,Z].BlockType-1
		
		local LightValue as integer
		Voxel_TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		Voxel_TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		Voxel_TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		Voxel_TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		Voxel_TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		Voxel_TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]
		
		CubeX=1+Mod(X-1,Voxel_ChunkSize)
		CubeY=Y
		CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
		
		if World.Terrain[X,Y,Z+1].BlockType=0
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X,Y,Z+1].BlockLight,World.Terrain[X,Y,Z+1].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[0],CubeX,CubeY,CubeZ,FaceFront,AO0,AO1,AO2,AO3,Flipped)
		endif
		if World.Terrain[X,Y,Z-1].BlockType=0			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X,Y,Z-1].BlockLight,World.Terrain[X,Y,Z-1].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[1],CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3,Flipped)
		endif
		if World.Terrain[X+1,Y,Z].BlockType=0	
			side1=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X+1,Y,Z].BlockLight,World.Terrain[X+1,Y,Z].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[2],CubeX,CubeY,CubeZ,FaceRight,AO0,AO1,AO2,AO3,Flipped)
		endif
		if World.Terrain[X-1,Y,Z].BlockType=0		
			side1=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X-1,Y,Z].BlockLight,World.Terrain[X-1,Y,Z].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[3],CubeX,CubeY,CubeZ,FaceLeft,AO0,AO1,AO2,AO3,Flipped)
		endif
		if World.Terrain[X,Y+1,Z].BlockType=0		
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X,Y+1,Z].BlockLight,World.Terrain[X,Y+1,Z].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[4],CubeX,CubeY,CubeZ,FaceUp,AO0,AO1,AO2,AO3,Flipped)
		endif
		if World.Terrain[X,Y-1,Z].BlockType=0			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(World.Terrain[X,Y-1,Z].BlockLight,World.Terrain[X,Y-1,Z].SunLight)/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[5],CubeX,CubeY,CubeZ,FaceDown,AO0,AO1,AO2,AO3,Flipped)
		endif
	endif
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
endfunction 3 - (side1 + side2 + corner)

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as ObjectData,Subimages ref as SubimageData,X,Y,Z,FaceDir,AO0,AO1,AO2,AO3,Flipped)
	TempVertex as VertexData[3]
	HalfFaceSize#=0.5	
	TextureSize#=256
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
			
//~			Voxel_SetObjectFaceTangent(TempVertex[0],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],-1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],-1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,1,0)
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
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,1,0)
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
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,1)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,1,0)
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
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],0,0,-1)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],0,0,-1)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,1,0)
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
			
			Voxel_SetObjectFaceColor(TempVertex[0],AO0,AO0,AO0,0)
			Voxel_SetObjectFaceColor(TempVertex[1],AO1,AO1,AO1,0)
			Voxel_SetObjectFaceColor(TempVertex[2],AO2,AO2,AO2,0)
			Voxel_SetObjectFaceColor(TempVertex[3],AO3,AO3,AO3,0)
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,0,1)
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
		
//~			Voxel_SetObjectFaceTangent(TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBinormal(TempVertex[3],0,0,1)
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
	Vertex.Color.Red=Red
	Vertex.Color.Green=Green
	Vertex.Color.Blue=Blue
	Vertex.Color.Alpha=Alpha
endfunction

function Voxel_SetObjectFaceTangent(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Tangent.X#=X#
	Vertex.Tangent.Y#=Y#
	Vertex.Tangent.Z#=Z#
endfunction

function Voxel_SetObjectFaceBinormal(Vertex ref as VertexData,X#,Y#,Z#)
	Vertex.Binormal.X#=X#
	Vertex.Binormal.Y#=Y#
	Vertex.Binormal.Z#=Z#
endfunction

// Generate the mesh header for a simple one sided plane
// Position,Normal,UV,Color,Tangent and Binormal Data
function Voxel_CreateMeshMemblock(VertexCount,IndexCount)
//~	Attributes=6
	Attributes=4
//~	VertexSize=3*4+3*4+2*4+4*1+3*4+3*4
	VertexSize=3*4+3*4+2*4+4*1
//~	VertexOffset=100
	VertexOffset=72
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

//~	SetMemblockByte(MemblockID,72,0)
//~	SetMemblockByte(MemblockID,72+1,3)
//~	SetMemblockByte(MemblockID,72+2,0)
//~	SetMemblockByte(MemblockID,72+3,8)
//~	SetMemblockString(MemblockID,72+4,"tangent"+chr(0))

//~	SetMemblockByte(MemblockID,84,0)
//~	SetMemblockByte(MemblockID,84+1,3)
//~	SetMemblockByte(MemblockID,84+2,0)
//~	SetMemblockByte(MemblockID,84+3,12)
//~	SetMemblockString(MemblockID,84+4,"binormal"+chr(0))
endfunction MemblockID

function Voxel_WriteMeshMemblock(MemblockID,Object ref as ObjectData)
	VertexCount=Object.Vertex.length+1
//~	VertexSize=3*4+3*4+2*4+4*1+3*4+3*4
	VertexSize=3*4+3*4+2*4+4*1
//~	VertexOffset=100
	VertexOffset=72
	IndexOffset=VertexOffset+(VertexCount*VertexSize)
	TangentOffset=3*4+3*4+2*4+4*1
	BinormalOffset=3*4+3*4+2*4+4*1+3*4
	for VertexID=0 to Object.Vertex.length
		SetMeshMemblockVertexPosition(MemblockID,VertexID,Object.Vertex[VertexID].Pos.X#,Object.Vertex[VertexID].Pos.Y#,Object.Vertex[VertexID].Pos.Z#)
		SetMeshMemblockVertexNormal(MemblockID,VertexID,Object.Vertex[VertexID].Normal.X#,Object.Vertex[VertexID].Normal.Y#,Object.Vertex[VertexID].Normal.Z#)
		SetMeshMemblockVertexUV(MemblockID,VertexID,Object.Vertex[VertexID].UV.X#,Object.Vertex[VertexID].UV.Y#)
		SetMeshMemblockVertexColor(MemblockID,VertexID,Object.Vertex[VertexID].Color.Red,Object.Vertex[VertexID].Color.Green,Object.Vertex[VertexID].Color.Blue,Object.Vertex[VertexID].Color.Alpha)
//~		Offset=VertexOffset+(VertexID*VertexSize)+TangentOffset
//~		Voxel_SetMemblockVec3(MemblockID,Offset,Object.Vertex[VertexID].Tangent.X#,Object.Vertex[VertexID].Tangent.Y#,Object.Vertex[VertexID].Tangent.Z#)
//~		Offset=VertexOffset+(VertexID*VertexSize)+BinormalOffset
//~		Voxel_SetMemblockVec3(MemblockID,Offset,Object.Vertex[VertexID].Binormal.X#,Object.Vertex[VertexID].Binormal.Y#,Object.Vertex[VertexID].Binormal.Z#)
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