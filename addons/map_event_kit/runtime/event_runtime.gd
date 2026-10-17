extends Node

signal state_changed
signal busy_changed(value: bool)
signal trace(event_key: String, index: int, command: Dictionary)
signal event_error(message: String)
signal custom_command(command_name: String, argument: String, event_key: String)

const Dialogue = preload("res://addons/map_event_kit/runtime/dialogue.gd")
const Data = preload("res://addons/map_event_kit/core/event_data.gd")
var switches: Dictionary = {}
var variables: Dictionary = {}
var self_switches: Dictionary = {}
var busy := false
var generation := 0
var dialogue: CanvasLayer
var current_event: Node
var pending_spawn := ""
var pending_position: Variant = null
var auto_answer := -1 # Only used by the headless integration harness.
var save_path := "user://map_event_kit/save_01.json"

func _ready() -> void:
	dialogue = Dialogue.new()
	add_child(dialogue)

func set_switch(key: String, value: bool) -> void:
	switches[key] = value
	state_changed.emit()

func set_variable(key: String, value: int) -> void:
	variables[key] = clampi(value, -1000000000, 1000000000)
	state_changed.emit()

func set_self_switch(event_key: String, key: String, value: bool) -> void:
	self_switches[event_key + "::" + key] = value
	state_changed.emit()

func condition(page: Dictionary, event_key: String) -> bool:
	var key := str(page.get("key", ""))
	match page.get("condition", "always"):
		"always": return true
		"switch": return switches.get(key, false) == page.get("value", true)
		"self_switch": return self_switches.get(event_key + "::" + key, false) == page.get("value", true)
		"variable": return int(variables.get(key, 0)) >= int(page.get("value", 0))
	return false

func active_page(data: Resource, event_key: String) -> int:
	if data == null: return -1
	for i in range(data.pages.size() - 1, -1, -1):
		if condition(data.pages[i], event_key): return i
	return -1

func cancel() -> void:
	generation += 1
	current_event = null
	if dialogue: dialogue.cancel()
	_set_busy(false)

func _set_busy(value: bool) -> void:
	if busy == value: return
	busy = value
	busy_changed.emit(busy)

func run_event(event: Node) -> bool:
	if busy or not is_instance_valid(event) or not event.is_inside_tree(): return false
	var errors := Data.validate(event.data)
	if not errors.is_empty():
		event_error.emit(" / ".join(errors))
		return false
	var event_key: String = event.identity()
	var pi := active_page(event.data, event_key)
	if pi < 0: return false
	var commands: Array = event.data.pages[pi].get("commands", []).duplicate(true)
	var token := generation + 1
	generation = token
	current_event = event
	_set_busy(true)
	var branches: Array[Dictionary] = []
	var enabled := true
	for index in range(commands.size()):
		if generation != token: return false
		var c: Dictionary = commands[index]
		var op := str(c.get("op", ""))
		if op.begins_with("if_"):
			var passed := _test(c, event_key)
			branches.append({"parent": enabled, "passed": passed})
			enabled = enabled and passed
			continue
		if op == "else":
			var frame: Dictionary = branches[-1]
			enabled = bool(frame.parent) and not bool(frame.passed)
			continue
		if op == "end":
			enabled = bool(branches.pop_back().parent)
			continue
		if not enabled: continue
		trace.emit(event_key, index, c)
		match op:
			"text", "choices":
				var answer: int
				if auto_answer >= 0:
					answer = auto_answer
					await get_tree().process_frame
				else: answer = await dialogue.ask(c)
				if generation != token or answer < 0: return false
				if op == "choices": set_variable(str(c.key), answer)
			"set_switch": set_switch(str(c.key), bool(c.value))
			"set_self_switch": set_self_switch(event_key, str(c.key), bool(c.value))
			"set_variable": set_variable(str(c.key), int(c.value))
			"add_variable": set_variable(str(c.key), int(variables.get(c.key, 0)) + int(c.value))
			"wait":
				await get_tree().create_timer(float(c.seconds)).timeout
				if generation != token: return false
			"sound":
				var player := AudioStreamPlayer.new()
				player.stream = load(str(c.path))
				player.volume_db = clampf(float(c.get("volume_db", -6)), -80, 6)
				add_child(player)
				player.finished.connect(player.queue_free)
				player.play()
			"custom": custom_command.emit(str(c.name), str(c.get("argument", "")), event_key)
			"transfer":
				pending_spawn = str(c.get("spawn", "Arrival"))
				current_event = null
				_set_busy(false)
				var error := get_tree().change_scene_to_file(str(c.scene))
				if error != OK: event_error.emit("场景切换失败：" + error_string(error))
				return error == OK
			"stop": break
		# Long synchronous lists must yield so cancellation and the editor remain responsive.
		if index % 64 == 63: await get_tree().process_frame
	if generation != token: return false
	current_event = null
	_set_busy(false)
	return true

