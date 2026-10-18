@tool
extends Node2D

const DemoLocale = preload("res://demo/localization.gd")
var locale_service: Node
var language_picker: OptionButton
var ui_root: Control
var notice_source := "本演示使用自绘几何图形，无外部游戏素材。"
var notice_args: Array = []

@export_enum("courtyard", "ruins") var region := "courtyard"
var runtime: Node
var state_label: Label
var log_label: Label
var hint: Label
var notice: Label
var log_lines: Array[Dictionary] = []
var save_button: Button
var load_button: Button
var reset_button: Button

func _ready() -> void:
	if Engine.is_editor_hint(): return
	runtime = get_node("/root/MapEvents")
	locale_service = runtime.get_node_or_null("DemoLocale")
	if locale_service == null:
		locale_service = DemoLocale.new()
		locale_service.name = "DemoLocale"
		runtime.add_child(locale_service)
	build_ui()
	locale_service.changed.connect(_language_changed)
	_language_changed()
	runtime.state_changed.connect(update_state)
	runtime.trace.connect(on_trace)
	runtime.busy_changed.connect(func(value): save_button.disabled = value; load_button.disabled = value; reset_button.disabled = value)
	runtime.event_error.connect(func(text): show_notice(text))
	update_state()
	if OS.get_cmdline_user_args().has("--capture-preview"):
		capture_preview.call_deferred()

func capture_preview() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	get_viewport().get_texture().get_image().save_png("res://artifacts/demo.png")
	get_tree().quit()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	ui_root = root
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	add_label(root, "MAP EVENT KIT", Vector2(40, 23), 15, Color("7cd7b5"))
	add_label(root, "地图事件工坊", Vector2(40, 48), 32, Color("f0f4ed"))
	add_label(root, "一个宝箱，一把钥匙，一段由你编排的冒险。", Vector2(42, 96), 17, Color("9caeb8"))
	add_label(root, "0.1.2 / ALPHA", Vector2(1105, 23), 16, Color("d8bc86"))
	var language_bar := HBoxContainer.new()
	language_bar.position = Vector2(954, 72)
	language_bar.size.x = 286
	root.add_child(language_bar)
	var language_label := Label.new()
	set_ui_text(language_label, "语言")
	language_bar.add_child(language_label)
	language_picker = OptionButton.new()
	language_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_picker.custom_minimum_size.y = 38
	for language_name in DemoLocale.NAMES: language_picker.add_item(language_name)
	language_picker.item_selected.connect(_choose_language)
	language_bar.add_child(language_picker)
	add_label(root, "02   静谧遗迹" if region == "ruins" else "01   苔石小院", Vector2(70, 158), 20, Color("dcebdc"))
	var side := PanelContainer.new()
	side.position = Vector2(954, 145)
	side.size = Vector2(286, 474)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14232d")
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	side.add_theme_stylebox_override("panel", style)
	root.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	side.add_child(box)
	var heading := Label.new()
	set_ui_text(heading, "事件观察窗")
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	var subtitle := Label.new()
	set_ui_text(subtitle, "状态随你的选择实时变化")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.modulate = Color("8fa5af")
	box.add_child(subtitle)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 17)
	box.add_child(state_label)
	box.add_child(HSeparator.new())
	var log_title := Label.new()
	set_ui_text(log_title, "最近执行")
	log_title.modulate = Color("e4c18a")
	box.add_child(log_title)
	log_label = Label.new()
	log_label.text = "靠近一个地图事件\n按 E 或回车开始。"
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.max_lines_visible = 7
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(log_label)
	hint = add_label(root, "WASD / 方向键移动     E / 回车交互", Vector2(58, 641), 19, Color("e2e5d9"))
	add_label(root, "先和守门人聊聊，再找到宝箱中的钥匙。", Vector2(58, 674), 17, Color("9dadaf"))
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(954, 636)
	toolbar.add_theme_constant_override("separation", 9)
	root.add_child(toolbar)
	save_button = ui_button(toolbar, "保存", save)
	load_button = ui_button(toolbar, "读取", restore)
	reset_button = ui_button(toolbar, "重置", reset)
	notice = add_label(root, "本演示使用自绘几何图形，无外部游戏素材。", Vector2(40, 750), 15, Color("839ba7"))

