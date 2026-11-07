class_name AchievementView
extends RefCounted
## Как показывать достижение (М17): иконка из UI-кита и текст описания. Правил здесь нет —
## открыто ли и прогресс берутся у Achievements.

## Закрытое достижение — притушенная иконка.
const LOCKED_TINT := Color(0.35, 0.35, 0.4, 1)


static func icon(id: Achievement.Id) -> Texture2D:
	match id:
		Achievement.Id.FLAWLESS, Achievement.Id.CLEAN_HANDS:
			return Sprites.texture(Sprites.ICON_SANITY)
		Achievement.Id.LIAR_CALL, Achievement.Id.SHARP_EYE, Achievement.Id.HUNTER:
			return Sprites.texture(Sprites.ICON_ACCUSE)
		Achievement.Id.CALZA_HIT:
			return Sprites.texture(Sprites.ICON_EVIDENCE)
		Achievement.Id.FIRST_TRICK:
			return Sprites.trick_icon(Cheat.Kind.SLEIGHT)
		Achievement.Id.TRICKSTER:
			return Sprites.trick_icon(Cheat.Kind.SLEEVE_DIE)
		Achievement.Id.ABYSS_VOICE:
			return Sprites.trick_icon(Cheat.Kind.ABYSS_WHISPER)
		Achievement.Id.INTO_ABYSS, Achievement.Id.MAD_CAPTAIN:
			return Sprites.texture(Sprites.ICON_MADNESS)
	return Sprites.texture(Sprites.ICON_DICE)


## Описание с подставленным числом (и прогрессом «N / M» для счётчиков).
static func description(id: Achievement.Id, progress: int) -> String:
	var text := TranslationServer.translate(Achievement.desc_key(id))
	var arg := Achievement.desc_arg(id)
	if arg >= 0:
		text = text % arg
	var goal := Achievement.goal(id)
	if goal > 1:
		text += " (%d/%d)" % [progress, goal]
	return text
