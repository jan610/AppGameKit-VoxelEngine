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

type WorldData
	Chunk as ChunkData[-1,-1]
endtype

type ChunkData
	ObjectID as integer
	Visible as integer
	Height as integer[-1,-1]
	BlockType as integer[-1,-1,-1]
	BlockLight as integer[-1,-1,-1]
	SunLight as integer[-1,-1,-1]
endtype

type BorderData
	Min as Int2Data
	Max as Int2Data
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

global Voxel_Neighbors as Int3Data[5]
global Voxel_LoadChunkList as ChunkListData[]
global Voxel_UnloadChunkList as ChunkListData[]
global Voxel_TempSubimages as SubimageData[5]
global Voxel_SpreadLight as SpreadLightData[]
global Voxel_TempChunkList as ChunkListData
global Voxel_TempChunk as ChunkData
global Voxel_TempObject as ObjectData
global Voxel_TempInt3 as Int3Data
global Voxel_ChunkView as BorderData
global Voxel_ChunkMax as Int2Data
global Voxel_BlockMax as Int3Data

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
global Voxel_DebugTime# as float
global Voxel_DebugCounter as integer

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData,ChunkSize,SizeX,SizeY,SizeZ,File$,WorldName$)
	Voxel_DiffuseImageID=LoadImage(File$)
//~	Voxel_NormalImageID=LoadImage(StringInsertAtDelemiter(File$,"_n.","."))
	
	Voxel_ShaderID=LoadShader("shader/vertex.vs","shader/fragment.ps")
	
	Voxel_WorldName$=WorldName$
	Voxel_ChunkSize=ChunkSize
	Voxel_ChunkMax.X=trunc((SizeX+1)/Voxel_ChunkSize)-1
	Voxel_ChunkMax.Z=trunc((SizeZ+1)/Voxel_ChunkSize)-1
	Voxel_AmbientLight=2
	
	Voxel_BlockMax.X=SizeX
	Voxel_BlockMax.Y=SizeY
	Voxel_BlockMax.Z=SizeZ
	
	World.Chunk.length=Voxel_ChunkMax.X
	for ChunkX=0 to Voxel_ChunkMax.X
		World.Chunk[ChunkX].length=Voxel_ChunkMax.Z
		for ChunkZ=0 to Voxel_ChunkMax.Z
			World.Chunk[ChunkX,ChunkZ].Height.length=Voxel_ChunkSize
			World.Chunk[ChunkX,ChunkZ].BlockType.length=Voxel_ChunkSize
			World.Chunk[ChunkX,ChunkZ].BlockLight.length=Voxel_ChunkSize
			World.Chunk[ChunkX,ChunkZ].SunLight.length=Voxel_ChunkSize
			for X=0 to Voxel_ChunkSize-1
				World.Chunk[ChunkX,ChunkZ].Height[X].length=Voxel_ChunkSize
				World.Chunk[ChunkX,ChunkZ].BlockType[X].length=SizeY
				World.Chunk[ChunkX,ChunkZ].BlockLight[X].length=SizeY
				World.Chunk[ChunkX,ChunkZ].SunLight[X].length=SizeY
				for Y=0 to SizeY
					World.Chunk[ChunkX,ChunkZ].BlockType[X,Y].length=Voxel_ChunkSize
					World.Chunk[ChunkX,ChunkZ].BlockLight[X,Y].length=Voxel_ChunkSize
					World.Chunk[ChunkX,ChunkZ].SunLight[X,Y].length=Voxel_ChunkSize
				next Y
			next X
		next ChunkZ
	next ChunkX
	
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

function Voxel_SaveChunk(Chunk ref as ChunkData,ChunkX,ChunkZ)
	StartTime#=Timer()
	local RunLength as integer
	local OldBlockType as integer
	OpenToWrite(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin",0) 
	for LocalX=0 to Voxel_ChunkSize-1
        for LocalZ=0 to Voxel_ChunkSize-1
            RunLength=0
            Height=Chunk.Height[LocalX,LocalZ]
            WriteByte(1,Height)
            for LocalY=0 to Height
            		BlockType=Chunk.BlockType[LocalX,LocalY,LocalZ]
                inc RunLength
                if BlockType<>OldBlockType
                    OldBlockType=BlockType
                    WriteByte(1,RunLength)
                    WriteByte(1,BlockType)
                    RunLength=0
                endif
            next LocalY
            WriteByte(1,RunLength)
            WriteByte(1,Chunk.BlockType[LocalX,LocalY,LocalZ])
        next LocalZ
	next LocalX
    CloseFile(1)
    Voxel_DebugSaveTime#=Timer()-StartTime#
endfunction

function Voxel_ChunkFileExists(ChunkX,ChunkZ)
	local Result as integer
	Result = GetFileExists(Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ))
