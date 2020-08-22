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
	Terrain as TerrainData[0,0,0]
	Chunk as ChunkData[0,0,0]
endtype

type TerrainData
	BlockType as integer
	LightValue as integer
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

type ChunkData
	Border as BorderData
	ObjectID as integer
	Visible as integer
endtype

global Voxel_ChunkSize
global Voxel_WorldSizeX
global Voxel_WorldSizeY
global Voxel_WorldSizeZ
global Voxel_AtlasImageID
global Voxel_ChunkUpdateX
global Voxel_ChunkUpdateY
global Voxel_ChunkUpdateZ
global Voxel_ChunkUpdateDist

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData,ChunkSize,TerrainSizeX,TerrainSizeY,TerrainSizeZ,File$)
	Voxel_AtlasImageID=LoadImage(File$)
	
	Voxel_ChunkSize=ChunkSize
	Voxel_WorldSizeX=trunc((TerrainSizeX+1)/Voxel_ChunkSize)-1
	Voxel_WorldSizeY=trunc((TerrainSizeY+1)/Voxel_ChunkSize)-1
	Voxel_WorldSizeZ=trunc((TerrainSizeZ+1)/Voxel_ChunkSize)-1
	
	World.Terrain.length=TerrainSizeX+1
	for X=0 to World.Terrain.length
		World.Terrain[X].length=TerrainSizeY+1
		for Y=0 to World.Terrain[X].length
			World.Terrain[X,Y].length=TerrainSizeZ+1
		next Y
	next X
	
	World.Chunk.length=Voxel_WorldSizeX
	for X=0 to World.Chunk.length
		World.Chunk[X].length=Voxel_WorldSizeY
		for Y=0 to World.Chunk[X].length
			World.Chunk[X,Y].length=Voxel_WorldSizeZ
		next Y
	next X
endfunction

function Voxel_UpdateObjects(FaceImages ref as FaceimageData,Chunk ref as ChunkData[][][],World ref as WorldData,PosX,PosY,PosZ,ViewDistance)	
		CameraChunkX=round((PosX-1)/Voxel_ChunkSize)
		CameraChunkY=round((PosY-1)/Voxel_ChunkSize)
		CameraChunkZ=round((PosZ-1)/Voxel_ChunkSize)
		
		MinX=Voxel_Clamp(CameraChunkX-Voxel_ChunkUpdateDist,0,Voxel_WorldSizeX)
		MinY=Voxel_Clamp(CameraChunkY-Voxel_ChunkUpdateDist,0,Voxel_WorldSizeY)
		MinZ=Voxel_Clamp(CameraChunkZ-Voxel_ChunkUpdateDist,0,Voxel_WorldSizeZ)
		MaxX=Voxel_Clamp(CameraChunkX+Voxel_ChunkUpdateDist,0,Voxel_WorldSizeX)
		MaxY=Voxel_Clamp(CameraChunkY+Voxel_ChunkUpdateDist,0,Voxel_WorldSizeY)
		MaxZ=Voxel_Clamp(CameraChunkZ+Voxel_ChunkUpdateDist,0,Voxel_WorldSizeZ)

		if Voxel_ChunkUpdateY>MaxY
			Voxel_ChunkUpdateY=MinY
			Voxel_ChunkUpdateX=Voxel_ChunkUpdateX+1
			if Voxel_ChunkUpdateX>MaxX
				Voxel_ChunkUpdateX=MinX
				Voxel_ChunkUpdateZ=Voxel_ChunkUpdateZ+1
				if Voxel_ChunkUpdateZ>MaxZ
					Voxel_ChunkUpdateZ=MinZ
					Voxel_ChunkUpdateDist=Voxel_ChunkUpdateDist+1
					if Voxel_ChunkUpdateDist>ViewDistance
						Voxel_ChunkUpdateDist=0
					endif
				endif
			endif
		endif
		
		TempX=Voxel_Clamp(Voxel_ChunkUpdateX,0,Voxel_WorldSizeX)
		TempY=Voxel_Clamp(Voxel_ChunkUpdateY,0,Voxel_WorldSizeY)
		TempZ=Voxel_Clamp(Voxel_ChunkUpdateZ,0,Voxel_WorldSizeZ)
		
		Chunk[TempX,TempY,TempZ].Border.Min.X=Voxel_ChunkUpdateX*Voxel_ChunkSize+1
		Chunk[TempX,TempY,TempZ].Border.Min.Y=Voxel_ChunkUpdateY*Voxel_ChunkSize+1
		Chunk[TempX,TempY,TempZ].Border.Min.Z=Voxel_ChunkUpdateZ*Voxel_ChunkSize+1
		Chunk[TempX,TempY,TempZ].Border.Max.X=Voxel_ChunkUpdateX*Voxel_ChunkSize+Voxel_ChunkSize
		Chunk[TempX,TempY,TempZ].Border.Max.Y=Voxel_ChunkUpdateY*Voxel_ChunkSize+Voxel_ChunkSize
		Chunk[TempX,TempY,TempZ].Border.Max.Z=Voxel_ChunkUpdateZ*Voxel_ChunkSize+Voxel_ChunkSize
		
		ChunkMidX#=Chunk[TempX,TempY,TempZ].Border.Min.X+(Chunk[TempX,TempY,TempZ].Border.Max.X-Chunk[TempX,TempY,TempZ].Border.Min.X)/2.0
		ChunkMidY#=Chunk[TempX,TempY,TempZ].Border.Min.Y+(Chunk[TempX,TempY,TempZ].Border.Max.Y-Chunk[TempX,TempY,TempZ].Border.Min.Y)/2.0
		ChunkMidZ#=Chunk[TempX,TempY,TempZ].Border.Min.Z+(Chunk[TempX,TempY,TempZ].Border.Max.Z-Chunk[TempX,TempY,TempZ].Border.Min.Z)/2.0
		
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
		
		if Dot#>0.4 or (CameraChunkX=TempX and CameraChunkY=TempY and CameraChunkZ=TempZ)
			if Chunk[TempX,TempY,TempZ].ObjectID=0
