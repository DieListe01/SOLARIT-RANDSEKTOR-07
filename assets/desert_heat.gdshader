shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	// Subtle warm-air refraction, confined to the world viewport, never the HUD.
	float band=smoothstep(0.15,0.85,SCREEN_UV.y);
	vec2 shimmer=vec2(sin(SCREEN_UV.y*180.0+TIME*2.4),sin(SCREEN_UV.x*130.0+TIME*1.8))*0.00035*band;
	COLOR=vec4(texture(screen_texture,SCREEN_UV+shimmer).rgb,1.0);
}