endfunction Result

function Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	if ChunkX<Voxel_ChunkView.Min.X or ChunkX>Voxel_ChunkView.Max.X or ChunkZ<Voxel_ChunkView.Min.Z or ChunkZ>Voxel_ChunkView.Max.Z then exitfunction
	Voxel_TempChunkList.X=ChunkX
	Voxel_TempChunkList.Z=ChunkZ
	Voxel_TempChunkList.Hash=ChunkX+(ChunkZ*Voxel_ChunkMax.X)
	if Voxel_LoadChunkList.IndexOf(Voxel_TempChunkList.Hash)=-1 then Voxel_LoadChunkList.insert(Voxel_TempChunkList)
endfunction

function Voxel_AddChunktoUnloadList(ChunkX,ChunkZ)
	Voxel_TempChunkList.X=ChunkX
	Voxel_TempChunkList.Z=ChunkZ
	Voxel_TempChunkList.Hash=ChunkX+(ChunkZ*Voxel_ChunkMax.X)
	if Voxel_UnloadChunkList.IndexOf(Voxel_TempChunkList.Hash)=-1 then Voxel_UnloadChunkList.insert(Voxel_TempChunkList)
endfunction

function Voxel_GetBlockTypeFromChunk(World ref as WorldData,ChunkX,ChunkZ,GlobalX,GlobalY,GlobalZ)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	BlockType=World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]
endfunction BlockType

function Voxel_GetBlockType(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	BlockType=World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]
endfunction BlockType

function Voxel_SetBlockType(World ref as WorldData,GlobalX,GlobalY,GlobalZ,BlockType)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]=BlockType
endfunction

function Voxel_GetBlockLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	LightValue=World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]
endfunction LightValue

function Voxel_SetBlockLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ,LightValue)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]=LightValue
endfunction

function Voxel_GetSunLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	LightValue=World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,GlobalY,LocalZ]
endfunction LightValue

function Voxel_SetSunLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ,LightValue)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	if LocalX<0 then LocalX=0
	if GlobalY<0 then GlobalY=0
	if LocalZ<0 then LocalZ=0
	World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,GlobalY,LocalZ]=LightValue
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
			Voxel_ChunkView.Min.X=Core_Clamp(Voxel_CameraChunkX-Dist,0,Voxel_ChunkMax.X)
			Voxel_ChunkView.Min.Z=Core_Clamp(Voxel_CameraChunkZ-Dist,0,Voxel_ChunkMax.Z)
			Voxel_ChunkView.Max.X=Core_Clamp(Voxel_CameraChunkX+Dist,0,Voxel_ChunkMax.X)
			Voxel_ChunkView.Max.Z=Core_Clamp(Voxel_CameraChunkZ+Dist,0,Voxel_ChunkMax.Z)
		
			for ChunkX=Voxel_ChunkView.Min.X to Voxel_ChunkView.Max.X
				for ChunkZ=Voxel_ChunkView.Min.Z to Voxel_ChunkView.Max.Z
					if World.Chunk[ChunkX,ChunkZ].ObjectID=0
						Voxel_TempChunkList.X=ChunkX
						Voxel_TempChunkList.Z=ChunkZ
						Voxel_TempChunkList.Hash=ChunkX+(ChunkZ*Voxel_ChunkMax.X)
						if Voxel_LoadChunkList.IndexOf(Voxel_TempChunkList.Hash)=-1
							Voxel_LoadChunkList.insert(Voxel_TempChunkList)
							if World.Chunk[ChunkX,ChunkZ].ObjectID=0 then Voxel_CreateBlocks(World.Chunk[ChunkX,ChunkZ],ChunkX,ChunkZ)
						endif
					endif
				next ChunkZ
			next ChunkX
		next Dist
		
		//>--- unkomment this to unload chunks outside of the view range ----<
		
//~		MinX=Core_Clamp(Voxel_CameraChunkX-ViewDistance-1,0,Voxel_ChunkMax.X)
//~		MinZ=Core_Clamp(Voxel_CameraChunkZ-ViewDistance-1,0,Voxel_ChunkMax.Z)
//~		MaxX=Core_Clamp(Voxel_CameraChunkX+ViewDistance+1,0,Voxel_ChunkMax.X)
//~		MaxZ=Core_Clamp(Voxel_CameraChunkZ+ViewDistance+1,0,Voxel_ChunkMax.Z)
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
				Voxel_UpdateChunkSunLight(World,ChunkX,ChunkZ,15)
				Voxel_CreateChunk(Faceimages,World,ChunkX,ChunkZ)
			else
				Voxel_UpdateChunkSunLight(World,ChunkX,ChunkZ,15)
				Voxel_UpdateChunk(Faceimages,World,ChunkX,ChunkZ)
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

