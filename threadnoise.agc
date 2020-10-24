// File: threadnoise.agc
// Created: 20-10-24

function TN_CreateMemblockNoise2D(Frecueny#,X,Y,Width,Height)
	MemblockID=CreateMemblock(4+4*((Width*Height)+Height+1))
	Noise.Write2DNoiseToMemblock(MemblockID,Frecueny#,X,Y,Width,Height)
endfunction MemblockID

function TN_CreateMemblockNoise3D(Frecueny#,X,Y,Z,Width,Height,Depth)
	MemblockID=CreateMemblock(4+4*((Depth*Width*Height)+(Width*Height)+Height+1))
	Noise.Write3DNoiseToMemblock(MemblockID,Frecueny#,X,Y,Z,Width,Height,Depth)
endfunction MemblockID

function TN_WaitForNoise(MemblockID)
	repeat
		Result=GetMemblockInt(MemblockID,0)
	until Result=1
endfunction