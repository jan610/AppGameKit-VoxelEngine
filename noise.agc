type GradType
	x as integer
	y as integer
	z as integer
endtype

function Noise_Init()
	global dim Grads[12] as GradType
	
	Grads[0].x = 1
	Grads[0].y = 1
	Grads[0].z = 0
	
	Grads[1].x = -1
	Grads[1].y = 1
	Grads[1].z = 0
	
	Grads[2].x = 1
	Grads[2].y = -1
	Grads[2].z = 0
	
	Grads[3].x = -1
	Grads[3].y = -1
	Grads[3].z = 0
	
	Grads[4].x = 1
	Grads[4].y = 0
	Grads[4].z = 1
	
	Grads[5].x = -1
	Grads[5].y = 0
	Grads[5].z = 1
	
	Grads[6].x = 1
	Grads[6].y = 0
	Grads[6].z = -1
	
	Grads[7].x = -1
	Grads[7].y = 0
	Grads[7].z = -1
	
	Grads[8].x = 0
	Grads[8].y = 1
	Grads[8].z = 1
	
	Grads[9].x = 0
	Grads[9].y = -1
	Grads[9].z = 1
	
	Grads[10].x = 0
	Grads[10].y = 1
	Grads[10].z = -1
	
	Grads[11].x = 0
	Grads[11].y = -1
	Grads[11].z = -1
	
	global grad3 as GradType[12]
	for T=0 TO 11
		grad3[T] = Grads[T]
	next T
	
	global p as integer[255]
	p = [151,160,137,91,90,15,
	131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
	190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
	88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
	77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
	102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
	135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
	5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
	223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
	129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
	251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
	49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
	138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]
	
	// To remove the need for index wrapping, double the permutation table length
	global perm as float[511]
	global gradP as GradType[511]
endfunction


