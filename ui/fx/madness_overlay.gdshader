shader_type canvas_item;
// Безумие по краям экрана (М10, DESIGN.md §4): дизеринговая виньетка, шевелящиеся щупальца
// и мерцающие искры. Рисует по пикселям экрана 640×360 (вьюпорт в этом разрешении), только
// цветами палитры: дизеринг Байера вместо полупрозрачности.

uniform vec2 screen_size = vec2(640.0, 360.0);
// 0 — нет эффекта, 1 — обычное Безумие, больше — всплеск при наступлении.
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
// Вспышка при наступлении (0..1): дизеринговая сиреневая пелена по всему экрану.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.051, 0.043, 0.078, 1.0);
uniform vec4 rim : source_color = vec4(0.42, 0.247, 0.651, 1.0);
uniform vec4 glow : source_color = vec4(0.71, 0.482, 1.0, 1.0);
uniform vec4 slime : source_color = vec4(0.247, 0.651, 0.42, 1.0);
// Глубина виньетки и длина щупалец, пикселей (при intensity = 1).
uniform float vignette_depth = 22.0;
uniform float tentacle_min = 16.0;
uniform float tentacle_max = 42.0;
uniform float tentacle_count = 16.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 p) {
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	return (BAYER[i] + 0.5) / 16.0;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * screen_size);
	float W = screen_size.x;
	float H = screen_size.y;
	// Расстояние до ближайшего края и координата вдоль периметра.
	float dl = px.x, dr = W - 1.0 - px.x, dt = px.y, db = H - 1.0 - px.y;
	float e = min(min(dl, dr), min(dt, db));
	float s;
	if (e == dt) s = px.x;
	else if (e == dr) s = W + px.y;
	else if (e == db) s = W + H + (W - px.x);
	else s = 2.0 * W + H + (H - px.y);
	float perimeter = 2.0 * (W + H);
	float spacing = perimeter / tentacle_count;

	vec4 col = vec4(0.0);
	float k_int = clamp(intensity, 0.0, 2.0);

	// Виньетка: чем ближе к краю, тем гуще дизеринг чернил.
	float v = 1.0 - e / (vignette_depth * max(k_int, 0.001));
	if (k_int > 0.0 && v > 0.0) {
		float d = bayer(px);
		if (v * 0.9 > d) {
			col = ink;
		}
	}

	// Щупальца: по одному на отрезок периметра, качаются и «дышат».
	float k0 = floor(s / spacing);
	for (float j = -1.0; j <= 1.0; j += 1.0) {
		float k = mod(k0 + j + tentacle_count, tentacle_count);
		float base = (k0 + j + 0.5 + (hash(k) - 0.5) * 0.6) * spacing;
		float u = s - base;
		float breath = 0.7 + 0.3 * sin(TIME * (0.6 + hash(k + 3.0) * 0.8) + k * 2.3);
		float len = mix(tentacle_min, tentacle_max, hash(k + 7.0)) * breath * k_int;
		if (len <= 1.0 || e >= len) continue;
		float t = e / len;
		float sway = sin(e * 0.09 - TIME * (1.4 + hash(k) * 1.2) + k * 1.7) * (1.0 + e * 0.2);
		float width = mix(5.5, 0.8, t);
		float rel = u - floor(sway + 0.5);
		float dist = abs(rel);
		if (dist < width) {
			// Тело фиолетовое, светлая полоса с одной стороны, присоски — по другой.
			bool lit = rel > width * 0.35;
			bool sucker = rel < -width * 0.2 && rel > -width * 0.8
					&& mod(e + floor(k * 3.0), 4.0) < 1.0 && t < 0.85;
			col = vec4((lit || sucker) ? glow.rgb : rim.rgb, 1.0);
		} else if (dist < width + 1.0) {
			col = ink;
		}
	}

	// Мерцающие искры у краёв.
	float sparkle = hash2(px + floor(TIME * 7.0) * 13.0);
	if (k_int > 0.0 && e < vignette_depth * 1.3 * k_int && sparkle < 0.002 * k_int) {
		col = vec4(mix(glow.rgb, slime.rgb, step(0.5, hash2(px * 0.37))), 1.0);
	}

	// Вспышка наступления.
	if (flash > 0.0 && col.a == 0.0 && flash * 0.6 > bayer(px + vec2(2.0, 1.0))) {
		col = vec4(rim.rgb, 1.0);
	}
	COLOR = col;
}
