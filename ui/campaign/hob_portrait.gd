class_name HobPortrait
extends RefCounted
## Портрет Старого Хоба (М25): картинка автора «новые портреты/bartender.webp», белый фон
## вырезан, кадр «по плечи», 64×64 в палитре игры (tools/cut_hob_portrait.py).
## Чтобы заменить — положите свой hob_normal.png того же размера и пересоберите скриптом.

const PATH := "res://assets/generated/portraits/hob_normal.png"


static var _texture: Texture2D


## Кэш нужен: в _draw() без ссылки текстура освобождается сразу после отрисовки.
static func texture() -> Texture2D:
	if _texture == null:
		_texture = load(PATH) as Texture2D
	return _texture
