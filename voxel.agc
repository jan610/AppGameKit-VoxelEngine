//~#import_plugin OpenSimplexNoise as Noise
//~#include "threadnoise.agc"

#constant FaceFront	1
#constant FaceBack	2
#constant FaceLeft	3
#constant FaceRight	4
#constant FaceUp		5
#constant FaceDown	6

// Data Types able to represent any AGK mesh
type VertexData
	Pos as Core_Vec3Data
	UV as Core_Vec2Data
	Color as Core_ColorData
	Normal as Core_Vec3Data
	Tangent as Core_Vec3Data
	Binormal as Core_Vec3Data
endtype

type MeshData
	Vertex as VertexData[]
	Index as integer[]
endtype

type SubimageData
	Path as string
	X as integer
	Y as integer
	Width as integer
	Height as integer
endtype
	
type BlockAttributeData
	Name$ as string
	Solid as integer
	Light as integer
	Opaque as integer
	JoinFace as integer
	FrontID as integer
	BackID as integer
	UpID as integer
	DownID as integer
	LeftID as integer
	RightID as integer
	FrontOffset# as float
	BackOffset# as float
	UpOffset# as float
	DownOffset# as float
	LeftOffset# as float
	RightOffset# as float
endtype

type BlockData
	Subimages as SubimageData[]
	Attributes as BlockAttributeData[]
endtype

type WorldData
	Chunk as ChunkData[-1,-1]
endtype

type ChunkData
	SolidObjectID as integer
	LooseObjectID as integer
	Visited as integer
	Height as integer[-1,-1]
	BlockType as integer[-1,-1,-1]
	BlockLight as integer[-1,-1,-1]
	SunLight as integer[-1,-1,-1]
	BlockFrontier as FrontierData[]
	SunFrontier as FrontierData[]
endtype

type BorderData
	Min as Core_Int2XZData
	Max as Core_Int2XZData
endtype

type FrontierData
	Dir as integer
	X as integer
	Y as integer
	Z as integer
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

global Voxel_Neighbors as Core_Int3Data[5]
global Voxel_LoadChunkList as ChunkListData[]
global Voxel_UnloadChunkList as ChunkListData[]
global Voxel_TempSubimages as SubimageData[5]
global Voxel_TempOffset as float[5]
global Voxel_SpreadLight as SpreadLightData[]
global Voxel_TempChunkList as ChunkListData
global Voxel_TempChunk as ChunkData
global Voxel_TempSolidMesh as MeshData
global Voxel_TempLooseMesh as MeshData
global Voxel_TempInt3 as Core_Int3Data
global Voxel_ChunkView as BorderData
global Voxel_ChunkMax as Core_Int2XZData
global Voxel_BlockMax as Core_Int3Data
global Voxel_TempVertex as VertexData[3]
global Voxel_Blocks as BlockData

global Voxel_AmbientLight as integer
global Voxel_ChunkSize as integer
global Voxel_DiffuseImageID as integer
global Voxel_NormalImageID as integer
global Voxel_OpaqueShaderID as integer
global Voxel_WaterShaderID as integer
global Voxel_TempID as integer
global Voxel_UpdateTimer# as float
global Voxel_ViewDistance as integer
global Voxel_CameraChunkOldX as integer
global Voxel_CameraChunkOldZ as integer
global Voxel_WorldName$ as string
global Voxel_Frecueny2D# as float
global Voxel_Frecueny3DCave# as float
global Voxel_Frecueny3DIron# as float
global Voxel_GrassHeight as integer
global Voxel_DirtHeight as integer
global Voxel_SeaHeight as integer
		
global Voxel_DebugMeshTime# as float
global Voxel_DebugChunkTime# as float
global Voxel_DebugSaveTime# as float
global Voxel_DebugLoadTime# as float
global Voxel_DebugTime# as float
global Voxel_DebugNoiseTime# as float
global Voxel_DebugSunTime# as float
global Voxel_DebugIterations as integer

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData,ChunkSize,SizeX,SizeY,SizeZ,File$,WorldName$,ViewDistance)
	Voxel_DiffuseImageID=LoadImage(File$)