func add_label(parent: Node, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var node := Label.new()
	set_ui_text(node, text)
	node.position = pos
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func ui_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	set_ui_text(button, text)
	button.custom_minimum_size = Vector2(88, 42)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func update_state() -> void:
	var opened := false
	for key in runtime.self_switches:
		if "chest_01::A" in key and runtime.self_switches[key]: opened = true
	state_label.text = _t("钥匙开关    %s\n宝箱独立开关    %s\n金币变量    %d\n抵达遗迹    %s") % ["ON" if runtime.switches.get("has_key", false) else "OFF", "ON" if opened else "OFF", int(runtime.variables.get("coins", 0)), _t("是" if runtime.switches.get("visited_ruins", false) else "否")]

func on_trace(event_key: String, index: int, command: Dictionary) -> void:
	var short_name := event_key.get_slice("::", 1)
	log_lines.append({"event":short_name, "index":index + 1, "op":command.get("op", "")})
	while log_lines.size() > 7: log_lines.pop_front()
	_update_log()

func save() -> void:
	var error: Error = runtime.save_game()
	if error == OK: show_notice("已保存：地图、位置、开关、变量和宝箱状态。")
	else: show_notice("保存失败：%s", [error_string(error)])

func restore() -> void:
	var error: Error = runtime.load_game()
	if error == ERR_FILE_NOT_FOUND: show_notice("还没有存档。")
	elif error != OK: show_notice("读取失败：%s", [error_string(error)])

func reset() -> void:
	runtime.reset_state()
	get_tree().change_scene_to_file("res://demo/courtyard.tscn")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or hint == null: return
	if runtime.busy:
		hint.text = _t("事件进行中 · 使用鼠标或方向键 / 回车选择")
		return
	var player := get_node_or_null("Player")
	if not player: return
	var nearest: MEKMapEvent
	var distance := 64.0
	for event in get_tree().get_nodes_in_group("map_event_objects"):
		if event.page_index < 0: continue
		if event.data.pages[event.page_index].get("trigger", "interact") != "interact": continue
		var d: float = event.global_position.distance_to(player.global_position)
		if d < distance: nearest = event; distance = d
	hint.text = _t("E / 回车  ·  ") + _t(nearest.display_name) if nearest else _t("WASD / 方向键移动     E / 回车交互")

func _draw() -> void:
	var ruin := region == "ruins"
	draw_style_box(panel_style(Color("1c343b") if ruin else Color("28453e")), Rect2(40, 145, 880, 474))
	for x in range(18):
		for y in range(9):
			var variation := float((x * 13 + y * 17) % 5) * 0.008
			var color := Color(0.12 + variation, 0.20 + variation, 0.24 + variation) if ruin else Color(0.14 + variation, 0.25 + variation, 0.21 + variation)
			draw_rect(Rect2(52 + x * 48, 166 + y * 48, 46, 46), color)
	draw_rect(Rect2(89, 356, 775, 84), Color("475758") if ruin else Color("7a7962"))
	draw_rect(Rect2(574, 213, 82, 326), Color("475758") if ruin else Color("7a7962"))
	for x in range(15):
		for y in range(2): draw_rect(Rect2(100 + 50 * x, 363 + 34 * y, 45, 29), Color("55676a") if ruin else Color("929078"))
	for i in range(7):
		var x := 105 + i * 112
		if ruin:
			draw_rect(Rect2(x, 210, 27, 58), Color("60767a"))
			draw_rect(Rect2(x - 5, 205, 37, 10), Color("94a3a0"))
		else:
			tree(Vector2(x, 246))
			if i not in [2, 3]: tree(Vector2(x + 12, 546))
	if ruin:
		for i in range(8): draw_circle(Vector2(150 + i * 86, 500 + (i % 2) * 30), 3, Color("6dd8c1"))
	else:
		for i in range(26):
			var pos := Vector2(80 + (i * 197) % 800, 465 + (i * 13) % 90)
			draw_circle(pos, 2, Color("cebd73"))

func tree(pos: Vector2) -> void:
	draw_circle(pos + Vector2(4, 6), 32, Color(0.03, 0.1, 0.1, 0.35))
	draw_rect(Rect2(pos + Vector2(-5, -5), Vector2(10, 30)), Color("69593e"))
	draw_circle(pos + Vector2(0, -15), 29, Color("365e4d"))
	draw_circle(pos + Vector2(-9, -24), 21, Color("477a5e"))
	draw_circle(pos + Vector2(8, -27), 17, Color("518867"))

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = Color("42605c")
	return style


func _t(source: String) -> String:
	return locale_service.text(source)

func set_ui_text(control: Control, source: String) -> void:
	control.set_meta("demo_text", source)
	control.set("text", _t(source))

func _translate_ui(node: Node) -> void:
	if node.has_meta("demo_text"): node.set("text", _t(str(node.get_meta("demo_text"))))
	for child in node.get_children(): _translate_ui(child)

func _language_changed() -> void:
	_translate_ui(ui_root)
	language_picker.set_item_text(0, _t("跟随系统"))
	language_picker.select(DemoLocale.LANGUAGES.find(locale_service.choice))
	update_state()
	_update_log()
	show_notice(notice_source, notice_args)
	_process(0.0)

func _choose_language(index: int) -> void:
	var error: Error = locale_service.set_language(DemoLocale.LANGUAGES[index])
	if error != OK: show_notice("语言偏好保存失败：%s", [error_string(error)])
	if runtime.dialogue.active:
		runtime.dialogue.buttons.get_child(runtime.dialogue.focused_choice).grab_focus.call_deferred()

func show_notice(source: String, args: Array = []) -> void:
	notice_source = source
	notice_args = args
	notice.text = _t(source) if args.is_empty() else _t(source) % args

func _update_log() -> void:
	var lines := PackedStringArray()
	for entry in log_lines:
		lines.append("%s · %02d %s" % [_t(str(DemoLocale.EVENT_NAMES.get(entry.event, entry.event))), entry.index, _t(str(DemoLocale.OPS.get(entry.op, entry.op)))])
	log_label.text = "\n".join(lines) if not lines.is_empty() else _t("靠近一个地图事件\n按 E 或回车开始。")