function Voxel_CreateChunk(FaceImages ref as FaceimageData,World ref as WorldData,ChunkX,ChunkZ)	
	StartTime#=Timer()
	
	Voxel_TempChunk=World.Chunk[ChunkX,ChunkZ]
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			for LocalY=0 to Voxel_TempChunk.Height[LocalX,LocalZ]
				GlobalX=ChunkX*Voxel_ChunkSize+LocalX
				GlobalZ=ChunkZ*Voxel_ChunkSize+LocalZ
				Voxel_GenerateCubeFaces(Voxel_TempObject,Faceimages,World,GlobalX,LocalY,GlobalZ)
			next LocalY
		next LocalZ
	next LocalX
	Voxel_DebugTime#=Timer()-StartTime#
	
	if Voxel_TempObject.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Voxel_TempObject.Vertex.length+1,Voxel_TempObject.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Voxel_TempObject)		
		ObjectID=CreateObjectFromMeshMemblock(MemblockID)
		DeleteMemblock(MemblockID)
		Voxel_TempObject.Index.length=-1
		Voxel_TempObject.Vertex.length=-1
		
		SetObjectPosition(ObjectID,ChunkX*Voxel_ChunkSize,0,ChunkZ*Voxel_ChunkSize)
		SetObjectImage(ObjectID,Voxel_DiffuseImageID,0)
		SetObjectShader(ObjectID,Voxel_ShaderID)
		World.Chunk[ChunkX,ChunkZ].ObjectID=ObjectID
		World.Chunk[ChunkX,ChunkZ].Visible=1
	endif
	Voxel_DebugMeshBuildingTime#=Timer()-StartTime#
endfunction ObjectID

function Voxel_UpdateChunk(Faceimages ref as FaceimageData,World ref as WorldData,ChunkX,ChunkZ)
	StartTime#=Timer()
	Voxel_TempChunk=World.Chunk[ChunkX,ChunkZ]
	local Object as ObjectData
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			for LocalY=0 to Voxel_TempChunk.Height[LocalX,LocalZ]
				GlobalX=ChunkX*Voxel_ChunkSize+LocalX
				GlobalZ=ChunkZ*Voxel_ChunkSize+LocalZ
				Voxel_GenerateCubeFaces(Object,Faceimages,World,GlobalX,LocalY,GlobalZ)
			next LocalY
		next LocalZ
	next LocalX
	Voxel_DebugTime#=Timer()-StartTime#
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)
		SetObjectMeshFromMemblock(World.Chunk[ChunkX,ChunkZ].ObjectID,1,MemblockID)
		DeleteMemblock(MemblockID)
		Object.Index.length=-1
		Object.Vertex.length=-1
	endif
	Voxel_DebugMeshBuildingTime#=Timer()-StartTime#
endfunction

function Voxel_CreateBlocks(Chunk ref as Chunkdata,ChunkX,ChunkZ)	
	Frecueny2D#=32.0
	Frecueny3DCave#=12.0
	Frecueny3DIron#=2.0
	DirtLayerHeight=3
	GrassStart=Voxel_BlockMax.Y*0.4
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			NoiseX=ChunkX*Voxel_ChunkSize+LocalX
			NoiseZ=ChunkZ*Voxel_ChunkSize+LocalZ
			
			Value1#=GetNoiseXY(NoiseX/Frecueny2D#,NoiseZ/Frecueny2D#)*Voxel_BlockMax.Y
			GrassLayer=GrassStart+Value1#/12.0
			Chunk.Height[LocalX,LocalZ]=GrassLayer
			
			for LocalY=GrassLayer to 0 step -1
				if LocalY=GrassLayer
					Chunk.BlockType[LocalX,LocalY,LocalZ]=1
				elseif LocalY>=GrassLayer-DirtLayerHeight and LocalY<GrassLayer
					Chunk.BlockType[LocalX,LocalY,LocalZ]=3
				elseif LocalY<GrassLayer-DirtLayerHeight
					Chunk.BlockType[LocalX,LocalY,LocalZ]=2
				endif
				
				Cave#=GetNoiseXYZ(NoiseX/Frecueny3DCave#,LocalY/Frecueny3DCave#,NoiseZ/Frecueny3DCave#)
				if Cave#>0.5
					Chunk.BlockType[LocalX,LocalY,LocalZ]=0
					if LocalY=Chunk.Height[LocalX,LocalZ] then Chunk.Height[LocalX,LocalZ]=LocalY-1
				endif
				
				Chunk.SunLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
				Chunk.BlockLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
