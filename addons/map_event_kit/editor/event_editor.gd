@tool
extends VBoxContainer

const I18n = preload("res://addons/map_event_kit/core/localization.gd")
const Data = preload("res://addons/map_event_kit/core/event_data.gd")
const OPS := ["text", "choices", "set_switch", "set_self_switch", "set_variable", "add_variable", "if_switch", "if_self_switch", "if_variable", "else", "end", "wait", "transfer", "sound", "custom", "stop"]
const LABELS := ["显示文字", "显示选项", "设置全局开关", "设置独立开关", "设置变量", "增加变量", "条件：全局开关", "条件：独立开关", "条件：变量", "否则", "结束分支", "等待", "切换地图", "播放音效", "自定义指令", "结束事件"]
const CONDITIONS := ["always", "switch", "self_switch", "variable"]
const TRIGGERS := ["interact", "touch", "autorun"]
const VISUALS := ["marker", "npc", "chest", "chest_open", "door", "portal"]
const ENUM_LABELS := {"always":"无条件", "switch":"全局开关", "self_switch":"独立开关", "variable":"变量阈值", "interact":"确认键交互", "touch":"靠近触发", "autorun":"自动执行", "marker":"路牌", "npc":"角色", "chest":"关闭的宝箱", "chest_open":"打开的宝箱", "door":"门", "portal":"传送门"}
var plugin: EditorPlugin
var data: MEKEventData
var dirty := false
var dirty_resources: Dictionary = {}
var page_index := 0
var command_index := -1
var pages_list: ItemList
var commands_list: ItemList
var page_form: VBoxContainer
var command_form: VBoxContainer
var location: Label
var status: Label
var command_picker: OptionButton
var page_fields: Dictionary = {}
var command_fields: Dictionary = {}
var open_dialog: EditorFileDialog
var save_dialog: EditorFileDialog
var title_field: LineEdit
var last_diagnostic := ""
var language_choice := "auto"
var language := "en"
var language_picker: OptionButton
var status_source := ""
var status_args: Array = []
var showing_validation := false
var command_heading: Label


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var settings := plugin.get_editor_interface().get_editor_settings()
	language_choice = str(settings.get_project_metadata("map_event_kit", "editor_language", "auto"))
	if language_choice not in I18n.LANGUAGES: language_choice = "auto"
	language = _resolved_language()
	settings.settings_changed.connect(_editor_settings_changed)
	add_theme_constant_override("separation", 12)
	var heading := HBoxContainer.new()
	add_child(heading)
	var name_label := Label.new()
	_set_text(name_label, "地图事件工坊")
	name_label.add_theme_font_size_override("font_size", 25)
	heading.add_child(name_label)
	var badge := Label.new()
	badge.text = "   MAP EVENT KIT   /   0.1.3 ALPHA"
	badge.modulate = Color("80d9b6")
	heading.add_child(badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var language_label := label(heading, "语言")
	language_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	language_picker = OptionButton.new()
	for language_name in I18n.NAMES: language_picker.add_item(language_name)
	language_picker.set_item_text(0, _t("跟随 Godot"))
	language_picker.select(I18n.LANGUAGES.find(language_choice))
	language_picker.item_selected.connect(func(index): set_language(I18n.LANGUAGES[index]))
	heading.add_child(language_picker)
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	button(toolbar, "新建事件", _new)
	button(toolbar, "打开事件…", func(): open_dialog.popup_centered_ratio(0.65))
	button(toolbar, "保存", save_current)
	button(toolbar, "另存为…", func(): save_dialog.popup_centered_ratio(0.65))
	button(toolbar, "撤销", _undo)
	button(toolbar, "重做", _redo)
	button(toolbar, "检查事件", _validate)
	if ResourceLoader.exists("res://demo/events/chest.tres"):
		var samples := MenuButton.new()
		_set_text(samples, "演示事件 ▾")
		toolbar.add_child(samples)
		var sample_labels := ["宝箱 · 两页与独立开关", "守门人 · 选项与分支", "遗迹门 · 钥匙与传送", "返回门 · 跨地图"]
		samples.get_popup().set_meta("mek_labels", sample_labels)
		for source in sample_labels: samples.get_popup().add_item(_t(source))
		samples.get_popup().id_pressed.connect(func(id): _open("res://demo/events/" + ["chest", "guide", "gate", "return"][id] + ".tres"))
	location = Label.new()
	_update_location()
	location.modulate = Color("9baeb8")
	add_child(location)
	var title_row := HBoxContainer.new()
	add_child(title_row)
	var title_label := Label.new()
	_set_text(title_label, "事件名称")
	title_row.add_child(title_label)
	title_field = LineEdit.new()
	title_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_field)
	button(title_row, "应用名称", _rename)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 230
	add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	split.add_child(left)
	label(left, "01  事件页 · 下方优先", 18)
	pages_list = ItemList.new()
	pages_list.custom_minimum_size.y = 115
	left.add_child(pages_list)
	pages_list.item_selected.connect(func(index): page_index = index; command_index = -1; _refresh())
	var page_buttons := HBoxContainer.new()
	left.add_child(page_buttons)
	button(page_buttons, "+ 页", _add_page)
	button(page_buttons, "复制", _duplicate_page)
	button(page_buttons, "删除", _delete_page)
	button(page_buttons, "↑", _move_page.bind(-1))
	button(page_buttons, "↓", _move_page.bind(1))
	var page_scroll := ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(page_scroll)
	page_form = VBoxContainer.new()
	page_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_form)
	var right := HSplitContainer.new()
	right.split_offset = 460
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 340
	right.add_child(center)
	label(center, "02  指令列表 · 从上到下执行", 18)
	var add_bar := HBoxContainer.new()
	center.add_child(add_bar)
	command_picker = OptionButton.new()
	command_picker.set_meta("mek_labels", LABELS)
	for text in LABELS: command_picker.add_item(_t(text))
	command_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_bar.add_child(command_picker)
	button(add_bar, "+ 插入", _add_command)
	commands_list = ItemList.new()
	commands_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(commands_list)
	commands_list.item_selected.connect(func(index): command_index = index; _command_form())
	var command_buttons := HFlowContainer.new()
	center.add_child(command_buttons)
	button(command_buttons, "复制指令", _duplicate_command)
	button(command_buttons, "删除", _delete_command)
	button(command_buttons, "上移", _move_command.bind(-1))
	button(command_buttons, "下移", _move_command.bind(1))
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 270
	right.add_child(inspector)
	label(inspector, "03  指令参数", 18)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.add_child(scroll)
	command_form = VBoxContainer.new()
	command_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(command_form)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 44
	add_child(status)
	open_dialog = EditorFileDialog.new()
	open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	open_dialog.add_filter("*.tres", _t("事件资源"))
	open_dialog.file_selected.connect(_open)
	add_child(open_dialog)
	save_dialog = EditorFileDialog.new()
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.tres", _t("事件资源"))
	save_dialog.file_selected.connect(_save_as)
	add_child(save_dialog)
	_show_status("快速开始：打开演示事件 → 修改参数并应用 → 保存 → F6 运行场景。")

