class_name TouchUI
extends RefCounted
## Сенсорный интерфейс (М16): на Android мелкие элементы получают увеличенную зону нажатия.
## Рисунок не меняется — спрайт стоит по центру большей невидимой области.
## На ПК режим включается аргументом `-- --touch` (проверка раскладки без телефона).

## Зона нажатия стрелок ◀ ▶ (спрайт 9×12). В 640×360 на телефоне 1 px ≈ 1 dp.
const ARROW_HIT := Vector2i(20, 20)

## Принудительно включить/выключить (тесты); null — по платформе.
static var forced: Variant = null


static func enabled() -> bool:
	if forced != null:
		return forced
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")


## Увеличить зону нажатия кнопки-картинки, не трогая рисунок.
static func enlarge(button: TextureButton, hit: Vector2i) -> void:
	if not enabled():
		return
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	button.custom_minimum_size = Vector2(maxi(hit.x, int(button.custom_minimum_size.x)),
			maxi(hit.y, int(button.custom_minimum_size.y)))
