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
	BlockType
	LightValue
endtype

type SubimageData
	X
	Y
	Width
	Height
endtype

type FaceIndexData
	FrontID
	BackID
	UpID
	DownID
	LeftID
	RightID
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

type ChunkData
	Min as Int3Data
	Max as Int3Data
	ObjectID as integer
	Visible as integer
endtype

global Chunk as ChunkData[32,32,32]

#constant ChunkSize	16
global WorldSize
global WorldSizeX
global WorldSizeY
global WorldSizeZ
global AtlasImageID
global ChunkUpdateX
global ChunkUpdateY
global ChunkUpdateZ

// Functions

// Initialise the Voxel Engine
function Voxel_Init(World ref as WorldData[][][],File$)
	AtlasImageID=LoadImage(File$)
	
	WorldSize=World.length
	if WorldSize<World[0].length then WorldSize=World[0].length
	if WorldSize<World[0,0].length then WorldSize=World[0,0].length
	
	WorldSizeX=trunc(World.length/ChunkSize)-1
	WorldSizeY=trunc(World[0].length/ChunkSize)-1
	WorldSizeZ=trunc(World[0,0].length/ChunkSize)-1
endfunction

function Voxel_UpdateObjects(FaceImages ref as FaceimageData,World ref as WorldData[][][],CameraX,CameraY,CameraZ,ViewDistance)	
		CameraChunkX=CameraX/ChunkSize
		CameraChunkY=CameraY/ChunkSize
		CameraChunkZ=CameraZ/ChunkSize
		
		MinX=Voxel_Clamp(CameraChunkX-ViewDistance,0,WorldSizeX)
		MinY=Voxel_Clamp(CameraChunkY-ViewDistance,0,WorldSizeY)
		MinZ=Voxel_Clamp(CameraChunkZ-ViewDistance,0,WorldSizeZ)
		MaxX=Voxel_Clamp(CameraChunkX+ViewDistance,0,WorldSizeX)
		MaxY=Voxel_Clamp(CameraChunkY+ViewDistance,0,WorldSizeY)
		MaxZ=Voxel_Clamp(CameraChunkZ+ViewDistance,0,WorldSizeZ)
		
		ChunkUpdateX=ChunkUpdateX+1
		if ChunkUpdateX>MaxX
			ChunkUpdateX=MinX
			ChunkUpdateY=ChunkUpdateY+1
			if ChunkUpdateY>MaxY
				ChunkUpdateY=MinY
				ChunkUpdateZ=ChunkUpdateZ+1
				if ChunkUpdateZ>MaxZ
					ChunkUpdateZ=MinZ
				endif
			endif
		endif
		
		TempX=Voxel_Clamp(ChunkUpdateX,0,WorldSizeX)
		TempY=Voxel_Clamp(ChunkUpdateY,0,WorldSizeY)
		TempZ=Voxel_Clamp(ChunkUpdateZ,0,WorldSizeZ)
		
		if Chunk[TempX,TempY,TempZ].Visible=0
			Voxel_CreateNoise(World,TempX,TempY,TempZ)
			Voxel_CreateObject(Faceimages,World,TempX,TempY,TempZ)
			Chunk[TempX,TempY,TempZ].Visible=1
		endif
endfunction

function Voxel_CreateNoise(World ref as WorldData[][][],ChunkX,ChunkY,ChunkZ)
	StartX=ChunkX*ChunkSize
	EndX=StartX+ChunkSize
	StartY=ChunkY*ChunkSize
	EndY=StartY+ChunkSize
	StartZ=ChunkZ*ChunkSize
	EndZ=StartZ+ChunkSize
	
	HeightFrequency#=32.0
	for X=StartX to EndX+1
		for Y=StartY to EndY+1
			for Z=StartZ to EndZ+1
				Value#=Noise_Perlin2(X/HeightFrequency#,Z/HeightFrequency#)*World[0].length
				MaxGrass=(World[0].length*0.7)+Value#/2.0
				if Y<MaxGrass then World[X,Y,Z].BlockType=1
			next Z
		next Y
	next X
endfunction