func button(parent: Node, text: String, action: Callable) -> Button:
	var control := Button.new()
	_set_text(control, text)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func label(parent: Node, text: String, font_size := 0) -> Label:
	var control := Label.new()
	_set_text(control, text)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size: control.add_theme_font_size_override("font_size", font_size)
	parent.add_child(control)
	return control

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func edit_data(value: MEKEventData) -> void:
	if data == value: return
	if data and dirty and not data.resource_path.is_empty(): save_current()
	data = value
	dirty = dirty_resources.has(value.get_instance_id())
	page_index = 0
	command_index = -1
	_refresh()

func _new() -> void:
	if data and dirty and data.resource_path.is_empty():
		_show_status("当前新事件尚未保存。请先另存为，再新建事件。")
		return
	var value := Data.new()
	value.title = _t("新事件")
	value.pages.append(Data.default_page(language))
	edit_data(value)
	dirty = true
	dirty_resources[data.get_instance_id()] = data
	_show_status("新事件已建立。编辑后另存为 .tres，再拖到 MEKMapEvent 的 Data 属性。")

func _open(path: String) -> void:
	if data and dirty and data.resource_path.is_empty():
		_show_status("请先另存当前新事件，避免丢失修改。")
		return
	var value := load(path)
	if value is MEKEventData: edit_data(value)
	else: _show_status("这不是 MEKEventData 事件资源。")

