shader_type spatial;
render_mode specular_disabled;

// A ten-metre grid gives otherwise unbuilt routes a visible sense of motion.
varying vec2 metres;
uniform vec4 paper : source_color = vec4(0.45, 0.53, 0.47, 1.0);
uniform vec4 grid : source_color = vec4(0.38, 0.46, 0.40, 1.0);

void vertex() {
	metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 cell = metres / 10.0;
	vec2 edge = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.0001));
	float line = 1.0 - smoothstep(0.12, 1.25, min(edge.x, edge.y));
	ALBEDO = mix(paper.rgb, grid.rgb, line);
	ROUGHNESS = 1.0;
}
