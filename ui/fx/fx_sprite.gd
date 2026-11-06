class_name FxSprite
extends Sprite2D
## Одноразовый покадровый эффект из листа ui/fx/fx_<имя>.png (М10). Ставится точкой привязки
## (pivot листа) в заданную позицию, проигрывается один раз со скоростью speed и удаляет себя.
##
## Листы собирает tools/build_fx.ps1 (библиотека pixelfx → палитра KrakenPalette),
## их размеры и точки привязки — в сгенерированном ui/fx/fx_sheets.gd.

signal finished

const SHEETS_PATH := "res://ui/fx/fx_sheets.gd"

var effect: StringName
var speed := 1.0
var _fps := 15.0
var _count := 1
var _time := 0.0

static var _sheets: Dictionary = {}
static var _textures: Dictionary = {}


static func has_effect(name: StringName) -> bool:
	return _sheet_table().has(name)


static func names() -> Array:
	return _sheet_table().keys()


static func info(name: StringName) -> Dictionary:
	return _sheet_table()[name]


## Длительность эффекта при скорости 1.
static func duration(name: StringName) -> float:
	var s := info(name)
	return s.count / s.fps


static func make(name: StringName, at: Vector2, play_speed := 1.0) -> FxSprite:
	assert(has_effect(name), "Unknown fx: %s" % name)
	var s := info(name)
	var fx := FxSprite.new()
	fx.effect = name
	fx.speed = maxf(play_speed, 0.01)
	fx._fps = s.fps
	fx._count = s.count
	fx.texture = _texture(s.path)
	fx.hframes = s.columns
	fx.vframes = ceili(float(s.count) / s.columns)
	fx.centered = false
	fx.offset = -Vector2(s.pivot)
	fx.position = at.round()
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return fx


func _process(delta: float) -> void:
	advance(delta)


## Продвинуть время (вызывается и из _process, и из тестов).
func advance(delta: float) -> void:
	_time += delta * speed
	var f := int(_time * _fps)
	if f >= _count:
		finished.emit()
		queue_free()
		set_process(false)
		return
	frame = f


func is_finished() -> bool:
	return int(_time * _fps) >= _count


static func _sheet_table() -> Dictionary:
	if not _sheets.has(&"table"):
		_sheets[&"table"] = (load(SHEETS_PATH) as GDScript).SHEETS
	return _sheets[&"table"]


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]