func _refresh() -> void:
	pages_list.clear()
	commands_list.clear()
	_clear(page_form)
	_clear(command_form)
	if data == null: return
	_update_location()
	title_field.text = data.title
	for i in range(data.pages.size()): pages_list.add_item("%02d  %s" % [i + 1, data.pages[i].get("name", _t("事件页"))])
	page_index = clampi(page_index, 0, maxi(0, data.pages.size() - 1))
	if data.pages.is_empty(): return
	pages_list.select(page_index)
	_page_form()
	var indent := 0
	for i in range(data.pages[page_index].commands.size()):
		var c: Dictionary = data.pages[page_index].commands[i]
		if c.op in ["else", "end"]: indent = maxi(0, indent - 1)
		commands_list.add_item("%02d  %s%s" % [i + 1, "    ".repeat(indent), describe(c)])
		if str(c.op).begins_with("if_") or c.op == "else": indent += 1
		if str(c.op).begins_with("if_") or c.op in ["else", "end"]: commands_list.set_item_custom_fg_color(i, Color("e9c782"))
		elif c.op == "text": commands_list.set_item_custom_fg_color(i, Color("87d9b8"))
	if command_index >= commands_list.item_count: command_index = commands_list.item_count - 1
	if command_index >= 0: commands_list.select(command_index)
	_command_form()

func describe(c: Dictionary) -> String:
	var op_index := OPS.find(str(c.get("op", "")))
	var text: String = _t(LABELS[op_index] if op_index >= 0 else "未知指令")
	match c.get("op"):
		"text": text += "  %s：%s" % [c.get("speaker", ""), str(c.get("text", "")).replace("\n", " ").left(42)]
		"choices": text += "  → " + str(c.get("key", ""))
		"set_switch", "set_self_switch", "if_switch", "if_self_switch": text += "  %s = %s" % [c.get("key", ""), "ON" if c.get("value", false) else "OFF"]
		"set_variable", "add_variable", "if_variable": text += "  %s %s %s" % [c.get("key", ""), c.get("compare", "="), str(c.get("value", 0))]
		"transfer": text += "  " + str(c.get("scene", "")).get_file()
		"wait": text += _t("  %s 秒") % c.get("seconds", 0)
	return text

func field(parent: Node, fields: Dictionary, key: String, caption: String, value: Variant, kind := "text", options: Array = []) -> void:
	var caption_label := label(parent, caption)
	var control: Control
	match kind:
		"choice":
			var picker := OptionButton.new()
			for option in options:
				picker.add_item(_t(str(ENUM_LABELS.get(option, option))))
				picker.set_item_metadata(picker.item_count - 1, str(option))
			picker.set_meta("mek_labels", options.map(func(option): return str(ENUM_LABELS.get(option, option))))
			picker.select(maxi(0, options.find(str(value))))
			control = picker
		"bool":
			var toggle := CheckBox.new()
			_set_text(toggle, "开启 / ON")
			toggle.button_pressed = bool(value)
			control = toggle
		"number":
			var spin := SpinBox.new()
			spin.min_value = -1000000000
			spin.max_value = 1000000000
			spin.value = float(value)
			spin.step = 0.1 if key in ["seconds", "volume_db"] else 1.0
			control = spin
		"multiline":
			var edit := TextEdit.new()
			edit.text = str(value)
			edit.custom_minimum_size.y = 160
			edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			control = edit
		_:
			var edit := LineEdit.new()
			edit.text = str(value)
			control = edit
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)
	control.set_meta("caption", caption_label)
	fields[key] = control

func value_of(control: Control) -> Variant:
	if control is OptionButton: return control.get_item_metadata(control.selected)
	if control is CheckBox: return control.button_pressed
	if control is SpinBox: return control.value
	return control.text

