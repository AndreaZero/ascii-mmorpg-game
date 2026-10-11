shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D reflection_map : filter_linear, repeat_disable;
uniform vec2 actor = vec2(-3.0,2.0);
uniform sampler2D glyphs : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool ascii_enabled=true;
uniform float glyph_scale=1.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float waves=sin(world.z*14.0+sin(world.x*3.0+TIME)*1.2+TIME*1.1);
	vec2 distortion=vec2(sin(world.z*19.0+TIME*1.2),cos(world.x*12.0-TIME))*0.0018;
	// Viewport color arrives encoded: decode before using it in a spatial material.
	vec3 reflected=pow(texture(reflection_map,SCREEN_UV+distortion).rgb,vec3(2.2));
	float dist=length(world.xz-actor);
	float ripples=pow(max(0.0,sin(dist*20.0-TIME*3.5)),22.0)*exp(-dist*0.65);
	float glints=pow(max(0.0,waves),28.0)*0.042;
	vec2 cell=world.xz/(vec2(0.18,0.22)*glyph_scale);
	float code=45.0-32.0;
	vec2 atlas_uv=(vec2(mod(code,16.0),floor(code/16.0))+fract(cell))/vec2(16.0,6.0);
	float ink=texture(glyphs,atlas_uv).a;
	float marks=step(0.65,sin(world.z*3.0+world.x*0.9))*ink;
	ALBEDO=vec3(0.001,0.0012,0.003)+reflected*0.80+vec3(0.025,0.05,0.065)*(glints+ripples*0.45)*(ascii_enabled ? ink : 1.0)+vec3(0.0015,0.004,0.007)*marks;
}
