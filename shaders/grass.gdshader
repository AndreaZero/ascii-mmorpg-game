shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D glyphs : filter_linear_mipmap, repeat_disable;
uniform bool ascii_enabled=true;
uniform float glyph_scale=1.0;
varying vec4 tint;
varying float glyph_id;
void vertex(){
 vec3 origin=MODEL_MATRIX[3].xyz;
 float sx=length(MODEL_MATRIX[0].xyz);
 float sy=length(MODEL_MATRIX[1].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 VERTEX.xy*=vec2(sx,sy)*pow(glyph_scale,0.6);
 VERTEX.x+=sin(TIME*1.05+origin.x*0.7+origin.z*0.4)*UV.y*0.035;
 tint=COLOR;
 glyph_id=INSTANCE_CUSTOM.x;
}
void fragment(){
 float idx=glyph_id-32.0;
 vec2 atlas_uv=(vec2(mod(idx,16.0),floor(idx/16.0))+vec2(UV.x,1.0-UV.y))/vec2(16.0,6.0);
 float ink=texture(glyphs,atlas_uv).a;
 if(!ascii_enabled) ink=step(abs(UV.x-0.5),0.18*(1.0-UV.y));
 ALPHA=ink;
 ALPHA_SCISSOR_THRESHOLD=0.28;
 ALBEDO=tint.rgb*(0.7+UV.y*0.4);
 NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