//~				Voxel_CreateNoise(Chunk[TempX,TempY,TempZ].Border,World)
				Voxel_CreateObject(Faceimages,Chunk[TempX,TempY,TempZ],World)
				Chunk[TempX,TempY,TempZ].Visible=1
			elseif Chunk[TempX,TempY,TempZ].Visible=0
				SetObjectVisible(Chunk[TempX,TempY,TempZ].ObjectID,1)
				Chunk[TempX,TempY,TempZ].Visible=1
			endif
		else
			if Chunk[TempX,TempY,TempZ].Visible=1 and Chunk[TempX,TempY,TempZ].ObjectID>0
				SetObjectVisible(Chunk[TempX,TempY,TempZ].ObjectID,0)
//~				Voxel_DeleteObject(Chunk[TempX,TempY,TempZ])
				Chunk[TempX,TempY,TempZ].Visible=0
			endif
		endif
		
		
//~		if Chunk[TempX,TempY,TempZ].ObjectID=0 then Voxel_CreateObject(Faceimages,Chunk[TempX,TempY,TempZ],World)

		Voxel_ChunkUpdateY=Voxel_ChunkUpdateY+1
endfunction

function Voxel_CreateNoise(Border ref as BorderData,World ref as WorldData)	
	freq1#=32.0
	freq2#=12.0
	freq3#=2.0	
	for CubeX=Border.Min.X-1 to Border.Max.X+1
		for CubeZ=Border.Min.Z-1 to Border.Max.Z+1
			for CubeY=Border.Min.Y-1 to Border.Max.Y+1
				Value1#=Noise_Perlin2(CubeX/freq1#,CubeZ/freq1#)*World.Terrain[0].length
//~				Value2#=Noise_Perlin3(CubeX/freq2#,CubeY/freq2#,CubeZ/freq2#)
				MaxGrass=(World.Terrain[0].length*0.7)+Value1#/2
				MaxDirt=(World.Terrain[0].length*0.64)+Value1#/2
				MaxStone=(World.Terrain[0].length*0.4)+Value1#/2
				if CubeY>MaxDirt and CubeY<=MaxGrass
					World.Terrain[CubeX,CubeY,CubeZ].BlockType=1
				elseif CubeY>MaxStone and CubeY<=MaxDirt
					World.Terrain[CubeX,CubeY,CubeZ].BlockType=3
				elseif CubeY<=MaxStone
					World.Terrain[CubeX,CubeY,CubeZ].BlockType=2
					Value3#=Noise_Perlin3(CubeX/freq3#,CubeY/freq3#,CubeZ/freq3#)
					if Value3#>0.68 then World.Terrain[CubeX,CubeY,CubeZ].BlockType=4
				endif
//~				if Value2#>0.5 then World.Terrain[CubeX,CubeY,CubeZ].BlockType=0
			next CubeY
		next CubeZ
	next CubeX
endfunction

function Voxel_DeleteObject(Chunk ref as ChunkData)	
	DeleteObject(Chunk.ObjectID)
	Chunk.ObjectID=0
endfunction

