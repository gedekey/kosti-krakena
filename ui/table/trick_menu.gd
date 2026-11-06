class_name TrickMenu
extends ChoicePanel
## Меню трюков (М9): список трюков с ценой в Рассудке и риском, затем выбор цели
## (сосед, кубик, грань — что нужно по Cheat.target). Доступность — из PlayerView и
## MatchController.cheat_denial; правил здесь нет.

signal cheat_chosen(action: CheatAction)

enum Step { LIST, NEIGHBOR, DIE, FACE }

var _view: PlayerView
var _names: Callable          # func(id: int) -> String
var _denial: Callable         # func(action: CheatAction) -> CheatRules.Denied
var _step := Step.LIST
var _kind: Cheat.Kind
var _target := CheatAction.NONE


func _ready() -> void:
	super._ready()
	picked.connect(_on_picked)


## names(id) — имя игрока, denial(action) — причина отказа контроллера.
func open_for(view: PlayerView, names: Callable, denial: Callable) -> void:
	_view = view
	_names = names
	_denial = denial
	_show_list()


func step() -> Step:
	return _step


func _show_list() -> void:
	_step = Step.LIST
	var choices: Array[ChoicePanel.Choice] = []
	for kind in Cheat.ALL:
		var text := tr("TABLE_TRICK_OPTION") % [tr(Cheat.name_key(kind)), Cheat.cost(kind),
				roundi(Cheat.risk(kind) * 100.0)]
		var c := ChoicePanel.Choice.new(text, kind, Sprites.trick_icon(kind), _available(kind))
		c.tooltip = Cheat.name_key(kind) + "_HINT"
		choices.append(c)
	var footer := tr("TABLE_TRICKS_FOOTER") % _view.own_sanity
	if _view.is_mad():
		footer = tr("TABLE_TRICKS_MAD")
	elif _view.cheat_used:
		footer = tr("TABLE_TRICKS_USED")
	open(tr("TABLE_TRICKS_TITLE"), choices, 1, footer)


func _available(kind: Cheat.Kind) -> bool:
	if not _view.can_afford_cheat(kind):
		return false
	return not Cheat.targets_neighbor(kind) or not _view.neighbors().is_empty()


func _on_picked(value: Variant) -> void:
	match _step:
		Step.LIST:
			_kind = value as Cheat.Kind
			_target = CheatAction.NONE
			match Cheat.target(_kind):
				Cheat.Target.NONE:
					_finish(CheatAction.sleeve_die())
				Cheat.Target.OWN_DIE:
					_show_dice(_view.player_id)
				Cheat.Target.NEIGHBOR, Cheat.Target.NEIGHBOR_DIE:
					_show_neighbors()
				Cheat.Target.FACE:
					_show_faces()
		Step.NEIGHBOR:
			_target = int(value)
			if Cheat.target(_kind) == Cheat.Target.NEIGHBOR:
				_finish(CheatAction.nudge_cup(_target))
			else:
				_show_dice(_target)
		Step.DIE:
			var die := int(value)
			if _kind == Cheat.Kind.PEEK:
				_finish(CheatAction.peek(_target, die))
			else:
				_finish(CheatAction.sleight(die))
		Step.FACE:
			var face := int(value)
			if _kind == Cheat.Kind.LOADED_DIE:
				_finish(CheatAction.loaded_die(face))
			else:
				_finish(CheatAction.abyss_whisper(face))


func _show_neighbors() -> void:
	_step = Step.NEIGHBOR
	var choices: Array[ChoicePanel.Choice] = []
	for id in _view.neighbors():
		choices.append(ChoicePanel.Choice.new(_names.call(id), id))
	open(tr("TABLE_PICK_NEIGHBOR") % tr(Cheat.name_key(_kind)), choices, choices.size())


## Свой кубик — с гранью, если чашка открыта; кубик соседа — только номер.
func _show_dice(owner: int) -> void:
	_step = Step.DIE
	var choices: Array[ChoicePanel.Choice] = []
	var own := owner == _view.player_id
	for i in _view.dice_counts[owner]:
		var icon: Texture2D = null
		if own and _view.cup_open and i < _view.own_dice.size():
			icon = Sprites.die(TableKit.DICE_SET, _view.own_dice[i])
		var action := CheatAction.sleight(i) if own else CheatAction.peek(owner, i)
		var ok: bool = _denial.call(action) == CheatRules.Denied.OK
		choices.append(ChoicePanel.Choice.new(tr("TABLE_DIE_NUMBER") % (i + 1), i, icon, ok))
	open(tr("TABLE_PICK_DIE") % tr(Cheat.name_key(_kind)), choices, mini(choices.size(), 5))


func _show_faces() -> void:
	_step = Step.FACE
	var choices: Array[ChoicePanel.Choice] = []
	for face in range(1, PerudoRules.FACES + 1):
		choices.append(ChoicePanel.Choice.new("", face, Sprites.die(TableKit.DICE_SET, face)))
	open(tr("TABLE_PICK_FACE") % tr(Cheat.name_key(_kind)), choices, PerudoRules.FACES)


func _finish(action: CheatAction) -> void:
	hide()
	cheat_chosen.emit(action)
