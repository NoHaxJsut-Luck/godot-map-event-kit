@tool
extends RefCounted

const I18n = preload("res://addons/map_event_kit/core/localization.gd")
const Data = preload("res://addons/map_event_kit/core/event_data.gd")
var checks: Array[Dictionary] = []
var failures := 0

func check(ok: bool, title: String) -> void:
	checks.append({"name":title,"passed":ok})
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func run(plugin: EditorPlugin, panel: Control) -> void:
	await plugin.get_tree().process_frame
	var saved_language: String = panel.language_choice
	panel.set_language("zh_CN")
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
	plugin.get_editor_interface().set_main_screen_editor("Map Events")
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
	check(await test_languages(plugin, panel) == true, "language suite completed without script errors")
	panel.set_language(saved_language)
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

func test_languages(plugin: EditorPlugin, panel: Control) -> bool:
	check(I18n.resolve("ja_JP") == "ja" and I18n.resolve("ko-KR") == "ko" and I18n.resolve("zh_TW") == "zh_CN" and I18n.resolve("fr_FR") == "en", "regional locale normalization and English fallback")
	var catalog_ok := true
	for source in I18n.MESSAGES:
		var row: Array = I18n.MESSAGES[source]
		if row.size() != 3: catalog_ok = false
		for translation in row:
			if str(translation).is_empty() or str(translation).count("%s") != str(source).count("%s") or str(translation).count("%d") != str(source).count("%d"):
				catalog_ok = false
	check(catalog_ok, "translation catalog is complete with matching placeholders")
	var resource: MEKEventData = panel.data.duplicate(true)
	panel.edit_data(resource)
	panel.command_index = 0
	panel._refresh()
	panel.command_picker.select(7)
	panel.title_field.text = "Draft title 日本語 한국어"
	panel.page_fields.name.text = "Draft page"
	panel.page_fields.condition.select(3)
	panel._condition_fields()
	panel.page_fields.number_value.value = 42
	panel.page_fields.bool_value.button_pressed = false
	panel.command_fields.text.text = "Unapplied dialogue 中文 日本語 한국어"
	var before := var_to_str(resource.pages)
	var title_before := resource.title
	var dirty_before: Dictionary = panel.dirty_resources.duplicate()
	var control_id: int = panel.command_fields.text.get_instance_id()
	for locale in ["en", "ja", "ko", "zh_CN"]:
		# Exercise the same signal as choosing a language in the UI.
		panel.language_picker.select(I18n.LANGUAGES.find(locale))
		panel.language_picker.item_selected.emit(panel.language_picker.selected)
		var menu_ok := true
		for child in panel.find_children("*", "MenuButton", true, false):
			if child.get_popup().has_meta("mek_labels"):
				menu_ok = menu_ok and child.get_popup().get_item_text(0) == I18n.text("宝箱 · 两页与独立开关", locale)
		check(panel.language == locale and panel.command_picker.get_item_text(0) == I18n.text("显示文字", locale) and panel.page_fields.condition.get_item_text(3) == I18n.text("变量阈值", locale), locale + " labels and enum choices translated")
		check(menu_ok and panel.command_fields.text.get_meta("caption").text == I18n.text("消息内容", locale), locale + " popup menu and field captions translated")
		check(panel.command_fields.text.get_instance_id() == control_id and panel.command_fields.text.text == "Unapplied dialogue 中文 日本語 한국어" and panel.title_field.text == "Draft title 日本語 한국어" and panel.page_fields.name.text == "Draft page" and panel.page_fields.number_value.value == 42 and not panel.page_fields.bool_value.button_pressed, locale + " pending text, number and boolean inputs survive")
		check(panel.value_of(panel.page_fields.condition) == "variable" and panel.command_picker.selected == 7 and panel.command_index == 0 and panel.page_index == 0 and var_to_str(resource.pages) == before and resource.title == title_before and panel.dirty_resources == dirty_before, locale + " selection, stable IDs and resource contents unchanged")
		panel._validate()
		check(panel.status.text == I18n.text("检查通过 · 页条件、分支结构和资源路径有效。", locale), locale + " validation success translated")
		var invalid := Data.new()
		invalid.pages.append(Data.default_page())
		invalid.pages[0].commands = [{"op":"else"}]
		check(Data.validate(invalid, locale)[0] == (I18n.text("第 %d 页：", locale) % 1) + (I18n.text("指令 %d：", locale) % 1) + I18n.text("否则缺少对应条件。", locale), locale + " validation error translated with page and command numbers")
		check(Data.default_page(locale).name == I18n.text("第 1 页", locale) and Data.default_command("choices", locale).options[0] == I18n.text("同意", locale), locale + " new-content defaults localized")
	panel.set_language("en")
	panel._apply_command()
	check(resource.pages[0].commands[0].text == "Unapplied dialogue 中文 日本語 한국어", "apply preserved draft after language changes")
	panel.set_language("ja")
	panel._undo()
	check(var_to_str(resource.pages) == before, "undo survives language switch")
	panel.set_language("ko")
	panel._redo()
	check(resource.pages[0].commands[0].text == "Unapplied dialogue 中文 日本語 한국어", "redo survives language switch")
	resource.pages[0].commands[1] = Data.default_command("choices")
	panel.command_index = 1
	panel._refresh()
	panel.command_fields.options.text = "Draft A\nDraft B\nDraft C"
	panel.set_language("en")
	check(panel.command_fields.options.text == "Draft A\nDraft B\nDraft C", "unapplied choice options survive language switch")
	var reopened: Control = panel.get_script().new()
	reopened.plugin = plugin
	plugin.get_editor_interface().get_editor_main_screen().add_child(reopened)
	check(reopened.language_choice == "en" and reopened.language == "en", "language preference persists across panel recreation")
	reopened.queue_free()
	panel.set_language("auto")
	check(panel.language == panel._resolved_language(), "automatic choice follows Godot editor language")
	panel.dirty_resources.erase(resource.get_instance_id())
	panel.dirty = false
	panel.edit_data(load("res://demo/events/chest.tres"))
	panel.command_index = 0
	panel._refresh()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		for locale in ["en", "ja", "ko", "zh_CN"]:
			panel.set_language(locale)
			await plugin.get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			plugin.get_editor_interface().get_base_control().get_viewport().get_texture().get_image().save_png("res://artifacts/editor-" + locale + ".png")
	return true
