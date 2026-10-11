shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
varying vec3 world;
varying vec3 normal_world;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;normal_world=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
	float n=noise(world*7.0)*0.55+noise(world*29.0)*0.45;
	float foliage=step(base_color.r*1.2,base_color.g);
	float detail=mix(0.44,1.45,n);
	vec3 color=base_color.rgb*detail;
	float moss=smoothstep(0.48,0.75,noise(world*2.5))*max(0.0,normal_world.y);
	color=mix(color,vec3(0.075,0.13,0.055),moss*0.6*(1.0-foliage));
	ALBEDO=color;
	ROUGHNESS=0.95;
}
