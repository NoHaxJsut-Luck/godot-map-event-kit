@tool
class_name MEKEventData
extends Resource

## 从后向前选择第一个满足条件的事件页；指令运行时使用快照。
@export var title: String = "新事件"
@export var pages: Array[Dictionary] = []

static func default_page() -> Dictionary:
	return {"name": "第 1 页", "condition": "always", "key": "", "value": true,
		"trigger": "interact", "visual": "marker", "commands": [{"op": "text", "speaker": "", "text": "你好，冒险者！"}]}

static func default_command(op: String) -> Dictionary:
	match op:
		"text": return {"op": op, "speaker": "", "text": "请输入对话"}
		"choices": return {"op": op, "text": "请选择", "options": ["同意", "暂时不了"], "key": "choice"}
		"set_switch", "if_switch": return {"op": op, "key": "has_key", "value": true}
		"set_self_switch", "if_self_switch": return {"op": op, "key": "A", "value": true}
		"set_variable", "add_variable", "if_variable": return {"op": op, "key": "coins", "value": 1, "compare": ">="}
		"wait": return {"op": op, "seconds": 0.3}
		"transfer": return {"op": op, "scene": "", "spawn": "Arrival"}
		"sound": return {"op": op, "path": "", "volume_db": -6.0}
		"custom": return {"op": op, "name": "my_command", "argument": ""}
		_: return {"op": op}

static func validate(data: MEKEventData) -> PackedStringArray:
	var errors := PackedStringArray()
	if data == null:
		errors.append("没有事件资源。")
		return errors
	if data.pages.is_empty(): errors.append("至少需要一个事件页。")
	for pi in range(data.pages.size()):
		var page: Dictionary = data.pages[pi]
		var prefix := "第 %d 页：" % (pi + 1)
		if page.get("condition", "always") not in ["always", "switch", "self_switch", "variable"]:
			errors.append(prefix + "未知页条件。")
		elif page.get("condition", "always") != "always":
			if str(page.get("key", "")).strip_edges().is_empty(): errors.append(prefix + "页条件缺少键名。")
			if page.get("condition") == "variable":
				if not _number(page.get("value")): errors.append(prefix + "变量条件需要数字。")
			elif not page.get("value") is bool: errors.append(prefix + "开关条件需要布尔值。")
		if page.get("trigger", "interact") not in ["interact", "touch", "autorun"]:
			errors.append(prefix + "未知触发方式。")
		if not page.get("commands", []) is Array:
			errors.append(prefix + "指令列表格式错误。")
			continue
		var stack: Array[bool] = []
		for ci in range(page.get("commands", []).size()):
			var raw: Variant = page.commands[ci]
			var at := prefix + "指令 %d：" % (ci + 1)
			if not raw is Dictionary:
				errors.append(at + "指令格式错误。")
				continue
			var c: Dictionary = raw
			var op := str(c.get("op", ""))
			if op not in ["text", "choices", "set_switch", "set_self_switch", "set_variable", "add_variable", "if_switch", "if_self_switch", "if_variable", "else", "end", "wait", "transfer", "sound", "custom", "stop"]:
				errors.append(at + "未知指令 " + op)
			if op in ["set_switch", "set_self_switch", "set_variable", "add_variable", "if_switch", "if_self_switch", "if_variable", "choices"]:
				if str(c.get("key", "")).strip_edges().is_empty(): errors.append(at + "需要键名。")
			if op in ["set_switch", "set_self_switch", "if_switch", "if_self_switch"] and not c.get("value") is bool:
				errors.append(at + "开关值必须是布尔值。")
			if op in ["set_variable", "add_variable", "if_variable"] and not _number(c.get("value")):
				errors.append(at + "变量值必须是有限数字。")
			if op == "if_variable" and c.get("compare", ">=") not in ["==", "!=", ">=", "<=", ">", "<"]:
				errors.append(at + "未知比较方式。")
			if op.begins_with("if_"): stack.append(false)
			elif op == "else":
				if stack.is_empty(): errors.append(at + "否则缺少对应条件。")
				elif stack[-1]: errors.append(at + "一个条件只能有一个否则。")
				else: stack[-1] = true
			elif op == "end":
				if stack.is_empty(): errors.append(at + "结束分支缺少对应条件。")
				else: stack.pop_back()
			if op == "choices":
				var options: Variant = c.get("options", [])
				if not options is Array or options.size() < 2 or options.size() > 6:
					errors.append(at + "选项数量必须为 2～6。")
				else:
					for option in options:
						if not option is String or option.strip_edges().is_empty(): errors.append(at + "选项不能为空。")
			if op == "wait":
				if not _number(c.get("seconds")) or float(c.get("seconds", -1)) < 0 or float(c.get("seconds", 0)) > 60:
					errors.append(at + "等待时间应在 0～60 秒。")
			if op in ["transfer", "sound"]:
				var path := str(c.get("scene" if op == "transfer" else "path", ""))
				if not path.begins_with("res://") or not ResourceLoader.exists(path):
					errors.append(at + "资源路径不存在。")
				else:
					var resource := load(path)
					if op == "transfer" and not resource is PackedScene: errors.append(at + "传送目标必须是场景。")
					if op == "sound" and not resource is AudioStream: errors.append(at + "音效目标必须是音频。")
			if op == "custom" and str(c.get("name", "")).strip_edges().is_empty(): errors.append(at + "自定义指令需要名称。")
		if not stack.is_empty(): errors.append(prefix + "条件分支未闭合，请添加结束分支。")
	return errors

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and abs(float(value)) <= 1.0e9
