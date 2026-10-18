extends SceneTree

const Locale = preload("res://demo/localization.gd")
var runtime: Node
var locale_service: Node
var checks: Array[Dictionary] = []
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks.append({"name":title, "passed":ok})
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func frames(count := 3) -> void:
	for _i in range(count): await process_frame

func choose(language: String) -> void:
	var picker: OptionButton = current_scene.language_picker
	picker.select(Locale.LANGUAGES.find(language))
	picker.item_selected.emit(picker.selected)
	await frames()

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")

func wait_idle() -> void:
	for _i in range(120):
		await process_frame
		if not runtime.busy: return
	check(false, "event completion deadline")

func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Demo language test timeout"); quit(2))
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	runtime = root.get_node("MapEvents")
	runtime.save_path = "user://map_event_kit_tests/demo_language_save.json"
	change_scene_to_file("res://demo/courtyard.tscn")
	await frames(5)
	locale_service = runtime.get_node("DemoLocale")
	# Never overwrite the player's language preference or progress in this harness.
	locale_service.settings_path = "user://map_event_kit_tests/demo_language.cfg"
	var test_settings_path: String = locale_service.settings_path
	locale_service.settings_path += ".fresh-" + str(OS.get_process_id())
	locale_service.load_preference()
	check(locale_service.choice == "en" and locale_service.language == "en" and current_scene.language_picker.get_item_text(current_scene.language_picker.selected) == "English", "fresh launch defaults to English independently of system language")
	locale_service.settings_path = test_settings_path
	var originals: Dictionary = {}
	var coverage := true
	for asset in ["chest", "guide", "gate", "return", "arrival", "sign"]:
		var data = load("res://demo/events/" + asset + ".tres")
		originals[asset] = var_to_str(data.pages)
		for page in data.pages:
			for command in page.commands:
				var sources: Array = command.get("options", []).duplicate()
				for key in ["text", "speaker"]:
					if not str(command.get(key, "")).is_empty(): sources.append(command[key])
				for source in sources:
					coverage = coverage and Locale.MESSAGES.has(source)
	check(coverage, "all authored dialogue, speakers and choices have translations")
	var placeholders_ok := true
	for source in Locale.MESSAGES:
		var row: Array = Locale.MESSAGES[source]
		placeholders_ok = placeholders_ok and row.size() == 3
		for value in row:
			placeholders_ok = placeholders_ok and not str(value).is_empty() and str(source).count("%s") == str(value).count("%s") and str(source).count("%d") == str(value).count("%d")
	check(placeholders_ok, "demo catalog complete and placeholders preserved")
	for language in ["en", "ja", "ko", "zh_CN"]:
		await choose(language)
		check(current_scene.save_button.text == locale_service.text("保存") and current_scene.load_button.text == locale_service.text("读取") and current_scene.state_label.text.contains(locale_service.text("否")), language + " HUD and buttons localized")
		check(runtime.translate_text(current_scene.get_node("Guide").display_name) == locale_service.text("守门人") and runtime.translate_text("User custom text") == "User custom text", language + " event captions translated and unknown content preserved")
		var original_save_path: String = runtime.save_path
		runtime.save_path += ".missing-" + str(OS.get_process_id())
		current_scene.restore()
		runtime.save_path = original_save_path
		check(current_scene.notice.text == locale_service.text("还没有存档。"), language + " load notice localized")
		current_scene.show_notice("本演示使用自绘几何图形，无外部游戏素材。")
		await capture("demo-" + language)

	runtime.auto_answer = -1
	current_scene.get_node("Guide").interact()
	await frames()
	var dialogue = runtime.dialogue
	var token: int = runtime.generation
	var source_text: String = dialogue.active_command.text
	for language in ["en", "ja", "ko", "zh_CN"]:
		await choose(language)
		check(dialogue.active and runtime.busy and runtime.generation == token and dialogue.message.text == locale_service.text(source_text) and dialogue.speaker.text == locale_service.text("守门人") and dialogue.buttons.get_child(0).text == locale_service.text("继续  ↵"), language + " active dialogue switches without advancing")
	dialogue.buttons.get_child(0).pressed.emit()
	await frames()
	var button_id: int = dialogue.buttons.get_child(1).get_instance_id()
	dialogue.buttons.get_child(1).grab_focus()
	for language in ["en", "ja", "ko", "zh_CN"]:
		await choose(language)
		check(dialogue.message.text == locale_service.text("需要我给你一点提示吗？") and dialogue.buttons.get_child(0).text == locale_service.text("请给我提示") and dialogue.buttons.get_child(1).text == locale_service.text("我自己探索") and dialogue.buttons.get_child(1).get_instance_id() == button_id and dialogue.focused_choice == 1, language + " live choices retain identity and focused option")
		await capture("demo-choices-" + language)
	dialogue.buttons.get_child(1).pressed.emit()
	await frames()
	check(runtime.variables.get("guide_choice") == 1 and dialogue.message.text == locale_service.text("好奇心会为你指路。祝你探索愉快。"), "translated choice retains branch index")
	dialogue.buttons.get_child(0).pressed.emit()
	await wait_idle()
	runtime.auto_answer = 0
	for language in ["en", "ja", "ko", "zh_CN"]:
		runtime.reset_state()
		await choose(language)
		await current_scene.get_node("Chest").interact()
		await current_scene.get_node("Chest").interact()
		check(runtime.variables.get("coins") == 10 and current_scene.get_node("Chest").page_index == 1, language + " chest reward occurs once")
		await current_scene.get_node("Gate").interact()
		await frames(6)
		await wait_idle()
		check(current_scene.scene_file_path.ends_with("ruins.tscn") and locale_service.language == language and runtime.switches.get("visited_ruins", false), language + " transfer and autorun preserve language")
		check(runtime.save_game() == OK, language + " save succeeds")
		var alternate := "en" if language != "en" else "ja"
		await choose(alternate)
		runtime.set_variable("coins", 999)
		check(runtime.load_game() == OK, language + " saved progress reloads")
		await frames(6)
		check(runtime.variables.get("coins") == 10 and locale_service.language == alternate, language + " loading restores progress without overriding language")
		await current_scene.get_node("Return").interact()
		await frames(6)
	await choose("ko")
	locale_service.set_language("en", false)
	locale_service.load_preference()
	check(locale_service.language == "ko", "language preference reloads from disk")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(runtime.save_path))
	check(snapshot.version == 1 and not snapshot.has("language"), "game save schema remains compatible")
	var unchanged := true
	for asset in originals: unchanged = unchanged and var_to_str(load("res://demo/events/" + asset + ".tres").pages) == originals[asset]
	check(unchanged, "translation never mutates authored event resources")
	runtime.set_text_translator(Callable())
	check(runtime.translate_text("守门人") == "守门人", "addon without translation adapter retains original behavior")
	var report := FileAccess.open("res://artifacts/demo-language-tests.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failed":failures}, "\t"))
	report.close()
	print("DEMO LANGUAGE RESULT %d checks, %d failures" % [checks.size(), failures])
	# Let the last half-second chime release its playback resource before shutdown.
	await create_timer(0.6).timeout
	await frames()
	quit(0 if failures == 0 else 1)
