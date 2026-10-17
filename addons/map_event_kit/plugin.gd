@tool
extends EditorPlugin

const EventPanel = preload("res://addons/map_event_kit/editor/event_editor.gd")
var panel: Control

func _enter_tree() -> void:
	panel = EventPanel.new()
	panel.plugin = self
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	get_editor_interface().get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.hide()
	_ensure_autoload.call_deferred()
	if OS.get_environment("MEK_EDITOR_TEST") == "1" and FileAccess.file_exists("res://tests/editor_smoke.gd"):
		call_deferred("_test_editor")

func _enable_plugin() -> void:
	_ensure_autoload()

func _ensure_autoload() -> void:
	if not ProjectSettings.has_setting("autoload/MapEvents"):
		# A freshly copied addon is discovered before the initial UID scan finishes.
		await get_tree().create_timer(1.5).timeout
		while get_editor_interface().get_resource_filesystem().is_scanning():
			await get_tree().process_frame
		if ProjectSettings.has_setting("autoload/MapEvents"): return
		add_autoload_singleton("MapEvents", "res://addons/map_event_kit/runtime/event_runtime.gd")
	elif not _owns_autoload():
		push_warning("Map Event Kit: MapEvents 自动加载名称已被其他脚本占用。请先解决名称冲突。")

func _disable_plugin() -> void:
	if _owns_autoload():
		remove_autoload_singleton("MapEvents")

func _exit_tree() -> void:
	if panel:
		panel.save_all()
		panel.queue_free()

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "地图事件"
func _get_plugin_icon() -> Texture2D: return get_editor_interface().get_base_control().get_theme_icon("Script", "EditorIcons")
func _make_visible(value: bool) -> void:
	if panel: panel.visible = value
func _handles(object: Object) -> bool: return object is MEKEventData or object is MEKMapEvent
func _edit(object: Object) -> void:
	if object is MEKEventData: panel.edit_data(object)
	elif object is MEKMapEvent and object.data: panel.edit_data(object.data)
	if panel: get_editor_interface().set_main_screen_editor("地图事件")
func _save_external_data() -> void:
	if panel: panel.save_all()

func _get_unsaved_status(_for_scene: String) -> String:
	if panel and not panel.dirty_resources.is_empty(): return "地图事件有尚未保存的修改。"
	return ""

func _build() -> bool:
	return _owns_autoload()

func _owns_autoload() -> bool:
	var path := str(ProjectSettings.get_setting("autoload/MapEvents", "")).trim_prefix("*")
	if path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(uid): return false
		path = ResourceUID.get_id_path(uid)
	return path == "res://addons/map_event_kit/runtime/event_runtime.gd"

func _test_editor() -> void:
	await get_tree().create_timer(2.0).timeout
	while get_editor_interface().get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var harness = load("res://tests/editor_smoke.gd").new()
	await harness.run(self, panel)
