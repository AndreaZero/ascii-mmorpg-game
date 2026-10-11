shader_type spatial;
render_mode cull_disabled;
uniform bool ascii_enabled=true;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 cell=world.xz/0.15;
 float r=hash(floor(cell));
 float grain=step(0.967,r)*step(length(fract(cell)-0.5),0.13);
 float path=1.0-smoothstep(0.8,1.8,abs(world.x+2.4+sin(world.z*0.38)*1.2));
 ALBEDO=mix(vec3(0.0004,0.0005,0.0008),vec3(0.0018,0.0014,0.0012),path);
 if(ascii_enabled) ALBEDO+=vec3(0.025,0.03,0.027)*grain;
 ROUGHNESS=1.0;
 SPECULAR=0.0;
 EMISSION=vec3(0.0012,0.0009,0.0024);
}
