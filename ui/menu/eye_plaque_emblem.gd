class_name EyePlaqueEmblem
extends TextureRect
## 3D-эмблема над названием в главном меню: табличка с глазом в кольце щупальца.
## Вся модель медленно поворачивается слева направо, а щупальце, как скакалка, крутится
## вокруг линии, где оно держится за табличку, и перелетает через неё.
## Рендер — в маленький SubViewport, который рисуется 1:1 с nearest-фильтром,
## так 3D получается в том же пиксельном разрешении, что и остальной экран.

const MODEL_PATH := "res://assets/models/eye_plaque.glb"
## Ось вращения всей модели (модель Y-вверх, лицом к +Z): вертикаль,
## положительный угол ведёт лицевую сторону слева направо.
const SPIN_AXIS := Vector3.UP
## Оборот всей модели, секунд.
const SPIN_PERIOD := 6.0
## Оборот «скакалки», секунд.
const ROPE_PERIOD := 1.4
## Высота линии крепления щупальца к табличке (метры, в координатах модели).
const ROPE_AXIS_Y := 0.077
## Центр вращения всей модели — там же: так «скакалка» не вылезает за кадр.
const MODEL_CENTER := Vector3(0, ROPE_AXIS_Y, 0)
## Высота кадра ортокамеры, метры (вмещает модель с размахом щупальца).
const CAMERA_SIZE := 0.16
const CAMERA_DISTANCE := 1.0
const LIGHT_ANGLES := Vector3(-35, -30, 0)
const LIGHT_ENERGY := 1.1
const AMBIENT_COLOR := Color(0.55, 0.5, 0.65)
const AMBIENT_ENERGY := 0.6

var viewport: SubViewport
## Узел, вращающий всю модель.
var spinner: Node3D
## Узел на оси крепления, вращающий щупальце.
var rope: Node3D


func setup(rect: Rect2i) -> EyePlaqueEmblem:
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP
	_build(rect.size)
	return self


func _build(px: Vector2i) -> void:
	viewport = SubViewport.new()
	viewport.size = px
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	texture = viewport.get_texture()

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ANGLES
	light.light_energy = LIGHT_ENERGY
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	camera.far = CAMERA_DISTANCE * 2
	viewport.add_child(camera)

	spinner = Node3D.new()
	viewport.add_child(spinner)
	var scene: PackedScene = load(MODEL_PATH)
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.position = -MODEL_CENTER
	spinner.add_child(model)
	_rig_rope(model)


## Переносит щупальце под узел на оси крепления, сохраняя его положение.
func _rig_rope(model: Node3D) -> void:
	var tentacle := _find_tentacle(model)
	if tentacle == null:
		return
	# Положение щупальца в координатах корня модели (в glb внутри есть масштаб мм → м).
	var keep := tentacle.transform
	var up := tentacle.get_parent() as Node3D
	while up != null and up != model:
		keep = up.transform * keep
		up = up.get_parent() as Node3D
	rope = Node3D.new()
	rope.position = Vector3(0, ROPE_AXIS_Y, 0)
	model.add_child(rope)
	tentacle.owner = null  # иначе Godot предупреждает о несогласованном владельце
	tentacle.get_parent().remove_child(tentacle)
	rope.add_child(tentacle)
	tentacle.transform = rope.transform.affine_inverse() * keep


## Группа щупальца в glb: «tentacle…» с детьми (сама труба, присоски, хвост).
static func _find_tentacle(model: Node) -> Node3D:
	for n in model.find_children("tentacle*", "Node3D", true, false):
		if n.get_child_count() > 1:
			return n as Node3D
	return null


func _process(delta: float) -> void:
	if spinner != null:
		spinner.rotate(SPIN_AXIS, TAU * delta / SPIN_PERIOD)
	if rope != null:
		rope.rotate_x(TAU * delta / ROPE_PERIOD)