//~	Voxel_NormalImageID=LoadImage(StringInsertAtDelemiter(File$,"_n.","."))
	
	Voxel_OpaqueShaderID=LoadShader("shader/opaque.vs","shader/opaque.ps")
	Voxel_WaterShaderID=LoadShader("shader/water.vs","shader/water.ps")
	SetShaderConstantByName(Voxel_WaterShaderID,"waveFrequency",2.0,2.2,0,0)
	SetShaderConstantByName(Voxel_WaterShaderID,"waveAmplitude",0.05,0,0,0)
	SetShaderConstantByName(Voxel_WaterShaderID,"waveOffset",0.0,0.0,0,0)
	
	Voxel_WorldName$=WorldName$
	Voxel_AmbientLight=2
	Voxel_ViewDistance=ViewDistance
	Voxel_ChunkSize=ChunkSize
	Voxel_ChunkMax.X=trunc(SizeX/Voxel_ChunkSize)
	Voxel_ChunkMax.Z=trunc(SizeZ/Voxel_ChunkSize)
	
	Voxel_BlockMax.X=SizeX
	Voxel_BlockMax.Y=SizeY
	Voxel_BlockMax.Z=SizeZ
	
	Voxel_Frecueny2D#=32.0
	Voxel_Frecueny3DCave#=22.0
	Voxel_Frecueny3DIron#=2.0
	Voxel_GrassHeight=SizeY*0.5
	Voxel_SeaHeight=Voxel_GrassHeight-2
	
	World.Chunk.length=Voxel_ChunkMax.X
	for ChunkX=0 to Voxel_ChunkMax.X
		World.Chunk[ChunkX].length=Voxel_ChunkMax.Z
		for ChunkZ=0 to Voxel_ChunkMax.Z
			World.Chunk[ChunkX,ChunkZ].Height.length=Voxel_ChunkSize-1
			World.Chunk[ChunkX,ChunkZ].BlockType.length=Voxel_ChunkSize-1
			World.Chunk[ChunkX,ChunkZ].BlockLight.length=Voxel_ChunkSize-1
			World.Chunk[ChunkX,ChunkZ].SunLight.length=Voxel_ChunkSize-1
			for X=0 to Voxel_ChunkSize-1
				World.Chunk[ChunkX,ChunkZ].Height[X].length=Voxel_ChunkSize-1
				World.Chunk[ChunkX,ChunkZ].BlockType[X].length=SizeY
				World.Chunk[ChunkX,ChunkZ].BlockLight[X].length=SizeY
				World.Chunk[ChunkX,ChunkZ].SunLight[X].length=SizeY
				for Y=0 to SizeY
					World.Chunk[ChunkX,ChunkZ].BlockType[X,Y].length=Voxel_ChunkSize-1
					World.Chunk[ChunkX,ChunkZ].BlockLight[X,Y].length=Voxel_ChunkSize-1
					World.Chunk[ChunkX,ChunkZ].SunLight[X,Y].length=Voxel_ChunkSize-1
				next Y
			next X
		next ChunkZ
	next ChunkX
	
	Voxel_Neighbors[0].x=0
	Voxel_Neighbors[0].y=1
	Voxel_Neighbors[0].z=0
	
	Voxel_Neighbors[1].x=1
	Voxel_Neighbors[1].y=0
	Voxel_Neighbors[1].z=0
	
	Voxel_Neighbors[2].x=0
	Voxel_Neighbors[2].y=0
	Voxel_Neighbors[2].z=1
	
	Voxel_Neighbors[3].x=0
	Voxel_Neighbors[3].y=0
	Voxel_Neighbors[3].z=-1
	
	Voxel_Neighbors[4].x=-1
	Voxel_Neighbors[4].y=0
	Voxel_Neighbors[4].z=0
	
	Voxel_Neighbors[5].x=0
	Voxel_Neighbors[5].y=-1
	Voxel_Neighbors[5].z=0
endfunction