function Voxel_CreateObject(FaceImages ref as FaceimageData,World ref as WorldData[][][],ChunkX,ChunkY,ChunkZ)
	StartX=ChunkX*ChunkSize
	EndX=StartX+ChunkSize
	StartY=ChunkY*ChunkSize
	EndY=StartY+ChunkSize
	StartZ=ChunkZ*ChunkSize
	EndZ=StartZ+ChunkSize
	
	local Object as ObjectData
	for X=StartX+1 to EndX
		for Y=StartY+1 to EndY
			for Z=StartZ+1 to EndZ
				Voxel_GenerateCubeFaces(Object,FaceImages,World,X,Y,Z)
			next Z
		next Y
	next X
	
	if Object.Vertex.length>1
		MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
		Voxel_WriteMeshMemblock(MemblockID,Object)
		Object.Index.length=-1
		Object.Vertex.length=-1
		
		ObjectID=1+ChunkX+ChunkY*WorldSize+ChunkZ*WorldSize*WorldSize
		CreateObjectFromMeshMemblock(ObjectID,MemblockID)
		DeleteMemblock(MemblockID)
		
		SetObjectPosition(ObjectID,ChunkX*ChunkSize,ChunkY*ChunkSize,ChunkZ*ChunkSize)
		SetObjectImage(ObjectID,AtlasImageID,0)
	endif
endfunction ObjectID

function Voxel_UpdateObject(ObjectID,Faceimages ref as FaceimageData,World ref as WorldData[][][])
	if GetObjectExists(ObjectID)
		ObjectX=GetObjectX(ObjectID)
		ObjectY=GetObjectY(ObjectID)
		ObjectZ=GetObjectZ(ObjectID)
		
		StartX=ObjectX
		EndX=StartX+ChunkSize
		StartY=ObjectY
		EndY=StartY+ChunkSize
		StartZ=ObjectZ
		EndZ=StartZ+ChunkSize
		
		local Object as ObjectData
		for X=StartX+1 to EndX
			for Y=StartY+1 to EndY
				for Z=StartZ+1 to EndZ
					Voxel_GenerateCubeFaces(Object,Faceimages,World,X,Y,Z)
				next Z
			next Y
		next X
		
		if Object.Vertex.length>1
			MemblockID=Voxel_CreateMeshMemblock(Object.Vertex.length+1,Object.Index.length+1)
			Voxel_WriteMeshMemblock(MemblockID,Object)
			SetObjectMeshFromMemblock(ObjectID,1,MemblockID)
			DeleteMemblock(MemblockID)
			Object.Index.length=-1
			Object.Vertex.length=-1
		endif
	endif
endfunction

function Voxel_ReadFaceImages(SubImageFile$,FaceIndexFile$, Faceimages ref as FaceimageData)
	Voxel_ReadSubimages(SubImageFile$,Faceimages.Subimages)
	Voxel_ReadFaceimageIdices(FaceIndexFile$,Faceimages.FaceimageIndices)
endfunction

function Voxel_ReadSubimages(File$,Subimages ref as SubimageData[])
	Subimages.length=-1
	local TempSubimage as SubimageData
	FileID=OpenToRead(File$)
	repeat
		Line$=ReadLine(FileID)
		TempSubimage.X=val(GetStringToken(Line$,":",2))
		TempSubimage.Y=val(GetStringToken(Line$,":",3))
		TempSubimage.Width=val(GetStringToken(Line$,":",4))
		TempSubimage.Height=val(GetStringToken(Line$,":",5))
		Subimages.insert(TempSubimage)
	until FileEOF(FileID)
	CloseFile(FileID)
endfunction

function Voxel_ReadFaceimageIdices(File$,FaceIndices ref as FaceIndexData[])
	FaceIndices.length=-1
	local TempFaceIndices as FaceIndexData
	FileID=OpenToRead(File$)
	repeat
		Line$=ReadLine(FileID)
		TempFaceIndices.FrontID=val(GetStringToken(Line$,":",2))
		TempFaceIndices.BackID=val(GetStringToken(Line$,":",3))
		TempFaceIndices.UpID=val(GetStringToken(Line$,":",4))
		TempFaceIndices.DownID=val(GetStringToken(Line$,":",5))
		TempFaceIndices.RightID=val(GetStringToken(Line$,":",6))
		TempFaceIndices.LeftID=val(GetStringToken(Line$,":",7))
		FaceIndices.insert(TempFaceIndices)
	until FileEOF(FileID)
	CloseFile(FileID)
endfunction

