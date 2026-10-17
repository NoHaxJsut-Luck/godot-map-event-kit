@tool
extends RefCounted

var checks: Array[Dictionary] = []
var failures := 0

func check(ok: bool, title: String) -> void:
	checks.append({"name":title,"passed":ok})
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func run(plugin: EditorPlugin, panel: Control) -> void:
	await plugin.get_tree().process_frame
	check(plugin._build(), "autoload path accepted by build gate")
	var original_autoload: String = ProjectSettings.get_setting("autoload/MapEvents")
	var runtime_uid := ResourceLoader.get_resource_uid("res://addons/map_event_kit/runtime/event_runtime.gd")
	ProjectSettings.set_setting("autoload/MapEvents", "*" + ResourceUID.id_to_text(runtime_uid))
	check(plugin._build(), "autoload UID accepted by build gate")
	ProjectSettings.set_setting("autoload/MapEvents", original_autoload)
	var original: MEKEventData = load("res://demo/events/chest.tres")
	var resource: MEKEventData = original.duplicate(true)
	panel.edit_data(resource)
	panel.show()
	plugin.get_editor_interface().set_main_screen_editor("地图事件")
	check(panel.pages_list.item_count == 2 and panel.commands_list.item_count == 6, "editor renders pages and commands")
	panel.command_index = 0
	panel._refresh()
	panel.command_fields.text.text = "已通过参数表单修改"
	panel._apply_command()
	check(resource.pages[0].commands[0].text == "已通过参数表单修改", "form applies command text")
	panel._undo()
	check(resource.pages[0].commands[0].text == original.pages[0].commands[0].text, "editor undo restores resource")
	panel._redo()
	check(resource.pages[0].commands[0].text == "已通过参数表单修改", "editor redo reapplies resource")
	panel._duplicate_command()
	check(resource.pages[0].commands.size() == 7, "duplicate command")
	panel._delete_command()
	check(resource.pages[0].commands.size() == 6, "delete command")
	panel._add_page()
	check(resource.pages.size() == 3, "add event page")
	panel._move_page(-1)
	check(resource.pages[1].name == "第 3 页", "change event page priority")
	panel._delete_page()
	check(resource.pages.size() == 2, "delete event page")
	DirAccess.make_dir_recursive_absolute("user://map_event_kit_tests")
	panel._save_as("user://map_event_kit_tests/editor_save.tres")
	var saved: MEKEventData = ResourceLoader.load("user://map_event_kit_tests/editor_save.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(saved.pages[0].commands[0].text == "已通过参数表单修改", "save-as survives resource reload")
	panel.edit_data(original)
	panel.page_index = 0
	panel.command_index = 0
	panel._refresh()
	panel._validate()
	check(panel.last_diagnostic.begins_with("检查通过"), "validation status visible")
	await plugin.get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		plugin.get_editor_interface().get_base_control().get_viewport().get_texture().get_image().save_png("res://artifacts/editor.png")
	var output := FileAccess.open("res://artifacts/editor-tests.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failed":failures},"\t"))
	output.close()
	print("EDITOR RESULT %d checks, %d failures" % [checks.size(),failures])
	panel.dirty = false
	panel.dirty_resources.clear()
	plugin.get_tree().quit(0 if failures == 0 else 1)