function Voxel_SetSpawn(SpawnX#,SpawnY#,SpawnZ#)
	SetCameraPosition(1,SpawnX#,SpawnY#,SpawnZ#)
	Voxel_CameraChunkX=trunc(SpawnX#)/Voxel_ChunkSize
	Voxel_CameraChunkZ=trunc(SpawnZ#)/Voxel_ChunkSize
//~	Voxel_CameraChunkOldX=Voxel_CameraChunkX
//~	Voxel_CameraChunkOldZ=Voxel_CameraChunkZ
endfunction

function Voxel_LoadBlockAttributes(FaceImagesFile$)
	local string$ as string
	string$ = Voxel_JSON_Load(FaceImagesFile$)
	Voxel_Blocks.fromJSON(string$)
endfunction

function Voxel_SaveBlockAttributes(FaceIMagesFile$)
	local string$ as string
	string$ = Voxel_Blocks.toJSON()
	Voxel_JSON_Save(string$ , FaceIMagesFile$)
endfunction

//~function Voxel_SaveChunk(Chunk ref as ChunkData,ChunkX,ChunkZ)
//~	StartTime#=Timer()
//~	local RunLength as integer
//~	local OldBlockType as integer
//~	OpenToWrite(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin",0) 
//~	for LocalX=0 to Voxel_ChunkSize-1
//~        for LocalZ=0 to Voxel_ChunkSize-1
//~            RunLength=1
//~            Height=Chunk.Height[LocalX,LocalZ]
//~            WriteByte(1,Height)
//~            OldBlockType=Chunk.BlockType[LocalX,1,LocalZ]
//~            for LocalY=2 to Height
//~            		BlockType=Chunk.BlockType[LocalX,LocalY,LocalZ]
//~                if BlockType<>OldBlockType
//~                    WriteByte(1,RunLength)
//~                    WriteByte(1,OldBlockType)
//~                    OldBlockType=BlockType
//~                    RunLength=0
//~                endif
//~                inc RunLength
//~            next LocalY
//~            WriteByte(1,RunLength)
//~            WriteByte(1,Chunk.BlockType[LocalX,LocalY,LocalZ])
//~        next LocalZ
//~	next LocalX
//~    CloseFile(1)
//~    Voxel_DebugSaveTime#=Timer()-StartTime#
//~endfunction

//~function Voxel_LoadChunk(Chunk ref as ChunkData,ChunkX,ChunkZ)
//~	StartTime#=Timer()
//~	local RunLength as integer
//~	local OldBlockType as integer
//~	OpenToRead(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin") 
//~	for LocalX=0 to Voxel_ChunkSize-1
//~        for LocalZ=0 to Voxel_ChunkSize-1
//~            Height=ReadByte(1)
//~            Chunk.Height[LocalX,LocalZ]=Height
//~            LocalY=1
//~            repeat
//~	    		RunLength=ReadByte(1)
//~	    		BlockType=ReadByte(1)
//~	    		repeat
//~	    			Chunk.BlockType[LocalX,LocalY,LocalZ]=BlockType
//~	    			inc LocalY
//~	    		until LocalY>=RunLength or LocalY>=Height
//~    		until LocalY>=Height
//~        next LocalZ
//~	next LocalX
//~    CloseFile(1)
//~    Voxel_DebugLoadTime#=Timer()-StartTime#
//~endfunction

function Voxel_SaveChunk(Chunk ref as ChunkData,ChunkX,ChunkZ)
	StartTime#=Timer()
	
	local RunLength as integer
	local OldBlockType as integer
	OpenToWrite(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin",0) 
	for LocalX=0 to Voxel_ChunkSize-1
        for LocalZ=0 to Voxel_ChunkSize-1
            Height=Chunk.Height[LocalX,LocalZ]
            WriteByte(1,Height)
            for LocalY=1 to Height
                 WriteByte(1,Chunk.BlockType[LocalX,LocalY,LocalZ])
//~                 WriteByte(1,Chunk.BlockLight[LocalX,LocalY,LocalZ])
//~                 WriteByte(1,Chunk.SunLight[LocalX,LocalY,LocalZ])
            next LocalY
        next LocalZ
	next LocalX
    CloseFile(1)
    
    Voxel_DebugSaveTime#=Timer()-StartTime#
endfunction

function Voxel_LoadChunk(Chunk ref as ChunkData,ChunkX,ChunkZ)
	StartTime#=Timer()
	
	local RunLength as integer
	local OldBlockType as integer
	OpenToRead(1,Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin") 
	for LocalX=0 to Voxel_ChunkSize-1
        for LocalZ=0 to Voxel_ChunkSize-1
            Height=ReadByte(1)
            for LocalY=1 to Height
				Chunk.BlockType[LocalX,LocalY,LocalZ]=ReadByte(1)
//~				Chunk.BlockLight[LocalX,LocalY,LocalZ]=ReadByte(1)
//~				Chunk.SunLight[LocalX,LocalY,LocalZ]=ReadByte(1)
				Chunk.BlockLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
				Chunk.SunLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
            next LocalY
            Chunk.Height[LocalX,LocalZ]=Height
        next LocalZ
	next LocalX
    CloseFile(1)
    
    Voxel_DebugLoadTime#=Timer()-StartTime#
endfunction

function Voxel_ChunkFileExists(ChunkX,ChunkZ)
	Result=GetFileExists(Voxel_WorldName$+"/Chunk_"+str(ChunkX)+"_"+str(ChunkZ)+".bin")
endfunction Result

function Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
	if ChunkX>Voxel_ChunkView.Min.X and ChunkX<Voxel_ChunkView.Max.X and ChunkZ>Voxel_ChunkView.Min.Z and ChunkZ<Voxel_ChunkView.Max.Z
		Voxel_TempChunkList.X=ChunkX
		Voxel_TempChunkList.Z=ChunkZ
		Voxel_TempChunkList.Hash=ChunkX+(ChunkZ*Voxel_ChunkMax.X)
		if Voxel_LoadChunkList.IndexOf(Voxel_TempChunkList.Hash)=-1 then Voxel_LoadChunkList.insert(Voxel_TempChunkList)
	endif
endfunction

function Voxel_AddChunktoUnloadList(ChunkX,ChunkZ)
	Voxel_TempChunkList.X=ChunkX
	Voxel_TempChunkList.Z=ChunkZ
	Voxel_TempChunkList.Hash=ChunkX+(ChunkZ*Voxel_ChunkMax.X)
	if Voxel_UnloadChunkList.IndexOf(Voxel_TempChunkList.Hash)=-1 then Voxel_UnloadChunkList.insert(Voxel_TempChunkList)
endfunction

function Voxel_GetHeight(World ref as WorldData,GlobalX,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	BlockType=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
endfunction BlockType

function Voxel_GetBlockType(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	BlockType=World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]
endfunction BlockType

function Voxel_SetBlockType(World ref as WorldData,GlobalX,GlobalY,GlobalZ,BlockType)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,GlobalY,LocalZ]=BlockType
endfunction

function Voxel_GetBlockLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	LightValue=World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]
endfunction LightValue

function Voxel_SetBlockLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ,LightValue)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	World.Chunk[ChunkX,ChunkZ].BlockLight[LocalX,GlobalY,LocalZ]=LightValue
endfunction

function Voxel_GetSunLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	LightValue=World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,GlobalY,LocalZ]
endfunction LightValue

function Voxel_SetSunLight(World ref as WorldData,GlobalX,GlobalY,GlobalZ,LightValue)
	ChunkX=trunc(GlobalX/Voxel_ChunkSize)
	ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
	LocalX=Mod(GlobalX,Voxel_ChunkSize)
	LocalX=Core_WrapInteger(GlobalX,Voxel_ChunkSize)
	LocalZ=Core_WrapInteger(GlobalZ,Voxel_ChunkSize)
	World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,GlobalY,LocalZ]=LightValue
endfunction

function Voxel_UpdateChunks(World ref as WorldData,CameraX,CameraZ)	
	Voxel_CameraChunkX=trunc(CameraX/Voxel_ChunkSize)
	Voxel_CameraChunkZ=trunc(CameraZ/Voxel_ChunkSize)
	
	if Voxel_CameraChunkX<>Voxel_CameraChunkOldX or Voxel_CameraChunkZ<>Voxel_CameraChunkOldZ
		CameraDirX=Voxel_CameraChunkX-Voxel_CameraChunkOldX
		CameraDirZ=Voxel_CameraChunkZ-Voxel_CameraChunkOldZ
		Voxel_CameraChunkOldX=Voxel_CameraChunkX
		Voxel_CameraChunkOldZ=Voxel_CameraChunkZ

		MinX=Core_Clamp(Voxel_CameraChunkX-Voxel_ViewDistance,0,Voxel_ChunkMax.X)
		MaxX=Core_Clamp(Voxel_CameraChunkX+Voxel_ViewDistance,0,Voxel_ChunkMax.X)
		MinZ=Core_Clamp(Voxel_CameraChunkZ-Voxel_ViewDistance,0,Voxel_ChunkMax.Z)
		MaxZ=Core_Clamp(Voxel_CameraChunkZ+Voxel_ViewDistance,0,Voxel_ChunkMax.Z)
		
		if CameraDirX = 1
		    for ChunkZ = MinZ to MaxZ
//~				for ChunkX = MaxX to MinX+1 step -1
//~				    World.Chunk[ChunkX-1, ChunkZ] = World.Chunk[ChunkX, ChunkZ]
//~				next ChunkX
		
		        if World.Chunk[MinX, ChunkZ].Visited = 1
		            Voxel_AddChunktoUnloadList(MinX, ChunkZ)
		            World.Chunk[MinX, ChunkZ].Visited = 0
		        endif
		    next ChunkZ
		elseif CameraDirX = -1
		    for ChunkZ = MinZ to MaxZ
//~		        for ChunkX = MinX to MaxX - 1
//~		            World.Chunk[ChunkX + 1, ChunkZ] = World.Chunk[ChunkX, ChunkZ]
//~		        next ChunkX
		
		        if World.Chunk[MaxX, ChunkZ].Visited = 1
		            Voxel_AddChunktoUnloadList(MaxX, ChunkZ)
		            World.Chunk[MaxX, ChunkZ].Visited = 0
		        endif
		    next ChunkZ
		endif
		
		if CameraDirZ = 1
		    for ChunkX = MinX to MaxX
//~		        for ChunkZ = MaxZ to MinZ+1 step -1
//~		            World.Chunk[ChunkX, ChunkZ - 1] = World.Chunk[ChunkX, ChunkZ]
//~		        next ChunkZ
		
		        if World.Chunk[ChunkX, MinZ].Visited = 1
		            Voxel_AddChunktoUnloadList(ChunkX, MinZ)
		            World.Chunk[ChunkX, MinZ].Visited = 0
		        endif
		    next ChunkX
		elseif CameraDirZ = -1
		    for ChunkX = MinX to MaxX
//~		        for ChunkZ = MinZ to MaxZ-1
//~		            World.Chunk[ChunkX, ChunkZ + 1] = World.Chunk[ChunkX, ChunkZ]
//~		        next ChunkZ
		
		        if World.Chunk[ChunkX, MaxZ].Visited = 1
		            Voxel_AddChunktoUnloadList(ChunkX, MaxZ)
		            World.Chunk[ChunkX, MaxZ].Visited = 0
		        endif
		    next ChunkX
		endif
	
		for Dist=0 to Voxel_ViewDistance
			Voxel_ChunkView.Min.X=Core_Clamp(Voxel_CameraChunkX-Dist,0,Voxel_ChunkMax.X)
			Voxel_ChunkView.Min.Z=Core_Clamp(Voxel_CameraChunkZ-Dist,0,Voxel_ChunkMax.Z)
			Voxel_ChunkView.Max.X=Core_Clamp(Voxel_CameraChunkX+Dist,0,Voxel_ChunkMax.X)
			Voxel_ChunkView.Max.Z=Core_Clamp(Voxel_CameraChunkZ+Dist,0,Voxel_ChunkMax.Z)
		
			for ChunkX=Voxel_ChunkView.Min.X to Voxel_ChunkView.Max.X
				for ChunkZ=Voxel_ChunkView.Min.Z to Voxel_ChunkView.Max.Z
					if World.Chunk[ChunkX,ChunkZ].SolidObjectID=0 and World.Chunk[ChunkX,ChunkZ].LooseObjectID=0
						Voxel_AddChunktoLoadList(ChunkX,ChunkZ)
						if World.Chunk[ChunkX,ChunkZ].Visited=0
							if Voxel_ChunkFileExists(ChunkX,ChunkZ)
								Voxel_LoadChunk(World.Chunk[ChunkX,ChunkZ],ChunkX,ChunkZ)
							else
								Voxel_GenerateChunk(World.Chunk[ChunkX,ChunkZ],ChunkX,ChunkZ)
							endif
							World.Chunk[ChunkX,ChunkZ].Visited=1
						endif
					endif
				next ChunkZ
			next ChunkX
		next Dist
	endif
	
	Timer#=Timer()
	if Timer#>Voxel_UpdateTimer#
		Voxel_UpdateTimer#=Timer#+0.1
		
		if Voxel_LoadChunkList.length>-1
			ChunkX=Voxel_LoadChunkList[0].X
			ChunkZ=Voxel_LoadChunkList[0].Z
			Voxel_UpdateChunkSunLight(World,ChunkX,ChunkZ,15)
			Voxel_UpdateChunk(World,ChunkX,ChunkZ)
			Voxel_LoadChunkList.remove(0)
		endif
		
		if Voxel_UnloadChunkList.length>-1
			ChunkX=Voxel_UnloadChunkList[0].X
			ChunkZ=Voxel_UnloadChunkList[0].Z
			Voxel_SaveChunk(World.Chunk[ChunkX,ChunkZ],ChunkX,ChunkZ)
			Voxel_DeleteObject(World.Chunk[ChunkX,ChunkZ])
			Voxel_UnloadChunkList.remove(0)
		endif
	endif
endfunction

function Voxel_DeleteObject(Chunk ref as ChunkData)	
	DeleteObject(Chunk.SolidObjectID)
	DeleteObject(Chunk.LooseObjectID)
	Chunk.SolidObjectID=0
	Chunk.LooseObjectID=0
endfunction

function Voxel_GenerateChunk(Chunk ref as Chunkdata,ChunkX,ChunkZ)	
	StartTime#=Timer()
	
	local BlockType as integer
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			NoiseX=ChunkX*Voxel_ChunkSize+LocalX
			NoiseZ=ChunkZ*Voxel_ChunkSize+LocalZ
			
			Value1#=GetNoiseXY(NoiseX/Voxel_Frecueny2D#,NoiseZ/Voxel_Frecueny2D#)*Voxel_BlockMax.Y*0.5+0.5
			Value2#=GetNoiseXY(NoiseX/(Voxel_Frecueny2D#*2.0),NoiseZ/(Voxel_Frecueny2D#*2.0))*Voxel_BlockMax.Y*0.5+0.5
			GrassLayer=Voxel_GrassHeight+(Value1#+Value2#)/6.0
			DirtHeight=GrassLayer-3
			SeaHeight=Voxel_SeaHeight
			SandHeight=SeaHeight
			MaxY=Core_Max(GrassLayer,SeaHeight)
			Chunk.Height[LocalX,LocalZ]=MaxY
			for LocalY=MaxY to 0 step -1
				BlockType=0
				if LocalY=GrassLayer
					BlockType=1 // Grass
				elseif LocalY>=DirtHeight and LocalY<GrassLayer
					BlockType=3 // Dirt
				elseif LocalY<DirtHeight
					BlockType=2 // Stone
				endif
				
				if LocalY<=SeaHeight and BlockType=0
					BlockType=25 // Water
				elseif LocalY<=SandHeight and BlockType=1
					BlockType=22 // Sand
				endif
				
				Cave#=abs(GetNoiseXYZ(NoiseX/Voxel_Frecueny3DCave#,LocalY/Voxel_Frecueny3DCave#,NoiseZ/Voxel_Frecueny3DCave#))
				if Cave#>0.75
					BlockType=0
					if LocalY=Chunk.Height[LocalX,LocalZ] then Chunk.Height[LocalX,LocalZ]=LocalY-1
				endif
				
				Chunk.SunLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
				Chunk.BlockLight[LocalX,LocalY,LocalZ]=Voxel_AmbientLight
				Chunk.BlockType[LocalX,LocalY,LocalZ]=BlockType
			next LocalY
		next LocalZ
	next LocalX
	
	Voxel_DebugNoiseTime#=Timer()-StartTime#
endfunction

function Voxel_CreateBlockLight(World ref as WorldData,ChunkX,ChunkZ,LocalX,LocalY,LocalZ)	
	LightValue=Voxel_IsLightBlock(World.Chunk[ChunkX,ChunkZ].BlockType[LocalX,LocalY,LocalZ])
	if LightValue>Voxel_AmbientLight
		Voxel_UpdateBlockLight(World,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,LightValue)
	endif
endfunction

function Voxel_UpdateBlockLight(World ref as WorldData,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,StartBlockLight as integer)
	local FrontierTemp as FrontierData
	local Frontier as FrontierData[]

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
			
			if Voxel_IsTransparentBlock(World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockType[NeighbourLocalX,NeighbourY,NeighbourLocalZ])=1
				CurrentBlockLight=Voxel_GetBlockLight(World,GlobalX,GlobalY,GlobalZ)
				if CurrentBlockLight>World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]+1
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
	local FrontierTemp as FrontierData
	local Frontier as FrontierData[]
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
				
				if Voxel_IsTransparentBlock(World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockType[NeighbourLocalX,NeighbourY,NeighbourLocalZ])=1
					NeighbourBlockLight=World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]
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

	for ID=0 to Voxel_SpreadLight.length-1
		GlobalX=Voxel_SpreadLight[ID].X
		GlobalY=Voxel_SpreadLight[ID].Y
		GlobalZ=Voxel_SpreadLight[ID].Z
		Light=Voxel_SpreadLight[ID].Light
		
		LocalX=Mod(GlobalX,Voxel_ChunkSize)
		LocalZ=Mod(GlobalZ,Voxel_ChunkSize)
		ChunkX=trunc(GlobalX/Voxel_ChunkSize)
		ChunkZ=trunc(GlobalZ/Voxel_ChunkSize)
		
		Voxel_UpdateBlockLight(World,ChunkX,ChunkZ,LocalX,LocalY,LocalZ,Light)
	next ID
	Voxel_SpreadLight.length=-1
endfunction

//~function Voxel_UpdateSunLight(World ref as WorldData,StartX,StartY,StartZ,StartSunLight as integer)
//~	local FrontierTemp as Core_Int3Data
//~	local Frontier as Core_Int3Data[]

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
	StartTime#=Timer()
	
	local FrontierTemp as FrontierData

	for LocalX=0 to Voxel_ChunkSize-1		
		ChunkEast=trunc((LocalX+1)/Voxel_ChunkSize)
		LocalEast=Core_WrapInteger(LocalX+1,Voxel_ChunkSize)
		
		ChunkWest=trunc((LocalX-1)/Voxel_ChunkSize)
		LocalWest=Core_WrapInteger(LocalX-1,Voxel_ChunkSize)
		
		for LocalZ=0 to Voxel_ChunkSize-1
			ChunkNorth=trunc((LocalZ+1)/Voxel_ChunkSize)
			LocalNorth=Core_WrapInteger(LocalZ+1,Voxel_ChunkSize)
			
			ChunkSouth=trunc((LocalZ-1)/Voxel_ChunkSize)
			LocalSouth=Core_WrapInteger(LocalZ-1,Voxel_ChunkSize)
			
			HeightNorth=World.Chunk[ChunkX,ChunkNorth].Height[LocalX,LocalNorth]
			HeightSouth=World.Chunk[ChunkX,ChunkSouth].Height[LocalX,LocalSouth]
			HeightEast=World.Chunk[ChunkEast,ChunkZ].Height[LocalEast,LocalZ]
			HeightWest=World.Chunk[ChunkWest,ChunkZ].Height[LocalWest,LocalZ]

//~			HeightNorth=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalNorth]
//~			HeightSouth=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalSouth]
//~			HeightEast=World.Chunk[ChunkX,ChunkZ].Height[LocalEast,LocalZ]
//~			HeightWest=World.Chunk[ChunkX,ChunkZ].Height[LocalWest,LocalZ]
			
			HeightCurrent=World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]
			
			LocalY=Core_Max(HeightNorth,Core_Max(HeightSouth,Core_Max(HeightEast,Core_Max(HeightWest,HeightCurrent))))+1
			HeightY=Voxel_BlockMax.Y
			
			while HeightY>LocalY
				World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,HeightY,LocalZ]=StartSunLight
				dec HeightY
			endwhile
			
			LocalY=Core_Clamp(World.Chunk[ChunkX,ChunkZ].Height[LocalX,LocalZ]+1,0,Voxel_BlockMax.Y)
			FrontierTemp.Dir=5
			FrontierTemp.X=ChunkX*Voxel_ChunkSize+LocalX
			FrontierTemp.Y=LocalY
			FrontierTemp.Z=ChunkZ*Voxel_ChunkSize+LocalZ
			World.Chunk[ChunkX,ChunkZ].SunFrontier.insert(FrontierTemp)
			
			World.Chunk[ChunkX,ChunkZ].SunLight[LocalX,LocalY,LocalZ]=StartSunLight
		next LocalZ
	next LocalX
	
	Voxel_DebugIterations=0
	while World.Chunk[ChunkX,ChunkZ].SunFrontier.length>=0
		inc Voxel_DebugIterations
		Direction=World.Chunk[ChunkX,ChunkZ].SunFrontier[0].Dir
		GlobalX=World.Chunk[ChunkX,ChunkZ].SunFrontier[0].X
		GlobalY=World.Chunk[ChunkX,ChunkZ].SunFrontier[0].Y
		GlobalZ=World.Chunk[ChunkX,ChunkZ].SunFrontier[0].Z
		World.Chunk[ChunkX,ChunkZ].SunFrontier.remove(0)
		
		for NeighbourID=0 to 5
			if NeighbourID+Direction=5 then continue
				
			NeighbourX=GlobalX+Voxel_Neighbors[NeighbourID].X
			NeighbourY=GlobalY+Voxel_Neighbors[NeighbourID].Y
			NeighbourZ=GlobalZ+Voxel_Neighbors[NeighbourID].Z
			
			if NeighbourX<0 or NeighbourZ<0 or NeighbourX>Voxel_BlockMax.X or NeighbourZ>Voxel_BlockMax.Z then continue
			NeighbourLocalX=Mod(NeighbourX,Voxel_ChunkSize)
			NeighbourLocalZ=Mod(NeighbourZ,Voxel_ChunkSize)
			
			NeighbourChunkX=trunc(NeighbourX/Voxel_ChunkSize)
			NeighbourChunkZ=trunc(NeighbourZ/Voxel_ChunkSize)
						
			if Voxel_IsOpaqueBlock(World.Chunk[NeighbourChunkX,NeighbourChunkZ].BlockType[NeighbourLocalX,NeighbourY,NeighbourLocalZ])=0
				NeighbourSunLight=World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]
				
				CurrentSunLight=Voxel_GetSunLight(World,GlobalX,GlobalY,GlobalZ)
				if CurrentSunLight>NeighbourSunLight+1
					FrontierTemp.Dir=NeighbourID
					FrontierTemp.X=NeighbourX
					FrontierTemp.Y=NeighbourY
					FrontierTemp.Z=NeighbourZ
					
					World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunFrontier.insert(FrontierTemp)
					if NeighbourChunkX<>ChunkX or NeighbourChunkZ<>ChunkZ then Voxel_AddChunktoLoadList(NeighbourChunkX,NeighbourChunkZ)				
					
					if NeighbourID=1 and CurrentSunLight=15
						World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]=CurrentSunLight
					else
						World.Chunk[NeighbourChunkX,NeighbourChunkZ].SunLight[NeighbourLocalX,NeighbourY,NeighbourLocalZ]=CurrentSunLight-1
					endif
				endif
			endif
		next NeighbourID
	endwhile
	
	Voxel_DebugSunTime#=Timer()-StartTime#