function Voxel_RemoveCubeFromObject(ObjectID,Faceimages ref as FaceimageData,World ref as WorldData[][][],X,Y,Z)
	X=Voxel_Clamp(X,1,World.length-1)
	Y=Voxel_Clamp(Y,1,World[0].length-1)
	Z=Voxel_Clamp(Z,1,World[0,0].length-1)
	
	BlockType=World[X,Y,Z].BlockType
	World[X,Y,Z].BlockType=0
	Voxel_UpdateObject(ObjectID,Faceimages,World)
	
	ChunkX=round((X-1)/ChunkSize)
	ChunkY=round((Y-1)/ChunkSize)
	ChunkZ=round((Z-1)/ChunkSize)
	CubeX=1+Mod(X-1,ChunkSize)
	CubeY=1+Mod(Y-1,ChunkSize)
	CubeZ=1+Mod(Z-1,ChunkSize)

	if CubeX=ChunkSize
		NeighbourObjectID=1+(ChunkX+1)+ChunkY*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeX=1
		NeighbourObjectID=1+(ChunkX-1)+ChunkY*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeY=ChunkSize
		NeighbourObjectID=1+ChunkX+(ChunkY+1)*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeY=1
		NeighbourObjectID=1+ChunkX+(ChunkY-1)*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeZ=ChunkSize
		NeighbourObjectID=1+ChunkX+ChunkY*WorldSize+(ChunkZ+1)*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeZ=1
		NeighbourObjectID=1+ChunkX+ChunkY*WorldSize+(ChunkZ-1)*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
endfunction BlockType

function Voxel_AddCubeToObject(ObjectID,Faceimages ref as FaceimageData,World ref as WorldData[][][],X,Y,Z,BlockType)
	X=Voxel_Clamp(X,1,World.length-1)
	Y=Voxel_Clamp(Y,1,World[0].length-1)
	Z=Voxel_Clamp(Z,1,World[0,0].length-1)
	
	World[X,Y,Z].BlockType=BlockType
	Voxel_UpdateObject(ObjectID,Faceimages,World)
	
	ChunkX=round((X-1)/ChunkSize)
	ChunkY=round((Y-1)/ChunkSize)
	ChunkZ=round((Z-1)/ChunkSize)
	CubeX=1+Mod(X-1,ChunkSize)
	CubeY=1+Mod(Y-1,ChunkSize)
	CubeZ=1+Mod(Z-1,ChunkSize)
	
	if CubeX=ChunkSize
		NeighbourObjectID=1+(ChunkX+1)+ChunkY*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeX=1
		NeighbourObjectID=1+(ChunkX-1)+ChunkY*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeY=ChunkSize
		NeighbourObjectID=1+ChunkX+(ChunkY+1)*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeY=1
		NeighbourObjectID=1+ChunkX+(ChunkY-1)*WorldSize+ChunkZ*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeZ=ChunkSize
		NeighbourObjectID=1+ChunkX+ChunkY*WorldSize+(ChunkZ+1)*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
	if CubeZ=1
		NeighbourObjectID=1+ChunkX+ChunkY*WorldSize+(ChunkZ-1)*WorldSize*WorldSize
		Voxel_UpdateObject(NeighbourObjectID,Faceimages,World)
	endif
endfunction

function Voxel_GenerateCubeFaces(Object ref as ObjectData,Faceimages ref as FaceimageData,World ref as WorldData[][][],X,Y,Z)
	if World[X,Y,Z].BlockType>0
		local TempSubimages as SubimageData[5]
		
		Index=World[X,Y,Z].BlockType-1
		TempSubimages[0]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].FrontID]
		TempSubimages[1]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].BackID]
		TempSubimages[2]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].RightID]
		TempSubimages[3]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].LeftID]
		TempSubimages[4]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].UpID]
		TempSubimages[5]=Faceimages.Subimages[Faceimages.FaceimageIndices[Index].DownID]
		
		CubeX=1+Mod(X-1,ChunkSize)
		CubeY=1+Mod(Y-1,ChunkSize)
		CubeZ=1+Mod(Z-1,ChunkSize)
		if World[X,Y,Z+1].BlockType=0
			side1=(World[X,Y+1,Z+1].BlockType=0)
			side2=(World[X-1,Y,Z+1].BlockType=0)
			corner=(World[X-1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y+1,Z+1].BlockType=0)
			side2=(World[X+1,Y,Z+1].BlockType=0)
			corner=(World[X+1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X,Y-1,Z+1].BlockType=0)
