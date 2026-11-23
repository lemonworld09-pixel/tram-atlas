shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// A shallow-water border and short engraved marks keep the river in the
// same matte, model-making palette as the buildings and bridge.
uniform vec4 deep_water : source_color = vec4(0.274, 0.533, 0.556, 1.0);
uniform vec4 shallows : source_color = vec4(0.450, 0.650, 0.605, 1.0);
uniform vec4 glint : source_color = vec4(0.610, 0.755, 0.700, 1.0);
varying vec2 chart;

void vertex() {
	chart = VERTEX.xz;
}

void fragment() {
	float bank_distance = min(chart.x - (84.0 - chart.y * 0.07),
			(446.0 + chart.y * 0.07) - chart.x);
	float island_width = mix(30.0, 8.0, smoothstep(58.0, 155.0, chart.y));
	float island_edge = abs(chart.x - (298.0 + 5.0 * sin(chart.y * 0.015))) - island_width;
	float island_distance = length(vec2(max(0.0, island_edge), max(0.0, chart.y - 148.0)));
	float edge = 1.0 - smoothstep(0.0, 23.0, min(bank_distance, island_distance));
	float current = 0.5 + 0.5 * sin(chart.y * 0.056 + sin(chart.x * 0.082 + chart.y * 0.029) * 1.8);
	vec3 base = mix(deep_water.rgb, shallows.rgb, 0.12 + 0.58 * edge + 0.12 * current);
	float phase = chart.y * 1.17 + 1.65 * sin(chart.x * 0.094) + 0.8 * sin(chart.x * 0.22 + chart.y * 0.08) + TIME * 0.25;
	float wave = sin(phase);
	float thin_stroke = 1.0 - smoothstep(0.03, max(0.16, fwidth(phase)), abs(wave));
	float clusters = smoothstep(0.70, 0.94, sin(chart.x * 0.31 + chart.y * 0.14)
			* sin(chart.x * 0.077 - chart.y * 0.218));
	ALBEDO = mix(base, glint.rgb, thin_stroke * clusters * 0.42);
	ROUGHNESS = 1.0;
}
