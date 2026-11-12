class_name HobPortrait
extends RefCounted
## Портрет Старого Хоба — ЗАГЛУШКА М23 (М25 заменит картинкой автора
## «новые портреты/bartender.webp»): грузный силуэт, борода с водорослями, мутные глаза
## без зрачков, кружка в руке. Рисуется по пикселям на палитре, размер — как у портретов.

const SKIN := Color8(0x6e, 0x6a, 0x5c)
const SHADE := Color8(0x3a, 0x34, 0x30)
const COAT := Color8(0x2a, 0x24, 0x2c)
const BEARD := Color8(0x3c, 0x5a, 0x3a)
const WEED := Color8(0x5e, 0x84, 0x4a)
const EYE := Color8(0xc8, 0xd4, 0xd0)
const MUG := Color8(0x8a, 0x64, 0x3a)
const MUG_DARK := Color8(0x5a, 0x3e, 0x24)

static var _texture: ImageTexture


static func texture() -> Texture2D:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_draw())
	return _texture


static func _draw() -> Image:
	var s := Sprites.PORTRAIT_SIZE
	var img := Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Плечи и тулово — широкая трапеция.
	for y in range(40, s.y):
		var half := 14 + (y - 40)
		for x in range(maxi(0, 32 - half), mini(s.x, 32 + half)):
			img.set_pixel(x, y, COAT)
	# Голова.
	_ellipse(img, Vector2i(32, 24), Vector2i(13, 15), SKIN)
	_ellipse(img, Vector2i(32, 12), Vector2i(12, 5), SHADE)
	# Борода с водорослями.
	for y in range(28, 50):
		var half := 12 - absi(y - 36) / 3
		for x in range(32 - half, 32 + half):
			img.set_pixel(x, y, WEED if (x * 7 + y * 3) % 5 == 0 else BEARD)
	for i in 4:
		var x := 22 + i * 6
		for y in range(48, 54 + i % 2 * 3):
			img.set_pixel(x, y, WEED)
	# Мутные глаза без зрачков.
	for e in [Vector2i(26, 22), Vector2i(38, 22)]:
		_ellipse(img, e, Vector2i(3, 2), EYE)
	# Кружка в руке.
	for y in range(46, 60):
		for x in range(44, 54):
			img.set_pixel(x, y, MUG if x < 52 else MUG_DARK)
	for y in range(49, 56):
		img.set_pixel(55, y, MUG_DARK)
	return img


static func _ellipse(img: Image, c: Vector2i, r: Vector2i, color: Color) -> void:
	for y in range(c.y - r.y, c.y + r.y + 1):
		for x in range(c.x - r.x, c.x + r.x + 1):
			var dx := float(x - c.x) / r.x
			var dy := float(y - c.y) / r.y
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 \
					and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)