//~				if LocalY>Chunk.Height[LocalX,LocalZ]
//~					Chunk.SunLight[LocalX,LocalY,LocalZ]=15
//~				endif
			next LocalY
		next LocalZ
	next LocalX
endfunction

function Voxel_CreateBlockLight(World ref as WorldData,ChunkX,ChunkZ,LocalX,LocalY,LocalZ)	
	LightIntensitiy=Voxel_IsLightBlock(World.Chunk[ChunkX,ChunkZ],LocalX,LocalY,LocalZ)
	if LightIntensitiy>Voxel_AmbientLight
		Voxel_UpdateBlockLight(World,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,LightIntensitiy)
	endif
endfunction

function Voxel_UpdateBlockLight(World ref as WorldData,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,StartBlockLight as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]

	FrontierTemp.X=ChunkX*Voxel_ChunkSize+LocalX
	FrontierTemp.Y=LocalY
	FrontierTemp.Z=ChunkZ*Voxel_ChunkSize+LocalZ
	Frontier.insert(FrontierTemp)
	
	World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,LocalY,LocalZ]=StartBlockLight
	
	while Frontier.length>=0
		GlobalX=Frontier[0].X
		GlobalY=Frontier[0].Y
		GlobalZ=Frontier[0].Z
		Frontier.remove(0)
		
		for NeighbourID=0 to 5
			NeighbourX=GlobalX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=GlobalY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=GlobalZ+Voxel_Neighbors[NeighbourID].Z
			NeighbourLocalX=Mod(NeighbourX,Voxel_ChunkSize)
			NeighbourLocalZ=Mod(NeighbourZ,Voxel_ChunkSize)
			if NeighbourLocalX<0 or NeighbourY<0 or NeighbourLocalZ<0 then continue
			NeighbourChunkX=trunc(NeighbourX/Voxel_ChunkSize)
			NeighbourChunkZ=trunc(NeighbourZ/Voxel_ChunkSize)
			
			if Voxel_IsTransparentBlock(World.Chunk[NeighbourChunkX,NeighbourChunkZ],NeighbourLocalX,NeighbourY,NeighbourLocalZ)=1
				NeighbourBlockLight=World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]
				CurrentBlockLight=Voxel_GetBlockLight(World,GlobalX,GlobalY,GlobalZ)
				if CurrentBlockLight>NeighbourBlockLight+1
					FrontierTemp.X=NeighbourX
					FrontierTemp.Y=NeighbourY
					FrontierTemp.Z=NeighbourZ
					Frontier.insert(FrontierTemp)
					World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]=CurrentBlockLight-1
					
					Voxel_AddChunktoLoadList(NeighbourChunkX,NeighbourChunkZ)
				endif
			endif
		next NeighbourID
	endwhile
endfunction

function Voxel_UpdateBlockShadow(World ref as WorldData,ChunkX,ChunkZ,LocalX,LocalY,LocalZ)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]
	local TempChunk as ChunkData
	local TempSpreadLight as SpreadLightData

	FrontierTemp.X=ChunkX*Voxel_ChunkSize+LocalX
	FrontierTemp.Y=LocalY
	FrontierTemp.Z=ChunkZ*Voxel_ChunkSize+LocalZ
	Frontier.insert(FrontierTemp)
	
	while Frontier.length>=0
		GlobalX=Frontier[0].X
		GlobalY=Frontier[0].Y
		GlobalZ=Frontier[0].Z
		Frontier.remove(0)
		
		LocalX=Mod(GlobalX,Voxel_ChunkSize)
		LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
		if LocalX<0 or GlobalY<0 or LocalZ<0 then continue
		ChunkX=trunc(GlobalX/Voxel_ChunkSize)
		ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
		CurrentBlockLight=World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]
		
		if CurrentBlockLight<>Voxel_AmbientLight
			for NeighbourID=0 to 5
				NeighbourX=GlobalX+Voxel_Neighbors[NeighbourID].X
				NeighbourY=GlobalY+Voxel_Neighbors[NeighbourID].Y
				NeighbourZ=GlobalZ+Voxel_Neighbors[NeighbourID].Z
				NeighbourLocalX=Mod(NeighbourX,Voxel_ChunkSize)
				NeighbourLocalZ=Mod(NeighbourZ,Voxel_ChunkSize)
				if NeighbourLocalX<0 or NeighbourY<0 or NeighbourLocalZ<0 then continue
				NeighbourChunkX=trunc(NeighbourX/Voxel_ChunkSize)
				NeighbourChunkZ=trunc(NeighbourZ/Voxel_ChunkSize)
				TempChunk=World.Chunk[NeighbourChunkX,NeighbourChunkZ]
				if Voxel_IsTransparentBlock(TempChunk,NeighbourLocalX,NeighbourY,NeighbourLocalZ)=1
					NeighbourBlockLight=TempChunk.BlockLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]
					if CurrentBlockLight>NeighbourBlockLight
						FrontierTemp.X=NeighbourX
						FrontierTemp.Y=NeighbourY
						FrontierTemp.Z=NeighbourZ
						Frontier.insert(FrontierTemp)
						
						World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]=Voxel_AmbientLight
						
						Voxel_AddChunktoLoadList(NeighbourChunkX,NeighbourChunkZ)
					else
						TempSpreadLight.X=NeighbourX
						TempSpreadLight.Y=NeighbourY
						TempSpreadLight.Z=NeighbourZ
						TempSpreadLight.Light=NeighbourBlockLight
						Voxel_SpreadLight.insert(TempSpreadLight)
					endif
				endif
			next NeighbourID
		endif
	endwhile

	for ID=0 to Voxel_SpreadLight.length
		GlobalX=Voxel_SpreadLight[ID].X
		GlobalY=Voxel_SpreadLight[ID].Y
		GlobalZ=Voxel_SpreadLight[ID].Z
		Light=Voxel_SpreadLight[ID].Light
		
		ChunkX=trunc(GlobalX/Voxel_ChunkSize)
		ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
		LocalX=Mod(GlobalX,Voxel_ChunkSize)
		LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