endfunction

//~function Voxel_UpdateSunShadow(World ref as WorldData,StartX,StartY,StartZ)
//~	local FrontierTemp as Core_Int3Data
//~	local Frontier as Core_Int3Data[]
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
	until Chunk.BlockType[LocalX,LocalY,LocalZ]<>0
	Chunk.Height[LocalX,LocalZ]=LocalY
//~	if LightValue>Voxel_AmbientLight
//~		Voxel_UpdateSunLight(World,LocalX,LocalY,LocalZ,LightValue)
//~	else
//~		Voxel_UpdateSunShadow(World,LocalX,LocalY,LocalZ)
//~	endif
endfunction

//~function Voxel_JoinFace(CurrentBlockType,NeighbourBlockType)
//~	if CurrentBlockType=0 or NeighbourBlockType=0 then exitfunction 0
//~	if Voxel_Blocks.Attributes[CurrentBlockType-1].JoinFace
//~		exitfunction (CurrentBlockType=NeighbourBlockType)
//~	endif
//~endfunction 0

function Voxel_JoinFace(CurrentBlockType, NeighbourBlockType)
    if CurrentBlockType = 0 or NeighbourBlockType = 0 then exitfunction 0
//~    if Voxel_Blocks.Attributes[CurrentBlockType-1].JoinFace
//~    	exitfunction (CurrentBlockType = NeighbourBlockType)
//~    endif
endfunction (CurrentBlockType = NeighbourBlockType)