// This isn't a very good seeding function, but it works ok. It supports 2^16
// different seed values. Write something better if you need more seeds.
function Noise_Seed(seedVal)
	if (seedVal > 0 and seedVal < 1)
		// Scale the seedVal out
		seedVal = seedVal *  65536
	endif
	
	seedVal = floor(seedVal)
	if(seedVal < 256)
		seedVal2 = seedVal << 8
		seedVal = seedVal || seedVal2
	endif
	
	for i = 0 to 255
		if (i && 1) 
			v# = p[i] ^ (seedVal && 255)
		else
			v# = p[i] ^ ((seedVal>>8) && 255)
		endif
		perm[i + 256] = v#
		perm[i] = v#
		gradP[i + 256] = grad3[trunc(mod(v#, 12))]
		gradP[i] = grad3[trunc(mod(v#, 12))]
	next i
endfunction

function Noise_PrintGrad(grad as GradType)
	print("Grad: { x: " + str(grad.x) + ", " + str(grad.y) + ", " + str(grad.z) + " }")
endfunction

// Skewing and unskewing factors for 2, 3, and 4 dimensions
global F2 as float
F2 = 0.5*(sqrt(3)-1)
global G2 as float
G2 = (3-sqrt(3))/6

global F3 as float
F3 = 1.0/3
global G3 as float
G3 = 1.0/6

//Here self is the Grad Type
function Noise_Dot2(self as GradType, x#, y#)
	dot2Val# = ((self.x*x#) + (self.y*y#))
endfunction dot2Val#

//Here self is the Grad Type
function Noise_Dot3(self as GradType, x as float, y as float, z as float)
endfunction ((self.x*x) + (self.y*y) + (self.z*z))

// 2D simplex noise
function Noise_Simplex2(xin as float, yin as float)
	n0 as float 
	n1 as float 
	n2 as float// Noise contributions from the three corners
	// Skew the input space to determine which simplex cell we're in
	s as float
	s = (xin+yin)*F2 // Hairy factor for 2D
	i as float
	i = floor(xin+s)
	j as float
	j = floor(yin+s)
	t as float
	t = (i+j)*G2
	x0 as float
	y0 as float
	x0 = xin-i+t // The x,y distances from the cell origin, unskewed.
	y0 = yin-j+t
	// For the 2D case, the simplex shape is an equilateral triangle.
	// Determine which simplex we are in.
	i1 as float
	j1 as float// Offsets for second (middle) corner of simplex in (i,j) coords
	if(x0>y0) // lower triangle, XY order: (0,0)->(1,0)->(1,1)
		i1=1
		j1=0
	else  // upper triangle, YX order: (0,0)->(0,1)->(1,1)
		i1=0
		j1=1
	endif
	// A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
	// a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
	// c = (3-sqrt(3))/6
	x1 as float
	x2 as float
	y1 as float
	y2 as float
	x1 = x0 - i1 + G2 // Offsets for middle corner in (x,y) unskewed coords
	y1 = y0 - j1 + G2
	x2 = x0 - 1 + 2 * G2 // Offsets for last corner in (x,y) unskewed coords
	y2 = y0 - 1 + 2 * G2
	// Work out the hashed gradient indices of the three simplex corners
	i = i && 255
	j = j && 255
	gi0 as GradType
	gi1 as GradType
	gi2 as GradType
	gi0 = gradP[Floor(i+perm[Floor(j)])]
	gi1 = gradP[Floor(i+i1+perm[Floor(j+j1)])]
	gi2 = gradP[Floor(i+1+perm[Floor(j+1)])]
	
	// Calculate the contribution from the three corners
	t0 as float
	t0 = 0.5 - x0*x0-y0*y0
	
	if(t0<0)
		n0 = 0
	else
		t0 = t0 * t0
		n0 = t0 * t0 * Noise_dot2(gi0, x0, y0)  // (x,y) of grad3 used for 2D gradient
	endif
	
	t1 as float
	t1 = 0.5 - x1*x1-y1*y1
	
	if(t1<0)
		n1 = 0
	else
		t1 = t1 * t1
		n1 = t1 * t1 * Noise_dot2(gi1, x1, y1)
	endif
	
	t2 as float
	t2 = 0.5 - x2*x2-y2*y2
	
	if(t2<0) 
		n2 = 0
	else
		t2 = t2 * t2
		n2 = t2 * t2 * Noise_dot2(gi2, x2, y2)
	endif
	// Add contributions from each corner to get the final noise value.
	// The result is scaled to return values in the interval [-1,1].
endfunction 70 * (n0 + n1 + n2)

function Noise_Simplex3(xin as float, yin as float, zin as float)
	// Noise contributions from the four corners
	n0 as float
	n1 as float
	n2 as float
	n3 as float
	
	// Skew the input space to determine which simplex cell we're in
	s as float
	i as float
	j as float
	k as float
	
	s = (xin+yin+zin)*F3 // Hairy factor for 2D
	i = floor(xin+s)
	j = floor(yin+s)
	k = floor(zin+s)
	
	t as float
	x0 as float
	y0 as float
	z0 as float
	
	t = (i+j+k)*G3
	x0 = xin-i+t // The x,y distances from the cell origin, unskewed.
	y0 = yin-j+t
	z0 = zin-k+t

	// For the 3D case, the simplex shape is a slightly irregular tetrahedron.
	// Determine which simplex we are in.
	
	// Offsets for second corner of simplex in (i,j,k) coords
	i1 as float
	j1 as float
	k1 as float
	
	// Offsets for third corner of simplex in (i,j,k) coords
	i2 as float
	j2 as float
	k2 as float
	
	if(x0 >= y0)
		if(y0 >= z0)
			i1=1
			j1=0
			k1=0
			i2=1
			j2=1
			k2=0
		elseif(x0 >= z0)
			i1=1
			j1=0
			k1=0
			i2=1
			j2=0
			k2=1
		else
			i1=0
			j1=0
			k1=1
			i2=1
			j2=0
			k2=1
		endif
	else
		if(y0 < z0)
			i1=0
			j1=0
			k1=1
			i2=0
			j2=1
			k2=1
		elseif(x0 < z0)
			i1=0
			j1=1
			k1=0
			i2=0
			j2=1
			k2=1
		else
			i1=0
			j1=1
			k1=0
			i2=1
			j2=1
			k2=0
		endif
	endif
	// A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
	// a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
	// a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
	// c = 1/6.
	
	// Offsets for second corner
	x1 as float
	y1 as float
	z1 as float
	x1 = x0 - i1 + G3
	y1 = y0 - j1 + G3
	z1 = z0 - k1 + G3

	// Offsets for third corner
	x2 as float
	y2 as float
	z2 as float
	x2 = x0 - i2 + 2 * G3
	y2 = y0 - j2 + 2 * G3
	z2 = z0 - k2 + 2 * G3
	
	// Offsets for fourth corner
	x3 as float
	y3 as float
	z3 as float
	x3 = x0 - 1 + 3 * G3
	y3 = y0 - 1 + 3 * G3
	z3 = z0 - 1 + 3 * G3

	// Work out the hashed gradient indices of the four simplex corners
	i = i && 255
	j = i && 255
	k = i && 255
	gi0 as GradType
	gi1 as GradType
	gi2 as GradType
	gi3 as GradType

	gi0 = gradP[floor(i+   perm[floor(j+   perm[floor(k   )])])]
	gi1 = gradP[floor(i+i1+perm[floor(j+j1+perm[floor(k+k1)])])]
	gi2 = gradP[floor(i+i2+perm[floor(j+j2+perm[floor(k+k2)])])]
	gi3 = gradP[floor(i+ 1+perm[floor(j+ 1+perm[floor(k+ 1)])])]
	
	// Calculate the contribution from the four corners
	t0 as float
	t0 = 0.6 - (x0*x0) - (y0*y0) - (z0*z0)
	if(t0<0)
		n0 = 0
	else
		t0 = t0 * t0
		n0 = t0 * t0 * Noise_dot3(gi0, x0, y0, z0)  // (x,y) of grad3 used for 2D gradient
	endif
	
	t1 as float
	t1 = 0.6 - (x1*x1) - (y1*y1) - (z1*z1)
	if(t1<0)
		n1 = 0
	else
		t1 = t1 * t1
		n1 = t1 * t1 * Noise_dot3(gi1, x1, y1, z1)
	endif
	
	t2 as float
	t2 = 0.6 - (x2*x2) - (y2*y2) - (z2*z2)
	if(t2<0)
		n2 = 0
	else
		t2 = t2 * t2
		n2 = t2 * t2 * Noise_dot3(gi2, x2, y2, z2)
	endif
	
	t3 as float
	t3 = 0.6 - (x3*x3) - (y3*y3) - (z3*z3)
	if(t3<0)
		n3 = 0
	else
		t3 = t3 * t3
		n3 = t3 * t3 * Noise_dot3(gi3, x3, y3, z3)
	endif
	
	// Add contributions from each corner to get the final noise value.
	// The result is scaled to return values in the interval [-1,1].
endfunction 32 * (n0 + n1 + n2 + n3)

// ##### Perlin noise stuff
function Noise_Fade(t#)
	fadeVal# = t#*t#*t#*(t#*(t#*6.0-15.0)+10.0)
endfunction fadeVal#

// Function to linearly interpolate between a0 and a1
// Weight w should be in the range [0.0, 1.0]
function Noise_Lerp(a0#, a1#, w#)
	lerpVal# = ((1.0 - w#) * a0#) + w# * a1#
endfunction lerpVal#

function Noise_Perlin2(xin#, yin#)
	// Find unit grid cell containing point
	X = trunc(xin#)
	Y = trunc(yin#)
	
	// Get relative xy coordinates of point within that cell
	xin# = xin# - X
	yin# = yin# - Y
	
	// Wrap the integer cells at 255 (smaller integer period can be introduced here)
	X = X && 255
	Y = Y && 255
	
	// Calculate noise contributions from each of the four corners
	n00# = Noise_dot2(gradP[trunc(X+perm[trunc(Y)])], xin#, yin#)
	n01# = Noise_dot2(gradP[trunc(X+perm[trunc(Y+1.0)])], xin#, yin#-1.0)
	n10# = Noise_dot2(gradP[trunc(X+1.0+perm[trunc(Y)])], xin#-1.0, yin#)
	n11# = Noise_dot2(gradP[trunc(X+1.0+perm[trunc(Y+1.0)])], xin#-1.0, yin#-1.0)
	
	// Compute the fade curve value for x
	u# = Noise_Fade(xin#)
	
	// Interpolate the four results
	retValue# = Noise_Lerp(Noise_Lerp(n00#, n10#, u#),Noise_Lerp(n01#, n11#, u#),Noise_Fade(yin#))
endfunction retValue#

function Noise_Perlin3(xin#, yin#, zin#)
	// Find unit grid cell containing point
	X = trunc(xin#)
	Y = trunc(yin#)
	Z = trunc(zin#)
	
	// Get relative xyz coordinates of point within that cell
	xin# = xin# - X
	yin# = yin# - Y
	zin# = zin# - Z
	
	// Wrap the integer cells at 255 (smaller integer period can be introduced here)
	X = X && 255
	Y = Y && 255
	Z = Z && 255
	
	// Calculate noise contributions from each of the eight corners	
	n000# = Noise_dot3(gradP[floor(X+  perm[floor(Y+  perm[floor(Z  )])])], xin#,   yin#,     zin#)
	n001# = Noise_dot3(gradP[floor(X+  perm[floor(Y+  perm[floor(Z+1)])])], xin#,   yin#,   zin#-1)
	n010# = Noise_dot3(gradP[floor(X+  perm[floor(Y+1+perm[floor(Z  )])])], xin#,   yin#-1,   zin#)
	n011# = Noise_dot3(gradP[floor(X+  perm[floor(Y+1+perm[floor(Z+1)])])], xin#,   yin#-1, zin#-1)
	n100# = Noise_dot3(gradP[floor(X+1+perm[floor(Y+  perm[floor(Z  )])])], xin#-1,   yin#,   zin#)
	n101# = Noise_dot3(gradP[floor(X+1+perm[floor(Y+  perm[floor(Z+1)])])], xin#-1,   yin#, zin#-1)
	n110# = Noise_dot3(gradP[floor(X+1+perm[floor(Y+1+perm[floor(Z  )])])], xin#-1, yin#-1,   zin#)
	n111# = Noise_dot3(gradP[floor(X+1+perm[floor(Y+1+perm[floor(Z+1)])])], xin#-1, yin#-1, zin#-1)
	
	// Compute the fade curve value for x, y, z
	u# = Noise_Fade(xin#)
	v# = Noise_Fade(yin#)
	w# = Noise_Fade(zin#)
	
	// Interpolate
	retValue# = Noise_lerp(Noise_lerp(Noise_lerp(n000#, n100#, u#),Noise_lerp(n001#, n101#, u#), w#),Noise_lerp(Noise_lerp(n010#, n110#, u#),Noise_lerp(n011#, n111#, u#), w#),v#)
endfunction retValue#