func _page_form() -> void:
	page_fields.clear()
	var p: Dictionary = data.pages[page_index]
	field(page_form, page_fields, "name", "页名称", p.get("name", ""))
	field(page_form, page_fields, "condition", "出现条件", p.get("condition", "always"), "choice", CONDITIONS)
	field(page_form, page_fields, "key", "条件键名（无条件时留空）", p.get("key", ""))
	field(page_form, page_fields, "bool_value", "开关条件目标值", p.get("value", true) if p.get("value") is bool else true, "bool")
	field(page_form, page_fields, "number_value", "变量条件：大于等于", p.get("value", 0) if not p.get("value") is bool else 0, "number")
	field(page_form, page_fields, "trigger", "触发方式", p.get("trigger", "interact"), "choice", TRIGGERS)
	field(page_form, page_fields, "visual", "示例外观", p.get("visual", "marker"), "choice", VISUALS)
	page_fields.condition.item_selected.connect(func(_index): _condition_fields())
	_condition_fields()
	button(page_form, "应用事件页", _apply_page)
	label(page_form, "优先级：最后一个满足条件的页生效。\n独立开关由场景路径 + event_id 隔离。\n自动事件每次进入该页执行一次。")

func _condition_fields() -> void:
	var selected: String = value_of(page_fields.condition)
	for key in ["key", "bool_value", "number_value"]:
		var show_field := selected != "always" if key == "key" else (selected == "variable" if key == "number_value" else selected in ["switch", "self_switch"])
		page_fields[key].visible = show_field
		page_fields[key].get_meta("caption").visible = show_field

func _command_form() -> void:
	_clear(command_form)
	command_heading = null
	command_fields.clear()
	if data == null or command_index < 0 or data.pages.is_empty():
		label(command_form, "选择一条指令以编辑参数。\n修改参数后点击“应用指令”，再保存资源。")
		return
	var c: Dictionary = data.pages[page_index].commands[command_index]
	command_heading = label(command_form, describe(c), 18)
	command_heading.remove_meta("mek_text")
	match c.op:
		"text":
			field(command_form, command_fields, "speaker", "说话人", c.get("speaker", ""))
			field(command_form, command_fields, "text", "消息内容", c.get("text", ""), "multiline")
		"choices":
			field(command_form, command_fields, "text", "提问", c.get("text", ""), "multiline")
			field(command_form, command_fields, "options", "选项（每行一个，2～6 项）", "\n".join(c.get("options", [])), "multiline")
			field(command_form, command_fields, "key", "结果变量（第一个选项 = 0）", c.get("key", "choice"))
		"set_switch", "set_self_switch", "if_switch", "if_self_switch":
			field(command_form, command_fields, "key", "开关名称", c.get("key", "A"))
			field(command_form, command_fields, "value", "目标值", c.get("value", true), "bool")
		"set_variable", "add_variable", "if_variable":
			field(command_form, command_fields, "key", "变量名称", c.get("key", "coins"))
			field(command_form, command_fields, "value", "数值", c.get("value", 0), "number")
			if c.op == "if_variable": field(command_form, command_fields, "compare", "比较方式", c.get("compare", ">="), "choice", ["==", "!=", ">=", "<=", ">", "<"])
		"wait": field(command_form, command_fields, "seconds", "等待秒数（0～60）", c.get("seconds", 0.3), "number")
		"transfer":
			field(command_form, command_fields, "scene", "目标场景 res://… .tscn", c.get("scene", ""))
			field(command_form, command_fields, "spawn", "出生点路径（相对场景根节点）", c.get("spawn", "Arrival"))
		"sound":
			field(command_form, command_fields, "path", "音频路径 res://…", c.get("path", ""))
			field(command_form, command_fields, "volume_db", "音量 dB", c.get("volume_db", -6), "number")
		"custom":
			field(command_form, command_fields, "name", "自定义指令名称", c.get("name", ""))
			field(command_form, command_fields, "argument", "文本参数", c.get("argument", ""))
		_: label(command_form, "此指令不需要额外参数。")
	button(command_form, "应用指令", _apply_command)

func _commit(pages: Array[Dictionary], action: String) -> void:
	if data == null: return
	var history := plugin.get_undo_redo()
	history.create_action(_t(action), UndoRedo.MERGE_DISABLE, data)
	history.add_do_property(data, "pages", pages.duplicate(true))
	history.add_undo_property(data, "pages", data.pages.duplicate(true))
	history.add_do_method(self, "_changed", data)
	history.add_undo_method(self, "_changed", data)
	history.commit_action()

func _changed(changed: MEKEventData) -> void:
	changed.emit_changed()
	dirty_resources[changed.get_instance_id()] = changed
	if changed == data:
		dirty = true
		_refresh()
		_validate()