function Voxel_IsOpaqueBlock(BlockType)
	if BlockType=0 then exitfunction 0
	Opaque=Voxel_Blocks.Attributes[BlockType-1].Opaque
endfunction Opaque

function Voxel_IsLightBlock(BlockType)
	if BlockType=0 then exitfunction Voxel_AmbientLight
	Light=Voxel_Blocks.Attributes[BlockType-1].Light
endfunction Light

function Voxel_IsTransparentBlock(BlockType)
	if BlockType=0 then exitfunction 1
	Solid=1-Voxel_Blocks.Attributes[BlockType-1].Solid
endfunction Solid

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

function Voxel_RemoveCubeListFromObject(World ref as WorldData,CubeList as Core_Int3Data[])
	local TempLocal as Core_Int3Data
	
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

function Voxel_UpdateChunk(World ref as WorldData,ChunkX,ChunkZ)
	StartTime#=Timer()
	
	Voxel_TempChunk=World.Chunk[ChunkX,ChunkZ]
	for LocalX=0 to Voxel_ChunkSize-1
		for LocalZ=0 to Voxel_ChunkSize-1
			for LocalY=1 to Voxel_TempChunk.Height[LocalX,LocalZ]
				BlockType=Voxel_TempChunk.BlockType[LocalX,LocalY,LocalZ]
				if BlockType<>0
					GlobalX=ChunkX*Voxel_ChunkSize+LocalX
					GlobalZ=ChunkZ*Voxel_ChunkSize+LocalZ
					if Voxel_Blocks.Attributes[BlockType-1].Solid=1
						Voxel_GenerateCubeFaces(Voxel_TempSolidMesh,World,LocalX,LocalY,LocalZ,GlobalX,GlobalZ,BlockType-1)
					else
						Voxel_GenerateCubeFaces(Voxel_TempLooseMesh,World,LocalX,LocalY,LocalZ,GlobalX,GlobalZ,BlockType-1)
					endif
				endif
			next LocalY
		next LocalZ
	next LocalX
	
	if Voxel_TempSolidMesh.Vertex.length>1
		if World.Chunk[ChunkX,ChunkZ].SolidObjectID=0
			ObjectID=Voxel_CreateObject(Voxel_TempSolidMesh,ChunkX,ChunkZ)
			SetObjectAlphaMask(ObjectID,1)
			SetObjectShader(ObjectID,Voxel_OpaqueShaderID)
			World.Chunk[ChunkX,ChunkZ].SolidObjectID=ObjectID
		else
			Voxel_UpdateObject(Voxel_TempSolidMesh,World.Chunk[ChunkX,ChunkZ].SolidObjectID,ChunkX,ChunkZ)
		endif
	endif
	if Voxel_TempLooseMesh.Vertex.length>1
		if World.Chunk[ChunkX,ChunkZ].LooseObjectID=0
			ObjectID=Voxel_CreateObject(Voxel_TempLooseMesh,ChunkX,ChunkZ)
			SetObjectTransparency(ObjectID,1)
			SetObjectShader(ObjectID,Voxel_WaterShaderID)
			SetObjectDepthBias(ObjectID,-1.0)
			World.Chunk[ChunkX,ChunkZ].LooseObjectID=ObjectID
		else
			Voxel_UpdateObject(Voxel_TempLooseMesh,World.Chunk[ChunkX,ChunkZ].LooseObjectID,ChunkX,ChunkZ)
		endif
	endif
	
	Voxel_DebugChunkTime#=Timer()-StartTime#