func _test(c: Dictionary, event_key: String) -> bool:
	match c.op:
		"if_switch": return switches.get(c.key, false) == c.value
		"if_self_switch": return self_switches.get(event_key + "::" + str(c.key), false) == c.value
		"if_variable":
			var a := int(variables.get(c.key, 0))
			var b := int(c.value)
			match c.get("compare", ">="):
				"==": return a == b
				"!=": return a != b
				">=": return a >= b
				"<=": return a <= b
				">": return a > b
				"<": return a < b
	return false

func place_player(player: Node2D) -> void:
	if pending_position is Vector2:
		player.global_position = pending_position
		pending_position = null
		pending_spawn = ""
	elif not pending_spawn.is_empty() and get_tree().current_scene:
		var spawn := get_tree().current_scene.get_node_or_null(NodePath(pending_spawn))
		if spawn is Node2D: player.global_position = spawn.global_position
		else: event_error.emit("未找到出生点：" + pending_spawn)
		pending_spawn = ""

func save_game() -> Error:
	if busy: return ERR_BUSY
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("map_event_player") as Node2D
	if scene == null or scene.scene_file_path.is_empty() or player == null: return ERR_UNCONFIGURED
	var snapshot := {"version": 1, "switches": switches, "variables": variables, "self_switches": self_switches,
		"scene": scene.scene_file_path, "position": [player.global_position.x, player.global_position.y]}
	return write_snapshot(save_path, snapshot)

func write_snapshot(path: String, snapshot: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK: return directory_error
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return write_error
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK: return backup_error
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK and FileAccess.file_exists(path + ".bak"):
		DirAccess.rename_absolute(path + ".bak", path)
	return result

func validate_snapshot(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.get("version") != 1: return false
	for field in ["switches", "self_switches", "variables"]:
		if not snapshot.get(field) is Dictionary: return false
		for key in snapshot[field]:
			if not key is String: return false
			var value: Variant = snapshot[field][key]
			if field == "variables":
				if not Data._number(value) or float(value) != floor(float(value)): return false
			elif not value is bool: return false
	var pos: Variant = snapshot.get("position")
	if not pos is Array or pos.size() != 2: return false
	if not Data._number(pos[0]) or not Data._number(pos[1]): return false
	var scene: Variant = snapshot.get("scene")
	if not scene is String or not scene.begins_with("res://") or not ResourceLoader.exists(scene): return false
	return load(scene) is PackedScene

func load_game() -> Error:
	if busy: return ERR_BUSY
	if not FileAccess.file_exists(save_path): return ERR_FILE_NOT_FOUND
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not validate_snapshot(snapshot): return ERR_FILE_CORRUPT
	switches = snapshot.switches.duplicate(true)
	variables = snapshot.variables.duplicate(true)
	self_switches = snapshot.self_switches.duplicate(true)
	pending_position = Vector2(snapshot.position[0], snapshot.position[1])
	state_changed.emit()
	return get_tree().change_scene_to_file(snapshot.scene)

func reset_state() -> void:
	cancel()
	switches.clear()
	variables.clear()
	self_switches.clear()
	pending_spawn = ""
	pending_position = null
	state_changed.emit()
