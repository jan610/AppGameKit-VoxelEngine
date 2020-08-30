// File: greedymeshing.agc
// Created: 20-08-30

type Vec3Data
	X#
	Y#
	Z#
endtype

type WorldData
	Terrain as TerrainData[0,0,0]
	Chunk as ChunkData[0,0,0]
endtype

type TerrainData
	BlockType as integer
	LightValue as integer
endtype
  
World as WorldData

global dims as Integer[3] // size of volume
 dims[0] = 16
 dims[1] = 16
 dims[2] = 16

#constant dims0 = 16
#constant dims1 = 16
#constant dims2 = 16

global volume as integer[dims0,dims1, dims2] // chunk cube data, 0 means empty cube

#constant false = 0
#constant true = 1

Function greedy()

	
	//Sweep over 3-axes (do it for each dimension seperatly)
	for d = 0 to 2
		u = mod((d + 1),3) // the other axis
		v = mod((d + 2),3)

		//x = [0, 0, 0] // current world position
		x as integer[3]

		// current axis direction
		q as integer[3]
		q[d] = 1

    //		mask  as integer[dims[u] * dims[v]] // is perpendicular to current axis
    // size = dims0 * dims1
    mask as TerrainData[size] // --> works only if all dims are the same length
		// 2d slice of blocks
		// array of bools -> true face visible in at current slice x[d]
		// 					false no face visible


		// each position has 2 faces, thats why we start at -1
		x[d] = -1
		while  x[d] < dims[d]
			//Compute mask (2d slice)
			 maskIndex = 0 // current mask index

			x[v] = 0
			while  x[v] < dims[v]
				x[u] = 0
				while x[u] < dims[u] 

					// is there a face visible in the current plane
					// trinary operator safeguards bounds 

					voxelFace as TerrainData
					voxelFace1 as TerrainData
						
					if 0 <= x[d]
						voxelFace = World.Terrain[x[0], x[1], x[2]]
					endif
					
					if x[d] < dims[d] - 1 
						voxelFace1 = World.Terrain[x[0] + q[0], x[1] + q[1], x[2] + q[2]]
					endif
            
				  if voxelFace1.BlockType = voxelFace.BlockType
            if backFace
            	mask[maskIndex] = voxelFace1
            else
            	mask[maskIndex] = voxelFace
						endif	
				  endif
          maskIndex=maskIndex+1
					
					inc x[u]
				endwhile
				inc x[v]
			endwhile

			//Increment x[d] WHY? because it starts at -1
			inc x[d]

			//Generate mesh for mask using lexicographic ordering
			maskIndex = 0 // current mask index
			for j = 0 to dims[v]-1
				for i = 0 to dims[u] -1
					if mask[maskIndex] 

						w = 1 
						h = 1 // current pos in mask, size in mask
						// 2d greedy algorithm
            
							//Compute width
              while ((i + w < dims[u]) AND (mask[maskIndex + w].BlockType > 0) AND (mask[maskIndex + w].BlockType = mask[maskIndex].BlockType))
									inc w
							endwhile
							//Compute height (this is slightly awkward
							done = false
							while j + h < dims[v] 
								for k = 0 to w-1                  
									if mask[maskIndex + k + h * dims[u]] > 0 OR mask[maskIndex + k + h * dims[u]].BlockType = mask[maskIndex].BlockType
										done = true
										exit
									endif
								next
								if done then exit
								inc h
							endwhile
						
              x[u] = i
              x[v] = j

							du as integer[2]
              du[0] = 0
              du[1] = 0
              du[2] = 0
              du[u] = w
							
              dv as integer[2]
              dv[0] = 0
              dv[1] = 0
              dv[2] = 0
              dv[v] = h
              
              Voxel_AddFaceToObject(Object,TempSubimages,World,CubeX,CubeY,CubeZ,FaceBack,AO0,AO1,AO2,AO3)
              
              quad(Object, new Vector3f(x[0],                 x[1],                   x[2]), 
                   new Vector3f(x[0] + du[0],         x[1] + du[1],           x[2] + du[2]), 
                   new Vector3f(x[0] + du[0] + dv[0], x[1] + du[1] + dv[1],   x[2] + du[2] + dv[2]), 
                   new Vector3f(x[0] + dv[0],         x[1] + dv[1],           x[2] + dv[2]), 
                   w,
                   h,
                   mask[n],
                   backFace);
              //Zero-out mask
              for l = 0 to  h -1
                for k = 0 to  w-1
                  mask[maskIndex + k + l * dims[u]].BlockType = 0
                next
              next
              // Increment counters and continue
              i = i + w
              maskIndex = maskIndex + w
            else 
              inc i
              inc maskIndex
            endif
    			next
    		next
    endwhile
  Next


EndFunction

function quad(bottomLeft as Vec3Data, topLeft bottomLeft as Vec3Data, topRight bottomLeft as Vec3Data, bottomRight bottomLeft as Vec3Data, width as integer, height as integer, voxel as TerrainData, backFace)
{
			TempVertex as VertexData[3]

			Voxel_SetObjectFacePosition(TempVertex[0],bottomLeft.x,bottomLeft.y,bottomLeft.z)
			Voxel_SetObjectFacePosition(TempVertex[1],bottomRight.x,bottomRight.y,bottomRight.z)
			Voxel_SetObjectFacePosition(TempVertex[2],topLeft.x,topLeft.y,topLeft.z)
			Voxel_SetObjectFacePosition(TempVertex[3],topRight.x,topRight.y,topRight.z)
        
        final int [] indexes = backFace ? new int[] { 2,0,1, 1,3,2 } : new int[]{ 2,3,1, 1,0,2 };
        
        final float[] colorArray = new float[4*4];
        
        for (int i = 0; i < colorArray.length; i+=4) {
        
            /*
             * Here I set different colors for quads depending on the "type" attribute, just 
             * so that the different groups of voxels can be clearly seen.
             * 
             */
            if (voxel.type == 1) {
                
                colorArray[i]   = 1.0f;
                colorArray[i+1] = 0.0f;
                colorArray[i+2] = 0.0f;
                colorArray[i+3] = 1.0f;                
                
            } else if (voxel.type == 2) {
                
                colorArray[i]   = 0.0f;
                colorArray[i+1] = 1.0f;
                colorArray[i+2] = 0.0f;
                colorArray[i+3] = 1.0f;
                
            } else {
            
                colorArray[i]   = 0.0f;
                colorArray[i+1] = 0.0f;
                colorArray[i+2] = 1.0f;
                colorArray[i+3] = 1.0f;                
            }
        }
        
        Mesh mesh = new Mesh();
        
        mesh.setBuffer(Type.Position, 3, BufferUtils.createFloatBuffer(vertices));
        mesh.setBuffer(Type.Color,    4, colorArray);
        mesh.setBuffer(Type.Index,    3, BufferUtils.createIntBuffer(indexes));
        mesh.updateBound();
        
        Geometry geo = new Geometry("ColoredMesh", mesh);
        Material mat = new Material(assetManager, "Common/MatDefs/Misc/Unshaded.j3md");
        mat.setBoolean("VertexColor", true);

        /*
         * To see the actual rendered quads rather than the wireframe, just comment outthis line.
         */
        mat.getAdditionalRenderState().setWireframe(true);
        
        geo.setMaterial(mat);

        rootNode.attachChild(geo);
    }