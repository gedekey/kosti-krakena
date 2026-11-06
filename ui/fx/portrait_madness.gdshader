shader_type canvas_item;
// Портрет в Безумии «плывёт» (М10): строки пикселей сдвигаются на целые пиксели волной,
// изредка — рывок-глитч. Цвета не смешиваются, только перестановка пикселей.

// Область портрета в атласе (UV): x, y, ширина, высота — чтобы не захватить соседний портрет.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float amplitude = 1.0;
uniform float glitch_amplitude = 3.0;
// Свой сдвиг фазы, чтобы портреты не плыли синхронно.
uniform float phase = 0.0;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float row = floor((UV.y - region.y) / texel.y);
	float t = TIME + phase;
	// Глитч ~0.2 с каждые 2.5 с.
	float glitch = step(2.3, mod(t, 2.5));
	float amp = amplitude + glitch * glitch_amplitude * step(0.5, fract(row * 0.137 + floor(t * 10.0) * 0.31));
	float shift = floor(sin(row * 0.45 + t * 3.2) * amp + 0.5);
	vec2 uv = UV + vec2(shift * texel.x, 0.0);
	uv.x = clamp(uv.x, region.x + texel.x * 0.5, region.x + region.z - texel.x * 0.5);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