//~		Voxel_UpdateBlockLight(World,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,Light)
	next ID
	Voxel_SpreadLight.length=-1
endfunction

//~function Voxel_UpdateSunLight(World ref as WorldData,StartX,StartY,StartZ,StartSunLight as integer)
//~	local FrontierTemp as Int3Data
//~	local Frontier as Int3Data[]

//~	FrontierTemp.X=StartX
//~	FrontierTemp.Y=StartY
//~	FrontierTemp.Z=StartZ
//~	Frontier.insert(FrontierTemp)
//~	
//~	World.Terrain[StartX,StartY,StartZ].SunLight=StartSunLight
//~	
//~	while Frontier.length>=0
//~		LocalX=Frontier[0].X
//~		LocalY=Frontier[0].Y
//~		LocalZ=Frontier[0].Z
//~		Frontier.remove(0)
//~		
//~		for NeighbourID=0 to 5
//~			NeighbourX=LocalX+Voxel_Neighbors[NeighbourID].X
//~			NeighbourY=LocalY+Voxel_Neighbors[NeighbourID].Y
//~			NeighbourZ=LocalZ+Voxel_Neighbors[NeighbourID].Z
//~			if NeighbourY<=Voxel_BlockMax.Y[NeighbourX,NeighbourZ]
//~				if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
//~					if World.Terrain[LocalX,LocalY,LocalZ].SunLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight+1
//~						FrontierTemp.X=NeighbourX
//~						FrontierTemp.Y=NeighbourY
//~						FrontierTemp.Z=NeighbourZ
//~						Frontier.insert(FrontierTemp)
//~						World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight=World.Terrain[LocalX,LocalY,LocalZ].SunLight-1
//~						
//~						ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
//~						ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
//~						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
//~					endif
//~				endif
//~			endif
//~		next NeighbourID
//~	endwhile
//~endfunction

