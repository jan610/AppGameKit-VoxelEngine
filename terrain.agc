// Project: AppGameKit-VoxelEngine
// File: terrain.agc
// Created: 20-07-31

global freq1# as float =32.0
global freq2# as float =12.0
global freq3# as float =2.0

function Voxel_Generate_Terrain(seed as integer)
	
	Noise_Init()
	Noise_Seed(seed)

	Voxel_Logger_Start() // Init the logger
	
	for X=0 to World.Terrain.length
		for Y=0 to World.Terrain[0].length
			for Z=0 to World.Terrain[0,0].length
				Value1#=Noise_Perlin2(X/freq1#,Z/freq1#)*World.Terrain[0].length
				Value2#=Noise_Perlin3(X/freq2#,Y/freq2#,Z/freq2#)
				MaxGrass=(World.Terrain[0].length*0.7)+Value1#/2
				MaxDirt=(World.Terrain[0].length*0.64)+Value1#/2
				MaxStone=(World.Terrain[0].length*0.4)+Value1#/2
				if Y>MaxDirt and Y<=MaxGrass
					World.Terrain[X,Y,Z].BlockType=1
				elseif Y>MaxStone and Y<=MaxDirt
					World.Terrain[X,Y,Z].BlockType=3
				elseif Y<=MaxStone
					World.Terrain[X,Y,Z].BlockType=2
					Value3#=Noise_Perlin3(X/freq3#,Y/freq3#,Z/freq3#)
					if Value3#>0.68 then World.Terrain[X,Y,Z].BlockType=4
				endif
				if Value2#>0.5 then World.Terrain[X,Y,Z].BlockType=0
				World.Terrain[X,Y,Z].LightValue=15
				//local string$ as string
				//string$ = World.Terrain[X,Y,Z].toJSON()
				//Voxel_Logger_Log("LOAD", VOXEL_INFO, Str(Z) + string$)
			next Z
		next Y
	next X
	
	/*
	for ChunkX=0 to World.Chunk.length
		for ChunkY=0 to World.Chunk[0].length
			for ChunkZ=0 to World.Chunk[0,0].length
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.X=ChunkX*Voxel_ChunkSize+1
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Y=ChunkY*Voxel_ChunkSize+1
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Min.Z=ChunkZ*Voxel_ChunkSize+1
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.X=ChunkX*Voxel_ChunkSize+Voxel_ChunkSize
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Y=ChunkY*Voxel_ChunkSize+Voxel_ChunkSize
				World.Chunk[ChunkX,ChunkY,ChunkZ].Border.Max.Z=ChunkZ*Voxel_ChunkSize+Voxel_ChunkSize
	//~			Voxel_UpdateLight(World.Chunk[ChunkX,ChunkY,ChunkZ],World)
				Voxel_CreateObject(Faceimages,World.Chunk[ChunkX,ChunkY,ChunkZ],World)
			next ChunkZ
		next ChunkY
	next ChunkX
	*/
	
	Voxel_Logger_Stop() // Check the time elapsed and closes the file
	
endfunction