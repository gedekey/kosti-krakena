class_name MadnessOverlay
extends ColorRect
## Постоянный эффект Безумия по краям экрана (М10, DESIGN.md §4): виньетка, щупальца, искры
## (шейдер madness_overlay.gdshader). При наступлении — всплеск: щупальца вытягиваются,
## экран заливает сиреневый дизеринг, потом всё оседает до обычного уровня.

const SHADER := preload("res://ui/fx/madness_overlay.gdshader")
## Всплеск при наступлении: пик интенсивности, длительность (сек при скорости 1).
const ONSET_PEAK := 1.7
const ONSET_TIME := 1.6
const ONSET_FLASH := 1.0

var _mat: ShaderMaterial
var _tween: Tween
var _active := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"ink", KrakenPalette.INK)
	_mat.set_shader_parameter(&"rim", KrakenPalette.VIOLET)
	_mat.set_shader_parameter(&"glow", KrakenPalette.LILAC)
	_mat.set_shader_parameter(&"slime", KrakenPalette.GREEN)
	_mat.set_shader_parameter(&"screen_size", Vector2(TableLayout.SCREEN))
	material = _mat
	TableKit.place(self, Rect2i(Vector2i.ZERO, TableLayout.SCREEN))
	_set_levels(0.0, 0.0)
	hide()


func is_active() -> bool:
	return _active


func intensity() -> float:
	return _mat.get_shader_parameter(&"intensity")


## Включить без всплеска (например, после «Реванша» — выключить).
func set_active(active: bool) -> void:
	if _tween != null:
		_tween.kill()
	_active = active
	visible = active
	_set_levels(1.0 if active else 0.0, 0.0)


## Наступление Безумия: всплеск и переход к постоянному эффекту.
func play_onset(speed := 1.0) -> void:
	if _tween != null:
		_tween.kill()
	_active = true
	show()
	_set_levels(0.0, ONSET_FLASH)
	var t := ONSET_TIME / maxf(speed, 0.01)
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_intensity, 0.0, ONSET_PEAK, t * 0.3) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_intensity, ONSET_PEAK, 1.0, t * 0.7).set_delay(t * 0.3) \
			.set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_flash, ONSET_FLASH, 0.0, t * 0.6)


func _set_levels(level: float, flash: float) -> void:
	_set_intensity(level)
	_set_flash(flash)


func _set_intensity(v: float) -> void:
	_mat.set_shader_parameter(&"intensity", v)


func _set_flash(v: float) -> void:
	_mat.set_shader_parameter(&"flash", v)