function Voxel_CreateObject(FaceImages ref as FaceimageData,Chunk ref as ChunkData,World ref as WorldData)
	local Object as ObjectData
	for CubeX=Chunk.Border.Min.X to Chunk.Border.Max.X
		for CubeZ=Chunk.Border.Min.Z to Chunk.Border.Max.Z
			for CubeY=Chunk.Border.Min.Y to Chunk.Border.Max.Y
				Voxel_GenerateCubeFaces(Object,Faceimages,World,CubeX,CubeY,CubeZ)
			next CubeY
		next CubeZ
	next CubeX
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)
		Object.Index.length=-1
		Object.Vertex.length=-1
		
		Chunk.ObjectID=CreateObjectFromMeshMemblock(MemblockID)
		DeleteMemblock(MemblockID)
		
		SetObjectPosition(Chunk.ObjectID,Chunk.Border.Min.X-1,Chunk.Border.Min.Y-1,Chunk.Border.Min.Z-1)
		SetObjectImage(Chunk.ObjectID,Voxel_AtlasImageID,0)
		Chunk.Visible=1
	endif
endfunction Chunk.ObjectID

function Voxel_UpdateObject(Faceimages ref as FaceimageData,Chunk ref as ChunkData,World ref as WorldData)		
	local Object as ObjectData
	for CubeX=Chunk.Border.Min.X to Chunk.Border.Max.X
		for CubeZ=Chunk.Border.Min.Z to Chunk.Border.Max.Z
			for CubeY=Chunk.Border.Min.Y to Chunk.Border.Max.Y
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

function Voxel_RemoveCubeFromObject(Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z)
	X=Voxel_Clamp(X,1,World.Terrain.length-1)
	Y=Voxel_Clamp(Y,1,World.Terrain[0].length-1)
	Z=Voxel_Clamp(Z,1,World.Terrain[0,0].length-1)
	
	BlockType=World.Terrain[X,Y,Z].BlockType
	World.Terrain[X,Y,Z].BlockType=0
	
	ChunkX=round((X-1)/Voxel_ChunkSize)
	ChunkY=round((Y-1)/Voxel_ChunkSize)
	ChunkZ=round((Z-1)/Voxel_ChunkSize)
	Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ],World)
	
	CubeX=1+Mod(X-1,Voxel_ChunkSize)
	CubeY=1+Mod(Y-1,Voxel_ChunkSize)
	CubeZ=1+Mod(Z-1,Voxel_ChunkSize)

	if CubeX=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX+1,ChunkY,ChunkZ],World)
	endif
	if CubeX=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX-1,ChunkY,ChunkZ],World)
	endif
	if CubeY=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY+1,ChunkZ],World)
	endif
	if CubeY=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY-1,ChunkZ],World)
	endif
	if CubeZ=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ+1],World)
	endif
	if CubeZ=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ-1],World)
	endif
endfunction BlockType

function Voxel_AddCubeToObject(Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z,BlockType)
	X=Voxel_Clamp(X,1,World.Terrain.length-1)
	Y=Voxel_Clamp(Y,1,World.Terrain[0].length-1)
	Z=Voxel_Clamp(Z,1,World.Terrain[0,0].length-1)
	
	World.Terrain[X,Y,Z].BlockType=BlockType
	
	ChunkX=round((X-1)/Voxel_ChunkSize)
	ChunkY=round((Y-1)/Voxel_ChunkSize)
	ChunkZ=round((Z-1)/Voxel_ChunkSize)
	Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ],World)
	
	CubeX=1+Mod(X-1,Voxel_ChunkSize)
	CubeY=1+Mod(Y-1,Voxel_ChunkSize)
	CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
	
	if CubeX=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX+1,ChunkY,ChunkZ],World)
	endif
	if CubeX=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX-1,ChunkY,ChunkZ],World)
	endif
	if CubeY=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY+1,ChunkZ],World)
	endif
	if CubeY=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY-1,ChunkZ],World)
	endif
	if CubeZ=Voxel_ChunkSize
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ+1],World)
	endif
	if CubeZ=1
		Voxel_UpdateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ-1],World)
	endif
endfunction

function Voxel_GenerateCubeFaces(Object ref as ObjectData,Faceimages ref as FaceimageData,World ref as WorldData,X,Y,Z)
	if World.Terrain[X,Y,Z].BlockType>0
		local TempSubimages as SubimageData[5]
		
		Index=World.Terrain[X,Y,Z].BlockType-1
		TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]
		
		CubeX=1+Mod(X-1,Voxel_ChunkSize)
		CubeY=1+Mod(Y-1,Voxel_ChunkSize)
		CubeZ=1+Mod(Z-1,Voxel_ChunkSize)
		if World.Terrain[X,Y,Z+1].BlockType=0
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
//~			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceFront,AO0,AO1,AO2,AO3)
		endif
		if World.Terrain[X,Y,Z-1].BlockType=0			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