endfunction

function Voxel_CreateObject(TempMesh ref as MeshData,ChunkX,ChunkZ)
	StartTime#=Timer()
	
	MemblockID=Voxel_CreateMeshMemblock(TempMesh.Vertex.length+1,TempMesh.Index.length+1)
	Voxel_WriteMeshMemblock(MemblockID,TempMesh)		
	ObjectID=CreateObjectFromMeshMemblock(MemblockID)
	DeleteMemblock(MemblockID)
	TempMesh.Index.length=-1
	TempMesh.Vertex.length=-1
	
	SetObjectPosition(ObjectID,ChunkX*Voxel_ChunkSize,0,ChunkZ*Voxel_ChunkSize)
	SetObjectImage(ObjectID,Voxel_DiffuseImageID,0)
	
	Voxel_DebugMeshTime#=Timer()-StartTime#
endfunction ObjectID

function Voxel_UpdateObject(TempMesh ref as MeshData,ObjectID,ChunkX,ChunkZ)
	StartTime#=Timer()
	
	MemblockID=Voxel_CreateMeshMemblock(TempMesh.Vertex.length+1,TempMesh.Index.length+1)
	Voxel_WriteMeshMemblock(MemblockID,TempMesh)
	SetObjectMeshFromMemblock(ObjectID,1,MemblockID)
	DeleteMemblock(MemblockID)
	TempMesh.Index.length=-1
	TempMesh.Vertex.length=-1
	
	Voxel_DebugMeshTime#=Timer()-StartTime#
