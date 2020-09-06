// Project: AppGameKit-VoxelEngine
// File: json.agc
// Created: 20-08-15

// Default world and terrain files

#constant VOXEL_WORLD_JSON = "world.json"
#constant VOXEL_TERRAIN_JSON = "terrain.json"

/*
 * Load a JSON file
 */
function Voxel_JSON_Load(filename$)
	JSON$ as string = ""
	memBlock as integer
	memBlock = CreateMemblockFromFile(filename$)
	JSON$ = GetMemblockString(Memblock, 0, GetMemblockSize(memBlock))
	DeleteMemblock(memBlock)
endfunction JSON$

/*
 * Save a string into a JSON file
 */
function Voxel_JSON_Save(string$, filename$)
    OpenToWrite(1,filename$,0) 
    WriteString(1,string$)
    CloseFile(1)
endfunction