//~			side2=(World[X+1,Y,Z+1].BlockType=0)
			corner=(World[X+1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y-1,Z+1].BlockType=0)
			side2=(World[X-1,Y,Z+1].BlockType=0)
			corner=(World[X-1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceFront,AO0,AO1,AO2,AO3)
		endif
		if World[X,Y,Z-1].BlockType=0			
			side1=(World[X,Y+1,Z-1].BlockType=0)
			side2=(World[X+1,Y,Z-1].BlockType=0)
			corner=(World[X+1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y+1,Z-1].BlockType=0)
			side2=(World[X-1,Y,Z-1].BlockType=0)
			corner=(World[X-1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X,Y-1,Z-1].BlockType=0)
//~			side2=(World[X-1,Y,Z-1].BlockType=0)
			corner=(World[X-1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y-1,Z-1].BlockType=0)
			side2=(World[X+1,Y,Z-1].BlockType=0)
			corner=(World[X+1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3)
		endif
		if World[X+1,Y,Z].BlockType=0	
			side1=(World[X+1,Y+1,Z].BlockType=0)
			side2=(World[X+1,Y,Z+1].BlockType=0)
			corner=(World[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X+1,Y+1,Z].BlockType=0)
			side2=(World[X+1,Y,Z-1].BlockType=0)
			corner=(World[X+1,Y+1,Z-1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X+1,Y-1,Z].BlockType=0)
//~			side2=(World[X+1,Y,Z-1].BlockType=0)
			corner=(World[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X+1,Y-1,Z].BlockType=0)
			side2=(World[X+1,Y,Z+1].BlockType=0)
			corner=(World[X+1,Y-1,Z+1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceRight,AO0,AO1,AO2,AO3)
		endif
		if World[X-1,Y,Z].BlockType=0		
			side1=(World[X-1,Y+1,Z].BlockType=0)
			side2=(World[X-1,Y,Z-1].BlockType=0)
			corner=(World[X-1,Y+1,Z-1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X-1,Y+1,Z].BlockType=0)
			side2=(World[X-1,Y,Z+1].BlockType=0)
			corner=(World[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X-1,Y-1,Z].BlockType=0)
//~			side2=(World[X-1,Y,Z+1].BlockType=0)
			corner=(World[X-1,Y-1,Z+1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X-1,Y-1,Z].BlockType=0)
			side2=(World[X-1,Y,Z-1].BlockType=0)
			corner=(World[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceLeft,AO0,AO1,AO2,AO3)
		endif
		if World[X,Y+1,Z].BlockType=0		
			side1=(World[X,Y+1,Z+1].BlockType=0)
			side2=(World[X+1,Y+1,Z].BlockType=0)
			corner=(World[X+1,Y+1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y+1,Z+1].BlockType=0)
			side2=(World[X-1,Y+1,Z].BlockType=0)
			corner=(World[X-1,Y+1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X,Y+1,Z-1].BlockType=0)
//~			side2=(World[X-1,Y+1,Z].BlockType=0)
			corner=(World[X-1,Y+1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y+1,Z-1].BlockType=0)
			side2=(World[X+1,Y+1,Z].BlockType=0)
			corner=(World[X+1,Y+1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceUp,AO0,AO1,AO2,AO3)
		endif
		if World[X,Y-1,Z].BlockType=0			
			side1=(World[X,Y-1,Z+1].BlockType=0)
			side2=(World[X-1,Y-1,Z].BlockType=0)
			corner=(World[X-1,Y-1,Z+1].BlockType=0)
			AO0=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y-1,Z+1].BlockType=0)
			side2=(World[X+1,Y-1,Z].BlockType=0)
			corner=(World[X+1,Y-1,Z+1].BlockType=0)
			AO1=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			side1=(World[X,Y-1,Z-1].BlockType=0)
//~			side2=(World[X+1,Y-1,Z].BlockType=0)
			corner=(World[X+1,Y-1,Z-1].BlockType=0)
			AO2=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
//~			side1=(World[X,Y-1,Z-1].BlockType=0)
			side2=(World[X-1,Y-1,Z].BlockType=0)
			corner=(World[X-1,Y-1,Z-1].BlockType=0)
			AO3=Voxel_GetVertexAO(side1,side2,corner)/3.0*255
			
			Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceDown,AO0,AO1,AO2,AO3)
		endif
	endif
endfunction

// Populate the MeshObject with Data
function Voxel_AddFaceToObject(Object ref as ObjectData,Subimages ref as SubimageData[],World ref as WorldData[][][],X,Y,Z,FaceDir,AO0,AO1,AO2,AO3)
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