//~			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3)
		endif
		if World.Terrain[X+1,Y,Z].BlockType=0	
			side1=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X+1,Y-1,Z].BlockType=0)
//~			side2=(World.Terrain[X+1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X+1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceRight,AO0,AO1,AO2,AO3)
		endif
		if World.Terrain[X-1,Y,Z].BlockType=0		
			side1=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X-1,Y-1,Z].BlockType=0)
//~			side2=(World.Terrain[X-1,Y,Z+1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			side2=(World.Terrain[X-1,Y,Z-1].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceLeft,AO0,AO1,AO2,AO3)
		endif
		if World.Terrain[X,Y+1,Z].BlockType=0		
			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y+1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
//~			side2=(World.Terrain[X-1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y+1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y+1,Z-1].BlockType=0)
			side2=(World.Terrain[X+1,Y+1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y+1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceUp,AO0,AO1,AO2,AO3)
		endif
		if World.Terrain[X,Y-1,Z].BlockType=0			
			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y-1,Z+1].BlockType=0)
			side2=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
//~			side2=(World.Terrain[X+1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World.Terrain[X,Y-1,Z-1].BlockType=0)
			side2=(World.Terrain[X-1,Y-1,Z].BlockType=0)
			corner=(World.Terrain[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceDown,AO0,AO1,AO2,AO3)
		endif
	endif
endfunction

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as ObjectData,Subimages ref as SubimageData[],World ref as WorldData,X,Y,Z,FaceDir,AO0,AO1,AO2,AO3)
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
			
			Left#=Subimages[0].X/TextureSize#
			Top#=Subimages[0].Y/TextureSize#
			Right#=(Subimages[0].X+Subimages[0].Width)/TextureSize#
			Bottom#=(Subimages[0].Y+Subimages[0].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
			
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
			
			Left#=Subimages[1].X/TextureSize#
			Top#=Subimages[1].Y/TextureSize#
			Right#=(Subimages[1].X+Subimages[1].Width)/TextureSize#
			Bottom#=(Subimages[1].Y+Subimages[1].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
		
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
			
			Left#=Subimages[3].X/TextureSize#
			Top#=Subimages[3].Y/TextureSize#
			Right#=(Subimages[3].X+Subimages[3].Width)/TextureSize#
			Bottom#=(Subimages[3].Y+Subimages[3].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
		
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
			
			Left#=Subimages[2].X/TextureSize#
			Top#=Subimages[2].Y/TextureSize#
			Right#=(Subimages[2].X+Subimages[2].Width)/TextureSize#
			Bottom#=(Subimages[2].Y+Subimages[2].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
		
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
			
			Left#=Subimages[4].X/TextureSize#
			Top#=Subimages[4].Y/TextureSize#
			Right#=(Subimages[4].X+Subimages[4].Width)/TextureSize#
			Bottom#=(Subimages[4].Y+Subimages[4].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
		
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
			
			Left#=Subimages[5].X/TextureSize#
			Top#=Subimages[5].Y/TextureSize#
			Right#=(Subimages[5].X+Subimages[5].Width)/TextureSize#
			Bottom#=(Subimages[5].Y+Subimages[5].Height)/TextureSize#
			Voxel_SetObjectFaceUV(TempVertex[0],Right#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[1],Left#,Top#)
			Voxel_SetObjectFaceUV(TempVertex[2],Left#,Bottom#)
			Voxel_SetObjectFaceUV(TempVertex[3],Right#,Bottom#)
			
			Voxel_SetObjectFaceColor(TempVertex[0],255-AO0,255-AO0,255-AO0,255)
			Voxel_SetObjectFaceColor(TempVertex[1],255-AO1,255-AO1,255-AO1,255)
			Voxel_SetObjectFaceColor(TempVertex[2],255-AO2,255-AO2,255-AO2,255)
			Voxel_SetObjectFaceColor(TempVertex[3],255-AO3,255-AO3,255-AO3,255)
		
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
	Object.Index.insert(VertexID+0)
	Object.Index.insert(VertexID+1)
	Object.Index.insert(VertexID+2)
	Object.Index.insert(VertexID+2)
	Object.Index.insert(VertexID+3)
	Object.Index.insert(VertexID+0)
endfunction

function Voxel_GetVertexAO(side1, side2, corner)
//~  if (side1 and side2) then exitfunction 0
endfunction 3 - (side1 + side2 + corner)

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