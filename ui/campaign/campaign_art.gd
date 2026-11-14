class_name CampaignArt
extends RefCounted
## Арт кампании (М25): pxl и слои ImageGen из art/campaign_imagegen/.
## assets/generated/campaign/ содержит готовые размеры; катсцены используют расширенную палитру.
## Слайды: фон 640×260 + спрайты и анимации (полоски кадров по горизонтали).

const DIR := "res://assets/generated/campaign/"
const MAP := &"campaign_map"

## Анимации: имя → число кадров в полоске (как frames в art/campaign.px.js).
const ANIM_FRAMES := {&"slide_waves": 4, &"slide_surf": 4, &"slide_eye": 8}
## Кадров в секунду (как fps в art/campaign.px.js).
const ANIM_FPS := {&"slide_waves": 5.0, &"slide_surf": 4.0, &"slide_eye": 6.0}

## Кэш: draw_texture() в _draw() держит только RID, и без ссылки загруженная текстура
## освобождается сразу после отрисовки (рисуется белым).
static var _textures := {}
static var _frames := {}


static func path(name: StringName) -> String:
	return DIR + String(name) + ".png"


static func texture(name: StringName) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(path(name)) as Texture2D
	return _textures[name]


static func has(name: StringName) -> bool:
	return ResourceLoader.exists(path(name))


## Кадр анимации по времени t (секунды). loop = false — последний кадр держится.
static func anim_frame(name: StringName, t: float, loop := true) -> AtlasTexture:
	var count: int = ANIM_FRAMES[name]
	var i := int(t * ANIM_FPS[name])
	i = i % count if loop else mini(i, count - 1)
	return frame(name, i)


static func frame(name: StringName, index: int) -> AtlasTexture:
	var key := "%s:%d" % [name, index]
	if not _frames.has(key):
		var strip := texture(name)
		var w := strip.get_width() / int(ANIM_FRAMES[name])
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(w * index, 0, w, strip.get_height())
		_frames[key] = atlas
	return _frames[key]