endfunction

function Voxel_GenerateCubeFaces(Object ref as MeshData,World ref as WorldData,LocalX,LocalY,LocalZ,GlobalX,GlobalZ,AttributeID)	
	local LightValue as integer
	
	Voxel_TempSubimages[0]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].UpID]
	Voxel_TempSubimages[1]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].DownID]
	Voxel_TempSubimages[2]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].BackID]
	Voxel_TempSubimages[3]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].FrontID]
	Voxel_TempSubimages[4]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].RightID]
	Voxel_TempSubimages[5]=Voxel_Blocks.Subimages[Voxel_Blocks.Attributes[AttributeID].LeftID]
	
	CurrentBlockType=Voxel_GetBlockType(World,GlobalX,LocalY,GlobalZ)
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX,LocalY+1,GlobalZ)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ  ))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ  ))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX,  LocalY+1,GlobalZ+1))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX,  LocalY+1,GlobalZ-1))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ+1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ+1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ-1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ-1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=0
		if A00+A10>A01+A11 then Flipped=1
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,LocalY+1,GlobalZ),Voxel_GetSunLight(World,GlobalX,LocalY+1,GlobalZ))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[0],LocalX,LocalY,LocalZ,FaceUp,A00,A01,A10,A11,Flipped)
	endif
	
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX,LocalY-1,GlobalZ)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ  ))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ  ))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX,  LocalY-1,GlobalZ+1))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX,  LocalY-1,GlobalZ-1))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ+1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ+1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ-1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ-1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=1
		if A00+A10<A01+A11 then Flipped=0
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,LocalY-1,GlobalZ),Voxel_GetSunLight(World,GlobalX,LocalY-1,GlobalZ))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[1],LocalX,LocalY,LocalZ,FaceDown,A00,A01,A10,A11,Flipped)
	endif
	
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX,LocalY,GlobalZ+1)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY  ,GlobalZ+1))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY  ,GlobalZ+1))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX  ,LocalY+1,GlobalZ+1))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX  ,LocalY-1,GlobalZ+1))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ+1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ+1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ+1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ+1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=0
		if A00+A10>A01+A11 then Flipped=1
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,LocalY,GlobalZ+1),Voxel_GetSunLight(World,GlobalX,LocalY,GlobalZ+1))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[2],LocalX,LocalY,LocalZ,FaceFront,A00,A01,A10,A11,Flipped)
	endif
	
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX,LocalY,GlobalZ-1)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY  ,GlobalZ-1))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY  ,GlobalZ-1))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX  ,LocalY+1,GlobalZ-1))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX  ,LocalY-1,GlobalZ-1))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ-1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ-1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ-1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ-1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=1
		if A00+A10<A01+A11 then Flipped=0
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX,LocalY,GlobalZ-1),Voxel_GetSunLight(World,GlobalX,LocalY,GlobalZ-1))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[3],LocalX,LocalY,LocalZ,FaceBack,A00,A01,A10,A11,Flipped)
	endif
	
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX+1,LocalY,GlobalZ)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY  ,GlobalZ+1))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY  ,GlobalZ-1))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ  ))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ  ))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ+1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY+1,GlobalZ-1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ+1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX+1,LocalY-1,GlobalZ-1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=1
		if A00+A10<A01+A11 then Flipped=0
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX+1,LocalY,GlobalZ),Voxel_GetSunLight(World,GlobalX+1,LocalY,GlobalZ))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[4],LocalX,LocalY,LocalZ,FaceRight,A00,A01,A10,A11,Flipped)
	endif
	
	NeighbourBlockType=Voxel_GetBlockType(World,GlobalX-1,LocalY,GlobalZ)
	if not(Voxel_IsOpaqueBlock(NeighbourBlockType) or Voxel_JoinFace(CurrentBlockType,NeighbourBlockType))
		side00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY  ,GlobalZ-1))=0)
		side01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY  ,GlobalZ+1))=0)
		side10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ  ))=0)
		side11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ  ))=0)
		
		corner00=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ-1))=0)
		corner01=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY+1,GlobalZ+1))=0)
		corner10=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ-1))=0)
		corner11=(Voxel_IsOpaqueBlock(Voxel_GetBlockType(World,GlobalX-1,LocalY-1,GlobalZ+1))=0)
		
		A00=Voxel_GetVertexAO(side10,side00,corner00)
		A01=Voxel_GetVertexAO(side10,side01,corner01)
		A10=Voxel_GetVertexAO(side11,side01,corner11)
		A11=Voxel_GetVertexAO(side11,side00,corner10)
		
		Flipped=1
		if A00+A10<A01+A11 then Flipped=0
		
		LightValue=Core_Max(Voxel_GetBlockLight(World,GlobalX-1,LocalY,GlobalZ),Voxel_GetSunLight(World,GlobalX-1,LocalY,GlobalZ))/15.0*255
		A00=LightValue-A00
		A01=LightValue-A01
		A10=LightValue-A10
		A11=LightValue-A11
		
		Voxel_AddFaceToObject(Object,Voxel_TempSubimages[5],LocalX,LocalY,LocalZ,FaceLeft,A00,A01,A10,A11,Flipped)
	endif
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
	Result = Core_Min((3 - (side1 + side2 + corner))/3.0*255,224)