func _rename() -> void:
	if data == null: return
	var history := plugin.get_undo_redo()
	history.create_action(_t("修改事件名称"), UndoRedo.MERGE_DISABLE, data)
	history.add_do_property(data, "title", title_field.text)
	history.add_undo_property(data, "title", data.title)
	history.add_do_method(self, "_changed", data)
	history.add_undo_method(self, "_changed", data)
	history.commit_action()

func _undo() -> void:
	if data == null: return
	var manager := plugin.get_undo_redo()
	var id := manager.get_object_history_id(data)
	manager.get_history_undo_redo(id).undo()

func _redo() -> void:
	if data == null: return
	var manager := plugin.get_undo_redo()
	var id := manager.get_object_history_id(data)
	manager.get_history_undo_redo(id).redo()

func _apply_page() -> void:
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	for key in ["name", "condition", "key", "trigger", "visual"]: pages[page_index][key] = value_of(page_fields[key])
	pages[page_index].value = int(value_of(page_fields.number_value)) if pages[page_index].condition == "variable" else bool(value_of(page_fields.bool_value))
	_commit(pages, "修改事件页")

func _apply_command() -> void:
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var c: Dictionary = pages[page_index].commands[command_index]
	for key in command_fields:
		var value: Variant = value_of(command_fields[key])
		if key == "options": value = Array(str(value).split("\n", false))
		if key == "value" and c.op in ["set_variable", "add_variable", "if_variable"]: value = int(value)
		c[key] = value
	_commit(pages, "修改指令")

func _add_page() -> void:
	if data == null: return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var p := Data.default_page(language)
	p.name = _t("第 %d 页") % (pages.size() + 1)
	pages.append(p)
	page_index = pages.size() - 1
	command_index = -1
	_commit(pages, "添加事件页")

func _duplicate_page() -> void:
	if data == null or data.pages.is_empty(): return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var p: Dictionary = pages[page_index].duplicate(true)
	p.name = str(p.name) + _t(" 副本")
	pages.insert(page_index + 1, p)
	page_index += 1
	_commit(pages, "复制事件页")

func _delete_page() -> void:
	if data == null or data.pages.size() <= 1:
		_show_status("至少保留一个事件页。")
		return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	pages.remove_at(page_index)
	_commit(pages, "删除事件页")

func _move_page(offset: int) -> void:
	if data == null or page_index + offset < 0 or page_index + offset >= data.pages.size(): return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var old: Dictionary = pages[page_index]
	pages[page_index] = pages[page_index + offset]
	page_index += offset
	pages[page_index] = old
	_commit(pages, "移动事件页")

func _add_command() -> void:
	if data == null or data.pages.is_empty(): return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var list: Array = pages[page_index].commands
	command_index = command_index + 1 if command_index >= 0 else list.size()
	list.insert(command_index, Data.default_command(OPS[command_picker.selected], language))
	_commit(pages, "插入指令")

func _duplicate_command() -> void:
	if data == null or command_index < 0: return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var list: Array = pages[page_index].commands
	list.insert(command_index + 1, list[command_index].duplicate(true))
	command_index += 1
	_commit(pages, "复制指令")

func _delete_command() -> void:
	if data == null or command_index < 0: return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	pages[page_index].commands.remove_at(command_index)
	_commit(pages, "删除指令")

func _move_command(offset: int) -> void:
	if data == null or command_index < 0: return
	var pages: Array[Dictionary] = data.pages.duplicate(true)
	var list: Array = pages[page_index].commands
	if command_index + offset < 0 or command_index + offset >= list.size(): return
	var old: Dictionary = list[command_index]
	list[command_index] = list[command_index + offset]
	command_index += offset
	list[command_index] = old
	_commit(pages, "移动指令")

func _validate() -> bool:
	showing_validation = true
	var errors := Data.validate(data, language)
	last_diagnostic = _t("检查通过 · 页条件、分支结构和资源路径有效。") if errors.is_empty() else "\n".join(errors)
	status.text = last_diagnostic
	status.modulate = Color("8ddbb7") if errors.is_empty() else Color("f2ab83")
	return errors.is_empty()

