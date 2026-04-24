shader_type 3d;

uniform vec3 bg_color : source_color = vec3(0.05, 0.05, 0.08);
uniform vec3 grid_color : source_color = vec3(0.2, 0.2, 0.4);
uniform float grid_size = 1.0;
uniform float line_width = 0.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Usa a posição X e Z do mundo para criar a grade
	vec2 pos = world_pos.xz / grid_size;
	vec2 grid = abs(fract(pos - 0.5) - 0.5) / (fwidth(pos) * line_width);
	float line = min(grid.x, grid.y);
	float mask = 1.0 - clamp(line, 0.0, 1.0);
	
	ALBEDO = mix(bg_color, grid_color, mask);
	
	// Adiciona um pouco de emissão para a grade brilhar levemente
	EMISSION = grid_color * mask * 0.5;
}