endfunction Result

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as MeshData,Subimage ref as SubimageData,X,Y,Z,FaceDir,A00,A01,A10,A11,Flipped)
	HalfFaceSize#=0.5	
	TextureSize#=256
	Select FaceDir
		case FaceUp
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],0,1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],0,1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],0,1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],0,1,0)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
		
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,0,1)
		endcase
		case FaceDown
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],0,-1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],0,-1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],0,-1,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],0,-1,0)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
		
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,0,1)
		endcase
		case FaceFront
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],0,0,1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],0,0,1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],0,0,1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],0,0,1)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
			
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],-1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],-1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],-1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],-1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,1,0)
		endcase
		case FaceBack
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],0,0,-1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],0,0,-1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],0,0,-1)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],0,0,-1)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
		
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],1,0,0)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],1,0,0)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,1,0)
		endcase
		case FaceRight
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X+HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X+HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X+HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X+HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],1,0,0)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
		
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],0,0,1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],0,0,1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],0,0,1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],0,0,1)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,1,0)
		endcase
		case FaceLeft
			Voxel_SetObjectFacePosition(Voxel_TempVertex[0],X-HalfFaceSize#,Y+HalfFaceSize#,Z-HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[1],X-HalfFaceSize#,Y+HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[2],X-HalfFaceSize#,Y-HalfFaceSize#,Z+HalfFaceSize#)
			Voxel_SetObjectFacePosition(Voxel_TempVertex[3],X-HalfFaceSize#,Y-HalfFaceSize#,Z-HalfFaceSize#)
			
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[0],-1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[1],-1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[2],-1,0,0)
			Voxel_SetObjectFaceNormal(Voxel_TempVertex[3],-1,0,0)
			
			Left#=Subimage.X/TextureSize#
			Top#=Subimage.Y/TextureSize#
			Right#=(Subimage.X+Subimage.Width)/TextureSize#
			Bottom#=(Subimage.Y+Subimage.Height)/TextureSize#
			Voxel_SetObjectFaceUV(Voxel_TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(Voxel_TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(Voxel_TempVertex[0],A00,A00,A00,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[1],A01,A01,A01,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[2],A10,A10,A10,255)
			Voxel_SetObjectFaceColor(Voxel_TempVertex[3],A11,A11,A11,255)
		
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[0],0,0,-1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[1],0,0,-1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[2],0,0,-1)
//~			Voxel_SetObjectFaceTangent(Voxel_TempVertex[3],0,0,-1)
//~			
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[0],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[1],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[2],0,1,0)
//~			Voxel_SetObjectFaceBinormal(Voxel_TempVertex[3],0,1,0)
		endcase
	endselect
	
	Object.Vertex.insert(Voxel_TempVertex[0])
	Object.Vertex.insert(Voxel_TempVertex[1])
	Object.Vertex.insert(Voxel_TempVertex[2])
	Object.Vertex.insert(Voxel_TempVertex[3])
	
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

function Voxel_WriteMeshMemblock(MemblockID,Object ref as MeshData)
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