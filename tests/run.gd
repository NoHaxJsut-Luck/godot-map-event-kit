extends SceneTree

const Data = preload("res://addons/map_event_kit/core/event_data.gd")
const Event = preload("res://addons/map_event_kit/runtime/map_event.gd")
var runtime: Node
var checks: Array[Dictionary] = []
var failures := 0
var errors_seen: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks.append({"name": title, "passed": ok})
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func frames(n := 2) -> void:
	for _i in range(n): await process_frame

func wait_idle() -> void:
	for _i in range(240):
		await process_frame
		if not runtime.busy: return
	check(false, "event must finish within frame budget")

func wait_scene(path: String) -> void:
	for _i in range(240):
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			await frames(3)
			await wait_idle()
			return
	check(false, "scene transition deadline: " + path)

func event(commands: Array, id: String) -> MEKMapEvent:
	var node := Event.new()
	node.event_id = id
	node.data = Data.new()
	var p := Data.default_page()
	p.commands = commands
	node.data.pages.append(p)
	current_scene.add_child(node)
	return node

func run() -> void:
	create_timer(40).timeout.connect(func(): push_error("Integration test timeout"); quit(2))
	runtime = root.get_node("MapEvents")
	runtime.auto_answer = 0
	runtime.save_path = "user://map_event_kit_tests/integration_save.json"
	runtime.event_error.connect(func(message): errors_seen.append(message))
	for name in ["chest", "guide", "gate", "return", "arrival", "sign"]:
		check(Data.validate(load("res://demo/events/" + name + ".tres")).is_empty(), "validate demo " + name)
	change_scene_to_file("res://demo/courtyard.tscn")
	await wait_scene("res://demo/courtyard.tscn")
	await current_scene.get_node("Gate").interact()
	check(current_scene.scene_file_path.ends_with("courtyard.tscn"), "locked gate does not transfer")
	await current_scene.get_node("Guide").interact()
	check(runtime.variables.get("guide_choice") == 0 and not runtime.busy, "choice writes result and nested dialogue completes")
	var chest := current_scene.get_node("Chest") as MEKMapEvent
	current_scene.get_node("Player").position = chest.position + Vector2(-35, 0)
	var input := InputEventKey.new()
	input.physical_keycode = KEY_E
	input.pressed = true
	Input.parse_input_event(input)
	await frames(2)
	input = InputEventKey.new()
	input.physical_keycode = KEY_E
	input.pressed = false
	Input.parse_input_event(input)
	await wait_idle()
	check(runtime.switches.get("has_key", false) and runtime.variables.get("coins") == 10, "E interaction grants key and exactly ten coins")
	check(chest.page_index == 1, "higher-priority self-switch page selected")
	await chest.interact()
	check(runtime.variables.get("coins") == 10, "opened chest cannot grant duplicate loot")
	var another := Event.new()
	another.event_id = "another_chest"
	another.data = chest.data
	current_scene.add_child(another)
	check(another.page_index == 0, "shared event resource keeps per-instance self switches isolated")
	another.queue_free()
	await frames()
	var nested := event([
		{"op":"if_switch", "key":"missing", "value":true},
		{"op":"if_switch", "key":"has_key", "value":true},
		{"op":"set_variable", "key":"branch", "value":99},
		{"op":"else"}, {"op":"set_variable", "key":"branch", "value":98}, {"op":"end"},
		{"op":"else"}, {"op":"set_variable", "key":"branch", "value":7}, {"op":"end"}
	], "nested")
	await nested.interact()
	check(runtime.variables.get("branch") == 7, "nested disabled branch cannot leak through inner else")
	nested.queue_free()
	var invalid := event([{"op":"else"}], "invalid")
	check(not await invalid.interact() and not runtime.busy, "malformed branch is rejected without locking player")
	invalid.queue_free()
	var waiting := event([{"op":"wait", "seconds":0.1},{"op":"set_switch", "key":"must_not_run", "value":true}], "cancel_wait")
	waiting.interact()
	await frames()
	check(runtime.save_game() == ERR_BUSY, "save refused during active event")
	waiting.queue_free()
	await create_timer(0.15).timeout
	check(not runtime.busy and not runtime.switches.get("must_not_run", false), "destroying waiting event cancels remaining commands and releases lock")
	runtime.auto_answer = -1
	var talking := event([{"op":"text", "text":"Cancel test"},{"op":"set_switch", "key":"must_not_run", "value":true}], "cancel_dialogue")
	talking.interact()
	await frames()
	check(runtime.dialogue.active, "dialogue awaits real user input")
	talking.queue_free()
	await frames()
	check(not runtime.busy and not runtime.dialogue.active and not runtime.switches.get("must_not_run", false), "destroying dialogue event dismisses UI and cancels coroutine")
	runtime.auto_answer = 0
	var first := event([], "duplicate")
	var second := event([], "duplicate")
	check(not first.valid_identity and not second.valid_identity, "duplicate scene event IDs disable both conflicting instances")
	first.queue_free(); second.queue_free()
	await frames()
	await current_scene.get_node("Gate").interact()
	await wait_scene("res://demo/ruins.tscn")
	check(runtime.switches.get("visited_ruins", false), "transfer executes arrival autorun")
	check(runtime.variables.get("coins") == 10, "global state survives scene change")
	var player := current_scene.get_node("Player") as Node2D
	player.position = Vector2(330, 402)
	check(runtime.save_game() == OK, "save complete state, scene and position")
	check(runtime.save_game() == OK and runtime.save_game() == OK, "repeated atomic save and backup replacement")
	runtime.set_variable("coins", 999)
	await current_scene.get_node("Return").interact()
	await wait_scene("res://demo/courtyard.tscn")
	check(current_scene.get_node("Chest").page_index == 1, "self switch survives round-trip map transfer")
	check(runtime.load_game() == OK, "load accepted")
	await wait_scene("res://demo/ruins.tscn")
	check(runtime.variables.get("coins") == 10 and current_scene.get_node("Player").position.is_equal_approx(Vector2(330,402)), "load restores exact state, scene and position")
	var corrupted := FileAccess.open(runtime.save_path, FileAccess.WRITE)
	corrupted.store_string('{"version":1,"switches":[]}')
	corrupted.close()
	check(runtime.load_game() == ERR_FILE_CORRUPT and runtime.variables.get("coins") == 10, "malformed save does not mutate live state")
	var source: MEKEventData = load("res://demo/events/guide.tres")
	var target := "user://map_event_kit_tests/resource_roundtrip.tres"
	check(ResourceSaver.save(source, target) == OK, "event resource serializes")
	var roundtrip: MEKEventData = ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(roundtrip.pages == source.pages, "event resource preserves nested branch commands on disk")
	check(errors_seen.size() == 2, "only expected malformed-branch and duplicate-ID diagnostics")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report := FileAccess.open("res://artifacts/runtime-tests.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failed":failures},"\t"))
	report.close()
	print("RESULT %d checks, %d failures" % [checks.size(), failures])
	await frames(3)
	quit(0 if failures == 0 else 1)