func save_current() -> void:
	if data == null: return
	if data.resource_path.is_empty():
		if visible: save_dialog.popup_centered_ratio(0.65)
		return
	if "::" in data.resource_path:
		plugin.get_editor_interface().mark_scene_as_unsaved()
		_show_status("内嵌资源随场景保存；建议另存为独立 .tres。")
		return
	var error := ResourceSaver.save(data, data.resource_path)
	if error == OK:
		dirty = false
		dirty_resources.erase(data.get_instance_id())
		_refresh()
		_validate()
	else: _show_status("保存失败：%s", [error_string(error)])

func _save_as(path: String) -> void:
	if data == null: return
	var copy := data.duplicate(true) as MEKEventData
	var error := ResourceSaver.save(copy, path)
	if error != OK:
		_show_status("保存失败：%s", [error_string(error)])
		return
	copy.take_over_path(path)
	dirty = false
	dirty_resources.erase(data.get_instance_id())
	edit_data(copy)
	if path.begins_with("res://"):
		plugin.get_editor_interface().get_resource_filesystem().update_file(path)

func save_all() -> void:
	for id in dirty_resources.keys():
		var resource: MEKEventData = dirty_resources[id]
		if resource.resource_path.is_empty(): continue
		if "::" in resource.resource_path:
			plugin.get_editor_interface().mark_scene_as_unsaved()
			continue
		if ResourceSaver.save(resource, resource.resource_path) == OK:
			dirty_resources.erase(id)
	if data:
		dirty = dirty_resources.has(data.get_instance_id())
		_refresh()


func _t(source: String) -> String:
	return I18n.text(source, language)

func _resolved_language() -> String:
	var editor_locale := str(plugin.get_editor_interface().get_editor_settings().get_setting("interface/editor/editor_language"))
	return I18n.resolve(editor_locale if language_choice == "auto" else language_choice)

func set_language(choice: String) -> void:
	language_choice = choice if choice in I18n.LANGUAGES else "auto"
	plugin.get_editor_interface().get_editor_settings().set_project_metadata("map_event_kit", "editor_language", language_choice)
	language = _resolved_language()
	_apply_language()

func _editor_settings_changed() -> void:
	if language_choice == "auto" and language != _resolved_language():
		language = _resolved_language()
		_apply_language()

func _set_text(control: Control, source: String) -> void:
	control.set_meta("mek_text", source)
	control.set("text", _t(source))

func _show_status(source: String, args: Array = []) -> void:
	status_source = source
	status_args = args
	showing_validation = false
	status.text = _t(source) if args.is_empty() else _t(source) % args

func _update_location() -> void:
	if data == null:
		location.text = _t("打开一个事件资源，或在 2D 场景中选择 MEKMapEvent 节点。")
	else:
		location.text = (data.resource_path if not data.resource_path.is_empty() else _t("尚未保存 · 请另存为 .tres")) + (_t("  ● 已修改") if dirty else "")

func _translate_tree(node: Node) -> void:
	if node.has_meta("mek_text"):
		node.set("text", _t(str(node.get_meta("mek_text"))))
	if node.has_meta("mek_labels"):
		var sources: Array = node.get_meta("mek_labels")
		for i in range(sources.size()): node.set_item_text(i, _t(sources[i]))
	# MenuButton owns an internal popup, omitted by get_children().
	if node is MenuButton: _translate_tree(node.get_popup())
	for child in node.get_children(): _translate_tree(child)

func _apply_language() -> void:
	# Update labels in place: rebuilding forms would discard pending user input.
	_translate_tree(self)
	language_picker.set_item_text(0, _t("跟随 Godot"))
	language_picker.select(I18n.LANGUAGES.find(language_choice))
	_update_location()
	open_dialog.clear_filters()
	open_dialog.add_filter("*.tres", _t("事件资源"))
	save_dialog.clear_filters()
	save_dialog.add_filter("*.tres", _t("事件资源"))
	if data and not data.pages.is_empty():
		var indent := 0
		for i in range(data.pages[page_index].commands.size()):
			var command: Dictionary = data.pages[page_index].commands[i]
			if command.op in ["else", "end"]: indent = maxi(0, indent - 1)
			commands_list.set_item_text(i, "%02d  %s%s" % [i + 1, "    ".repeat(indent), describe(command)])
			if str(command.op).begins_with("if_") or command.op == "else": indent += 1
		if is_instance_valid(command_heading) and command_index >= 0:
			command_heading.text = describe(data.pages[page_index].commands[command_index])
	if showing_validation: _validate()
	else: _show_status(status_source, status_args)
