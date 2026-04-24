shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 grid_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform float grid_size = 40.0;
uniform float line_width = 1.0;

void fragment() {
	vec2 grid = step(line_width, mod(FRAGCOORD.xy, grid_size));
	float line = 1.0 - (grid.x * grid.y);
	COLOR = mix(bg_color, grid_color, line);
}
