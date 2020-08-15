// Project: AppGameKit-VoxelEngine
// File: json.agc
// Created: 20-08-15


/*
 * Loads a JSON file
 */
function Voxel_JSON_Load( filename$ )
	JSON$ as string = ""
	memBlock as integer
	memBlock = CreateMemblockFromFile( filename$ )
	JSON$ = GetMemblockString( Memblock, 0, GetMemblockSize( memBlock ) )
	DeleteMemblock(memBlock)
endfunction JSON$

/*
 * Saves a string into a JSON file
 */
function Voxel_JSON_Save( string$ , filename$)
    OpenToWrite(1,"savegame.json",0) 
    WriteString(1,string$ )
    CloseFile(1)
endfunction
