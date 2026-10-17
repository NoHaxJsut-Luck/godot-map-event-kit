@tool
extends CharacterBody2D

var walking := 0.0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("map_event_player")
	get_node("/root/MapEvents").place_player.call_deferred(self)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var runtime := get_node("/root/MapEvents")
	var direction := Vector2.ZERO
	if not runtime.busy:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direction += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	velocity = direction.limit_length() * 220
	move_and_slide()
	position.x = clampf(position.x, 78, 878)
	position.y = clampf(position.y, 186, 584)
	if direction.length_squared() > 0: walking += delta * 14
	else: walking = 0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 18), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 21, Color(0.02, 0.06, 0.08, 0.5))
	draw_set_transform(Vector2.ZERO)
	var step := sin(walking) * 3
	draw_rect(Rect2(-10, 11 + step, 7, 10), Color("273d50"))
	draw_rect(Rect2(3, 11 - step, 7, 10), Color("273d50"))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -8), Vector2(11, -8), Vector2(17, 15), Vector2(-17, 15)]), Color("84d5cc"))
	draw_rect(Rect2(-3, -7, 6, 21), Color("f2d28a"))
	draw_circle(Vector2(0, -17), 10, Color("ebbe9f"))
	draw_rect(Rect2(-11, -28, 22, 9), Color("354550"))
	draw_circle(Vector2(4, -17), 1.4, Color("243a43"))
