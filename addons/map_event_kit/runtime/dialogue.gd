extends CanvasLayer

signal answered(value: int)
var panel: PanelContainer
var speaker: Label
var message: Label
var buttons: HBoxContainer
var active := false
var active_command: Dictionary = {}
var focused_choice := 0

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layer = 90
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142530")
	style.border_color = Color("6ad8b1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	speaker = Label.new()
	speaker.add_theme_color_override("font_color", Color("78e2b9"))
	speaker.add_theme_font_size_override("font_size", 20)
	box.add_child(speaker)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(0, 58)
	message.add_theme_font_size_override("font_size", 22)
	box.add_child(message)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	panel.hide()

func ask(command: Dictionary) -> int:
	active = true
	active_command = command.duplicate(true)
	focused_choice = 0
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	var options: Array = command.get("options", ["继续  ↵"])
	for i in range(options.size()):
		var button := Button.new()
		button.text = str(options[i])
		button.custom_minimum_size = Vector2(140, 42)
		button.pressed.connect(_answer.bind(i))
		button.focus_entered.connect(func(): focused_choice = i)
		buttons.add_child(button)
	refresh_translation()
	panel.show()
	buttons.get_child(0).grab_focus.call_deferred()
	var result: int = await answered
	active = false
	panel.hide()
	return result

func refresh_translation() -> void:
	if not active: return
	speaker.text = get_parent().translate_text(str(active_command.get("speaker", "事件")))
	message.text = get_parent().translate_text(str(active_command.get("text", "")))
	var options: Array = active_command.get("options", ["继续  ↵"])
	for i in range(buttons.get_child_count()):
		buttons.get_child(i).text = get_parent().translate_text(str(options[i]))

func _answer(value: int) -> void:
	if not active: return
	active = false
	answered.emit(value)

func cancel() -> void:
	if active: _answer(-1)
