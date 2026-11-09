class_name RankBadge
extends HBoxContainer
## Значок ранга (М20, DESIGN.md §8в): иконка, название ранга и Слава «85 / 200».
## Иконки — ui/sprites/ranks/ (вырезаны tools/cut_rank_icons.py из картинки автора).

const ICON_DIR := "res://ui/sprites/ranks/"
const SMALL := 32
const BIG := 64

var icon: TextureRect
var title_label: Label
var glory_label: Label
var _caption: Label


## caption_key — подпись над названием («Одиночный ранг»), пусто — без неё.
func setup(caption_key := "", big := false) -> RankBadge:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = TableKit.icon_rect(texture(RankBalance.Tier.WOOD, big))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	var box := TableKit.vbox(1)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_caption = TableKit.label(caption_key, TableKit.TEXT_MUTED)
	_caption.visible = caption_key != ""
	box.add_child(_caption)
	title_label = TableKit.label("", TableKit.TEXT)
	box.add_child(title_label)
	glory_label = TableKit.label("", TableKit.TEXT_MUTED)
	box.add_child(glory_label)
	return self


func show_rank(tier: RankBalance.Tier, glory: int) -> void:
	icon.texture = texture(tier, icon.texture.get_width() >= BIG)
	title_label.text = tr(RankBalance.name_key(tier))
	glory_label.text = glory_text(tier, glory)


## Ранг игрока в режиме mode (RankTracker.Mode).
func show_mode(mode: RankTracker.Mode) -> void:
	show_rank(Ranks.tier(mode), Ranks.glory(mode))


static func texture(tier: RankBalance.Tier, big := false) -> Texture2D:
	return load(ICON_DIR + "%s_%d.png" % [RankBalance.SAVE_NAMES[tier], BIG if big else SMALL])


static func glory_text(tier: RankBalance.Tier, glory: int) -> String:
	var cap := RankBalance.promote_glory(tier)
	if cap < 0:
		return TranslationServer.translate("RANK_GLORY_TOP") % glory
	return TranslationServer.translate("RANK_GLORY") % [glory, cap]
