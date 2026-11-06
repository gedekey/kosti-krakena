class_name PortraitFx
extends RefCounted
## «Плывущий» портрет в Безумии (М10): шейдер portrait_madness.gdshader на TextureRect с
## AtlasTexture. Область атласа передаётся в шейдер, чтобы сдвиг строк не захватил соседа.

const SHADER := preload("res://ui/fx/portrait_madness.gdshader")


## Включить / выключить эффект на портрете. Вызывать после смены текстуры.
static func apply(rect: TextureRect, mad: bool, phase := 0.0) -> void:
	if not mad:
		rect.material = null
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		rect.material = mat
	mat.set_shader_parameter(&"phase", phase)
	var atlas := rect.texture as AtlasTexture
	if atlas != null and atlas.atlas != null:
		var full := atlas.atlas.get_size()
		var r := atlas.region
		mat.set_shader_parameter(&"region", Vector4(r.position.x / full.x, r.position.y / full.y,
				r.size.x / full.x, r.size.y / full.y))


static func is_applied(rect: TextureRect) -> bool:
	return rect.material is ShaderMaterial \
			and (rect.material as ShaderMaterial).shader == SHADER
