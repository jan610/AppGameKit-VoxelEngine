attribute highp vec3 position;
attribute mediump vec3 normal;
attribute mediump vec2 uv;
attribute mediump vec4 color;

varying highp vec3 posVarying;
//~varying mediump vec3 normalVarying;
varying mediump vec2 uvVarying;
//~varying mediump vec3 lightVarying;
varying highp vec4 colorVarying;

uniform highp mat3 agk_WorldNormal;
uniform highp mat4 agk_World;
uniform highp mat4 agk_ViewProj;
//~uniform mediump vec4 uvBounds0;

uniform float agk_time;
uniform float waveFrequency;
uniform float waveAmplitude;
uniform vec2 waveOffset;

//~mediump vec3 GetVSLighting( mediump vec3 normal, highp vec3 pos );

void main()
{
    uvVarying = uv; // * uvBounds0.xy + uvBounds0.zw;
    highp vec4 pos = agk_World * vec4(position,1.0);
    mediump vec3 norm = normalize(agk_WorldNormal * normal);
 	pos.z -= norm.z * 0.0001;
 	pos.x -= norm.x * 0.0001;
 	
//~ 	if (uvVarying.y < uvVarying.y || norm.y > 0.5)
//~ 	{
		pos.y += (sin(agk_time * waveFrequency + pos.x) * waveAmplitude) - waveAmplitude;
		pos.y += (cos(agk_time * waveFrequency + pos.z) * waveAmplitude) - waveAmplitude;
//~	}
    
    gl_Position = agk_ViewProj * pos;
   
    posVarying = pos.xyz;
//~    normalVarying = norm;
//~    lightVarying = GetVSLighting( norm, posVarying );
	colorVarying = color;
}