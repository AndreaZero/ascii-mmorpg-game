shader_type spatial;
render_mode cull_disabled;
uniform sampler2D glyphs : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 base_color : source_color=vec4(0.5,0.5,0.5,1.0);
uniform float glow=0.0;
uniform int surface_kind=0;
uniform bool ascii_enabled=true;
uniform float glyph_scale=1.0;
varying vec3 local_position;
varying vec3 local_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec3 n=abs(normalize(local_normal));
 vec2 plane=local_position.xy;
 if(n.y>n.x && n.y>n.z) plane=local_position.xz;
 else if(n.x>n.z) plane=local_position.zy;
 vec2 cell=vec2(0.105,0.15)*glyph_scale;
 if(surface_kind==1) cell*=1.35;
 if(surface_kind==2 || surface_kind==3) cell*=0.62;
 vec2 grid=floor(plane/cell);
 vec2 uv=fract(plane/cell);
 float r=hash(grid);
 float code=r<0.2 ? 35.0 : (r<0.5 ? 111.0 : (r<0.8 ? 43.0 : 58.0));
 if(surface_kind==1) code=r<0.4 ? 47.0 : (r<0.8 ? 92.0 : 89.0);
 if(surface_kind==2) code=r<0.65 ? 61.0 : 43.0;
 if(surface_kind==3) code=r<0.6 ? 61.0 : 35.0;
 float idx=code-32.0;
 vec2 atlas_uv=(vec2(mod(idx,16.0),floor(idx/16.0))+uv)/vec2(16.0,6.0);
 float ink=smoothstep(0.08,0.65,texture(glyphs,atlas_uv).a);
 if(surface_kind==1) ink*=step(0.28,r);
 float grain=0.85+hash(grid+vec2(12.0))*0.30;
 float fill=surface_kind==1 ? 0.045 : 0.08;
 ALBEDO=base_color.rgb*grain*(ascii_enabled ? mix(fill,1.35,ink) : 1.0);
 ROUGHNESS=0.95;
 SPECULAR=0.0;
 EMISSION=base_color.rgb*glow*(ascii_enabled ? (ink*0.8+0.18) : 1.0);
}