function Voxel_UpdateChunkSunLight(World ref as WorldData,ChunkX,ChunkZ,StartSunLight as integer)
	local FrontierTemp as Int3Data
	local Frontier as Int3Data[]

	benchmark# = GetMilliseconds()
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			HeightNorth=World.Chunk[ChunkX,ChunkZ].Height[LocalX,trunc(Core_Clamp(LocalZ+1,0,Voxel_ChunkSize-1))]
			HeightSouth=World.Chunk[ChunkX,ChunkZ].Height[LocalX,trunc(Core_Clamp(LocalZ-1,0,Voxel_ChunkSize-1))]
			HeightEast=World.Chunk[ChunkX,ChunkZ].Height[trunc(Core_Clamp(LocalX+1,0,Voxel_ChunkSize-1)),LocalZ]
			HeightWest=World.Chunk[ChunkX,ChunkZ].Height[trunc(Core_Clamp(LocalX-1,0,Voxel_ChunkSize-1)),LocalZ]
			HeightCurrent=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
			
			LocalY=Core_Max(HeightNorth,Core_Max(HeightSouth,Core_Max(HeightEast,Core_Max(HeightWest,HeightCurrent))))+1
			HeightY=Voxel_BlockMax.Y
			
			while HeightY>LocalY
				World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,HeightY,LocalZ]=StartSunLight
				dec HeightY
			endwhile
			
			LocalY=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]+1
			FrontierTemp.X=ChunkX*Voxel_ChunkSize+LocalX
			FrontierTemp.Y=LocalY
			FrontierTemp.Z=ChunkZ*Voxel_ChunkSize+LocalZ
			Frontier.insert(FrontierTemp)
			
			World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,LocalY,LocalZ]=StartSunLight
			
		next LocalZ
	next LocalX
	
	print("1: "+str(GetMilliseconds()-benchmark#))
	benchmark# = GetMilliseconds()
	print("Frontier length: "+str(Frontier.length))
	iterations# = 0
	
	while Frontier.length>=0
		inc iterations#
		GlobalX=Frontier[0].X
		GlobalY=Frontier[0].Y
		GlobalZ=Frontier[0].Z
		Frontier.remove(0)
		
		for NeighbourID=0 to 5
			NeighbourX=GlobalX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=GlobalY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=GlobalZ+Voxel_Neighbors[NeighbourID].Z
			NeighbourLocalX=Mod(NeighbourX,Voxel_ChunkSize)
			NeighbourLocalZ=Mod(NeighbourZ,Voxel_ChunkSize)
			if NeighbourLocalX<0 or NeighbourY<0 or NeighbourLocalZ<0 then continue
			NeighbourChunkX=trunc(NeighbourX/Voxel_ChunkSize)
			NeighbourChunkZ=trunc(NeighbourZ/Voxel_ChunkSize)
			
			if Voxel_IsTransparentBlock(World.Chunk[NeighbourChunkX,NeighbourChunkZ],NeighbourLocalX,NeighbourY,NeighbourLocalZ)=1
				NeighbourSunLight=World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]
				
				CurrentSunLight=Voxel_GetSunLight(World,GlobalX,GlobalY,GlobalZ)
				if CurrentSunLight>NeighbourSunLight+1
					FrontierTemp.X=NeighbourX
					FrontierTemp.Y=NeighbourY
					FrontierTemp.Z=NeighbourZ
					
//~					if NeighbourLocalX>0 and NeighbourLocalZ>0 and NeighbourLocalX<Voxel_ChunkSize-1 and NeighbourLocalZ<Voxel_ChunkSize-1
						Frontier.insert(FrontierTemp)
//~					endif
					
					if NeighbourID=1 and CurrentSunLight=15
						World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]=CurrentSunLight
					else
						World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]=CurrentSunLight-1
					endif

					Voxel_AddChunktoLoadList(NeighbourChunkX,NeighbourChunkZ)
				endif
			endif
		next NeighbourID
	endwhile
	
	print("2: "+str(GetMilliseconds()-benchmark#))
	benchmark# = GetMilliseconds()
	print("total iterations: "+str(iterations#))
endfunction

//~function Voxel_UpdateSunShadow(World ref as WorldData,StartX,StartY,StartZ)
//~	local FrontierTemp as Int3Data
//~	local Frontier as Int3Data[]
//~	local TempSunLight as integer
//~	local TempSpreadLight as SpreadLightData

//~	FrontierTemp.X=StartX
//~	FrontierTemp.Y=StartY
//~	FrontierTemp.Z=StartZ
//~	Frontier.insert(FrontierTemp)
//~	
//~	while Frontier.length>=0
//~		LocalX=Frontier[0].X
//~		LocalY=Frontier[0].Y
//~		LocalZ=Frontier[0].Z
//~		Frontier.remove(0)
//~		TempSunLight=World.Terrain[LocalX,LocalY,LocalZ].SunLight
//~		if TempSunLight<>Voxel_AmbientLight
//~			for NeighbourID=0 to 5
//~				NeighbourX=LocalX+Voxel_Neighbors[NeighbourID].X
//~				NeighbourY=LocalY+Voxel_Neighbors[NeighbourID].Y
//~				NeighbourZ=LocalZ+Voxel_Neighbors[NeighbourID].Z
//~				if Voxel_IsTransparentBlock(World,NeighbourX,NeighbourY,NeighbourZ)=1
//~					if TempSunLight>World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight
//~						FrontierTemp.X=NeighbourX
//~						FrontierTemp.Y=NeighbourY
//~						FrontierTemp.Z=NeighbourZ
//~						Frontier.insert(FrontierTemp)
//~						
//~						World.Terrain[LocalX,LocalY,LocalZ].SunLight=Voxel_AmbientLight
//~						
//~						ChunkX=trunc((NeighbourX-1)/Voxel_ChunkSize)
//~						ChunkZ=trunc((NeighbourZ-1)/Voxel_ChunkSize)
//~						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
//~					else
//~						TempSpreadLight.X=NeighbourX
//~						TempSpreadLight.Y=NeighbourY
//~						TempSpreadLight.Z=NeighbourZ
//~						TempSpreadLight.Light=World.Terrain[NeighbourX,NeighbourY,NeighbourZ].SunLight
//~						Voxel_SpreadLight.insert(TempSpreadLight)
//~					endif
//~				endif
//~			next NeighbourID
//~		endif
//~	endwhile

//~	for ID=0 to Voxel_SpreadLight.length-1
//~		LocalX=Voxel_SpreadLight[ID].X
//~		LocalY=Voxel_SpreadLight[ID].Y
//~		LocalZ=Voxel_SpreadLight[ID].Z
//~		Light=Voxel_SpreadLight[ID].Light
//~		Voxel_UpdateBlockLight(World,LocalX,LocalY,LocalZ,Light)
//~	next ID
//~	Voxel_SpreadLight.length=-1
//~endfunction

function Voxel_UpdateHeightAndSunlight(Chunk ref as ChunkData,LocalX,LocalY,LocalZ,LightValue)
	repeat
//~		Chunk.SunLight[LocalX,LocalY,LocalZ]=LightValue
		LocalY=LocalY-1
		if LocalY<=1 then Exitfunction
	until Voxel_IsTransparentBlock(Chunk,LocalX,LocalY,LocalZ)=0
	Chunk.Height[LocalX,LocalZ]=LocalY
//~	if LightValue>Voxel_AmbientLight
//~		Voxel_UpdateSunLight(World,LocalX,LocalY,LocalZ,LightValue)
//~	else
//~		Voxel_UpdateSunShadow(World,LocalX,LocalY,LocalZ)
//~	endif
endfunction

function Voxel_IsLightBlock(Chunk ref as ChunkData,LocalX,LocalY,LocalZ)
	select Chunk.BlockType[LocalX,LocalY,LocalZ]
		case 11
			exitfunction 14
		endcase
	endselect
endfunction 0

function Voxel_IsTransparentBlock(Chunk ref as ChunkData,LocalX,LocalY,LocalZ)
	select Chunk.BlockType[LocalX,LocalY,LocalZ]
		case 0
			exitfunction 1
		endcase
	endselect
endfunction 0

function Voxel_AddNeighbouringChunkstoList(ChunkX,ChunkZ,LocalX,LocalZ)
	if LocalX=Voxel_ChunkSize-1
		if ChunkX+1<=Voxel_ChunkMax.X then Voxel_AddChunktoLoadList(ChunkX+1,ChunkZ)
	endif
	if LocalX=0
		if ChunkX-1>=0 then Voxel_AddChunktoLoadList(ChunkX-1,ChunkZ)
	endif
	if LocalZ=Voxel_ChunkSize-1
		if ChunkZ+1<=Voxel_ChunkMax.Z then Voxel_AddChunktoLoadList(ChunkX,ChunkZ+1)
	endif
	if LocalZ=0
		if ChunkZ-1>=0 then Voxel_AddChunktoLoadList(ChunkX,ChunkZ-1)
	endif
endfunction

function Voxel_AddCubeToObject(World ref as WorldData,GlobalX,GlobalY,GlobalZ,BlockType)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	
	if GlobalY>World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
		Voxel_UpdateHeightAndSunlight(World.Chunk[ChunkX,ChunkZ],LocalX,GlobalY,LocalZ,Voxel_AmbientLight)
		World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]=GlobalY
	endif
	
	World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]=BlockType
//~	World.Terrain[X,Y,Z].BlockLight=Voxel_AmbientLight
//~	World.Terrain[X,Y,Z].SunLight=Voxel_AmbientLight

	Voxel_CreateBlockLight(World,ChunkX,ChunkZ,LocalX,GlobalY,LocalZ)
	
	Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	Voxel_AddNeighbouringChunkstoList(ChunkX,ChunkZ,LocalX,LocalZ)
endfunction

function Voxel_RemoveCubeFromObject(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	
	if GlobalY=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
		Voxel_UpdateHeightAndSunlight(World.Chunk[ChunkX,ChunkZ],LocalX,GlobalY,LocalZ,15)
	elseif GlobalY<World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
		TempHeight=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
		Voxel_UpdateHeightAndSunlight(World.Chunk[ChunkX,ChunkZ],LocalX,GlobalY,LocalZ,Voxel_AmbientLight)
		World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]=TempHeight
	endif
	BlockType=World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]
	World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]=0
	
	Voxel_UpdateBlockShadow(World,ChunkX,ChunkZ,LocalX,GlobalY,LocalZ)

	Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	Voxel_AddNeighbouringChunkstoList(ChunkX,ChunkZ,LocalX,LocalZ)
