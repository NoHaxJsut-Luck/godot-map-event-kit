@tool
class_name MEKMapEvent
extends Node2D

@export var event_id: String = "event_01"
@export var display_name: String = "地图事件"
@export var data: MEKEventData
@export var marker_color := Color("79ddba")
@export var interaction_radius: float = 64.0
var runtime: Node
var page_index := -1
var autorun_done := -1
var valid_identity := true
var previous_touch := false

func identity() -> String:
	var scene_path := ""
	var parent: Node = self
	while parent:
		if not parent.scene_file_path.is_empty(): scene_path = parent.scene_file_path
		parent = parent.get_parent()
	return scene_path + "::" + event_id

func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("map_event_objects")
	runtime = get_node_or_null("/root/MapEvents")
	if runtime == null:
		push_error("Map Event Kit：请启用插件，或添加 MapEvents autoload。")
		return
	if event_id.strip_edges().is_empty():
		valid_identity = false
		runtime.event_error.emit("地图事件缺少 event_id：" + str(get_path()))
	for other in get_tree().get_nodes_in_group("map_event_objects"):
		if other != self and other.identity() == identity():
			valid_identity = false
			other.valid_identity = false
			runtime.event_error.emit("同一场景内 event_id 重复：" + event_id)
	runtime.state_changed.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and is_instance_valid(runtime) and runtime.current_event == self:
		runtime.cancel()

func _refresh() -> void:
	var next: int = runtime.active_page(data, identity())
	if next != page_index:
		autorun_done = -1
		previous_touch = false
	page_index = next
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if runtime == null or not valid_identity or page_index < 0: return
	var trigger: String = data.pages[page_index].get("trigger", "interact")
	var player := get_tree().get_first_node_in_group("map_event_player") as Node2D
	var touching := player != null and global_position.distance_to(player.global_position) < 30
	if not runtime.busy:
		if trigger == "autorun" and autorun_done != page_index:
			autorun_done = page_index
			interact()
		elif trigger == "touch" and touching and not previous_touch:
			interact()
	previous_touch = touching

func _unhandled_input(input: InputEvent) -> void:
	if Engine.is_editor_hint() or runtime == null or runtime.busy or not valid_identity or page_index < 0: return
	if data.pages[page_index].get("trigger", "interact") != "interact": return
	var pressed := input.is_action_pressed("ui_accept")
	if input is InputEventKey: pressed = pressed or (input.pressed and not input.echo and input.physical_keycode == KEY_E)
	if not pressed: return
	var player := get_tree().get_first_node_in_group("map_event_player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > interaction_radius: return
	for other in get_tree().get_nodes_in_group("map_event_objects"):
		if other == self or other.page_index < 0 or not other.valid_identity: continue
		if other.data.pages[other.page_index].get("trigger", "interact") != "interact": continue
		if other.global_position.distance_to(player.global_position) < global_position.distance_to(player.global_position): return
	get_viewport().set_input_as_handled()
	interact()

func interact() -> bool:
	if runtime == null or not valid_identity: return false
	return await runtime.run_event(self)

func _draw() -> void:
	var visual := "marker"
	if data and not data.pages.is_empty():
		visual = str(data.pages[maxi(page_index, 0)].get("visual", "marker"))
	draw_ellipse_shadow()
	match visual:
		"chest", "chest_open":
			draw_rect(Rect2(-23, -17, 46, 33), Color("926138"))
			draw_rect(Rect2(-23, -17, 46, 11), Color("d8ad65"))
			draw_rect(Rect2(-19, -4, 38, 16), Color("503e30"))
			if visual == "chest": draw_rect(Rect2(-4, -9, 8, 18), Color("f6d68b"))
			else: draw_rect(Rect2(-20, -10, 40, 13), Color("172631"))
		"npc":
			draw_circle(Vector2(0, -20), 11, Color("efc59c"))
			draw_rect(Rect2(-12, -9, 24, 27), marker_color)
			draw_rect(Rect2(-14, -33, 28, 10), Color("475d62"))
		"door", "portal":
			draw_rect(Rect2(-27, -45, 54, 65), Color("536b70"))
			draw_rect(Rect2(-20, -38, 40, 58), Color("1b303a"))
			draw_rect(Rect2(-15, -32, 30, 45), marker_color.darkened(0.35))
			draw_circle(Vector2(9, -4), 3, Color("ffce80"))
		_:
			draw_rect(Rect2(-3, -8, 6, 30), Color("8b7450"))
			draw_rect(Rect2(-24, -29, 48, 28), marker_color.darkened(0.3))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(-width / 2, 44), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e1ece4"))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 19), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 28, Color(0.02, 0.08, 0.1, 0.4))
	draw_set_transform(Vector2.ZERO)
