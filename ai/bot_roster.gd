class_name BotRoster
extends RefCounted
## Список персонажей-ботов (DESIGN.md §5). Порядок — как в дизайн-документе.

const PATHS: Array[String] = [
	"res://ai/personalities/scholar.tres",
	"res://ai/personalities/occultist.tres",
	"res://ai/personalities/sailor.tres",
	"res://ai/personalities/witch.tres",
	"res://ai/personalities/plague_cultist.tres",
	"res://ai/personalities/drowned.tres",
	"res://ai/personalities/deep_one.tres",
	"res://ai/personalities/ulits.tres",
	"res://ai/personalities/ichthyander.tres",
	"res://ai/personalities/omen.tres",
	"res://ai/personalities/craber.tres",
	"res://ai/personalities/horror_master.tres",
]


static func all() -> Array[BotPersonality]:
	var out: Array[BotPersonality] = []
	for path in PATHS:
		out.append(load(path) as BotPersonality)
	return out


## Персонаж по id или null.
static func by_id(id: StringName) -> BotPersonality:
	for p in all():
		if p.id == id:
			return p
	return null
