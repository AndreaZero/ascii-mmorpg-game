shader_type canvas_item;
render_mode unshaded;
// Glyphs originate in the world; this pass only grades the image.
uniform bool enabled = true;
uniform float cell_size = 6.0;
void fragment(){
 vec3 color=texture(TEXTURE,UV).rgb;
 float vignette=1.0-smoothstep(0.3,0.79,length((UV-0.5)*vec2(1.0,1.12)))*0.45;
 COLOR=vec4(color*vignette,1.0);
}