endfunction BlockType

function Voxel_RemoveCubeListFromObject(World ref as WorldData,CubeList as Int3Data[])
	local TempLocal as Int3Data
	
	for Index=0 to CubeList.length
		GlobalX=CubeList[Index].X
		GlobalY=CubeList[Index].Y
		GlobalZ=CubeList[Index].Z
		ChunkX=trunc(GlobalX/Voxel_ChunkSize)
		ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
		LocalX=Mod(GlobalX,Voxel_ChunkSize)
		LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
		
		if GlobalY=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
			Voxel_UpdateHeightAndSunlight(World.Chunk[ChunkX,ChunkZ],LocalX,GlobalY,LocalZ,15)
		elseif GlobalY<World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
			TempHeight=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
			Voxel_UpdateHeightAndSunlight(World.Chunk[ChunkX,ChunkZ],LocalX,GlobalY,LocalZ,Voxel_AmbientLight)
			World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]=TempHeight
		endif
		World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]=0
	
		Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
		Voxel_AddNeighbouringChunkstoList(ChunkX,ChunkZ,LocalX,LocalZ)
	next Index
endfunction

function Voxel_GenerateCubeFaces(Object ref as ObjectData,Faceimages ref as FaceimageData,World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
	
	BlockType=World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]
	if BlockType>0
		Index=BlockType-1
		Voxel_TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		Voxel_TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		Voxel_TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		Voxel_TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		Voxel_TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		Voxel_TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]
		
		Flipped=0
		local LightValue as integer
		if Voxel_GetBlockType(World,GlobalX,GlobalY,GlobalZ+1)=0
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY+1,GlobalZ+1)=0)
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY-1,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,GlobalY,GlobalZ+1),Voxel_GetSunLight(World,GlobalX,GlobalY,GlobalZ+1))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[0],LocalX,GlobalY,LocalZ,FaceFront,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,GlobalX,GlobalY,GlobalZ-1)=0
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY+1,GlobalZ-1)=0)
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY-1,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,GlobalY,GlobalZ-1),Voxel_GetSunLight(World,GlobalX,GlobalY,GlobalZ-1))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[1],LocalX,GlobalY,LocalZ,FaceBack,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ)=0
			side1=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ)=0)
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ-1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ+1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX+1,GlobalY,GlobalZ),Voxel_GetSunLight(World,GlobalX+1,GlobalY,GlobalZ))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[2],LocalX,GlobalY,LocalZ,FaceRight,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ)=0
			side1=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ)=0)
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ-1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ+1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ+1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX-1,GlobalY,GlobalZ),Voxel_GetSunLight(World,GlobalX-1,GlobalY,GlobalZ))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[3],LocalX,GlobalY,LocalZ,FaceLeft,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,GlobalX,GlobalY+1,GlobalZ)=0
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY+1,GlobalZ+1)=0)
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY+1,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY+1,GlobalZ-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY+1,GlobalZ-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,GlobalY+1,GlobalZ),Voxel_GetSunLight(World,GlobalX,GlobalY+1,GlobalZ))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[4],LocalX,GlobalY,LocalZ,FaceUp,AO0,AO1,AO2,AO3,Flipped)
		endif
		if Voxel_GetBlockType(World,GlobalX,GlobalY-1,GlobalZ)=0
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY-1,GlobalZ+1)=0)
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ+1)=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ+1)=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)
			
			side1=(Voxel_GetBlockType(World,GlobalX,GlobalY-1,GlobalZ-1)=0)
			corner=(Voxel_GetBlockType(World,GlobalX+1,GlobalY-1,GlobalZ-1)=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)
			
			side2=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ)=0)
			corner=(Voxel_GetBlockType(World,GlobalX-1,GlobalY-1,GlobalZ-1)=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)
			
			if AO0+AO2>AO1+AO3 then Flipped=1
			
			LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,GlobalY-1,GlobalZ),Voxel_GetSunLight(World,GlobalX,GlobalY-1,GlobalZ))/15.0*255
			AO0=LightValue-AO0
			AO1=LightValue-AO1
			AO2=LightValue-AO2
			AO3=LightValue-AO3
			
			Voxel_AddFaceToObject(Object,Voxel_TempSubimages[5],LocalX,GlobalY,LocalZ,FaceDown,AO0,AO1,AO2,AO3,Flipped)
		endif
	endif
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
endfunction (3 - (side1 + side2 + corner))/3.0*255

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