@tool
class_name MEKEventData
extends Resource

const I18n = preload("res://addons/map_event_kit/core/localization.gd")

## 从后向前选择第一个满足条件的事件页；指令运行时使用快照。
@export var title: String = "新事件"
@export var pages: Array[Dictionary] = []

static func default_page(locale: String = "zh_CN") -> Dictionary:
	return {"name": I18n.text("第 1 页", locale), "condition": "always", "key": "", "value": true,
		"trigger": "interact", "visual": "marker", "commands": [{"op": "text", "speaker": "", "text": I18n.text("你好，冒险者！", locale)}]}

static func default_command(op: String, locale: String = "zh_CN") -> Dictionary:
	match op:
		"text": return {"op": op, "speaker": "", "text": I18n.text("请输入对话", locale)}
		"choices": return {"op": op, "text": I18n.text("请选择", locale), "options": [I18n.text("同意", locale), I18n.text("暂时不了", locale)], "key": "choice"}
		"set_switch", "if_switch": return {"op": op, "key": "has_key", "value": true}
		"set_self_switch", "if_self_switch": return {"op": op, "key": "A", "value": true}
		"set_variable", "add_variable", "if_variable": return {"op": op, "key": "coins", "value": 1, "compare": ">="}
		"wait": return {"op": op, "seconds": 0.3}
		"transfer": return {"op": op, "scene": "", "spawn": "Arrival"}
		"sound": return {"op": op, "path": "", "volume_db": -6.0}
		"custom": return {"op": op, "name": "my_command", "argument": ""}
		_: return {"op": op}

static func validate(data: MEKEventData, locale: String = "zh_CN") -> PackedStringArray:
	var errors := PackedStringArray()
	if data == null:
		errors.append(I18n.text("没有事件资源。", locale))
		return errors
	if data.pages.is_empty(): errors.append(I18n.text("至少需要一个事件页。", locale))
	for pi in range(data.pages.size()):
		var page: Dictionary = data.pages[pi]
		var prefix := I18n.text("第 %d 页：", locale) % (pi + 1)
		if page.get("condition", "always") not in ["always", "switch", "self_switch", "variable"]:
			errors.append(prefix + I18n.text("未知页条件。", locale))
		elif page.get("condition", "always") != "always":
			if str(page.get("key", "")).strip_edges().is_empty(): errors.append(prefix + I18n.text("页条件缺少键名。", locale))
			if page.get("condition") == "variable":
				if not _number(page.get("value")): errors.append(prefix + I18n.text("变量条件需要数字。", locale))
			elif not page.get("value") is bool: errors.append(prefix + I18n.text("开关条件需要布尔值。", locale))
		if page.get("trigger", "interact") not in ["interact", "touch", "autorun"]:
			errors.append(prefix + I18n.text("未知触发方式。", locale))
		if not page.get("commands", []) is Array:
			errors.append(prefix + I18n.text("指令列表格式错误。", locale))
			continue
		var stack: Array[bool] = []
		for ci in range(page.get("commands", []).size()):
			var raw: Variant = page.commands[ci]
			var at := prefix + I18n.text("指令 %d：", locale) % (ci + 1)
			if not raw is Dictionary:
				errors.append(at + I18n.text("指令格式错误。", locale))
				continue
			var c: Dictionary = raw
			var op := str(c.get("op", ""))
			if op not in ["text", "choices", "set_switch", "set_self_switch", "set_variable", "add_variable", "if_switch", "if_self_switch", "if_variable", "else", "end", "wait", "transfer", "sound", "custom", "stop"]:
				errors.append(at + I18n.text("未知指令 ", locale) + op)
			if op in ["set_switch", "set_self_switch", "set_variable", "add_variable", "if_switch", "if_self_switch", "if_variable", "choices"]:
				if str(c.get("key", "")).strip_edges().is_empty(): errors.append(at + I18n.text("需要键名。", locale))
			if op in ["set_switch", "set_self_switch", "if_switch", "if_self_switch"] and not c.get("value") is bool:
				errors.append(at + I18n.text("开关值必须是布尔值。", locale))
			if op in ["set_variable", "add_variable", "if_variable"] and not _number(c.get("value")):
				errors.append(at + I18n.text("变量值必须是有限数字。", locale))
			if op == "if_variable" and c.get("compare", ">=") not in ["==", "!=", ">=", "<=", ">", "<"]:
				errors.append(at + I18n.text("未知比较方式。", locale))
			if op.begins_with("if_"): stack.append(false)
			elif op == "else":
				if stack.is_empty(): errors.append(at + I18n.text("否则缺少对应条件。", locale))
				elif stack[-1]: errors.append(at + I18n.text("一个条件只能有一个否则。", locale))
				else: stack[-1] = true
			elif op == "end":
				if stack.is_empty(): errors.append(at + I18n.text("结束分支缺少对应条件。", locale))
				else: stack.pop_back()
			if op == "choices":
				var options: Variant = c.get("options", [])
				if not options is Array or options.size() < 2 or options.size() > 6:
					errors.append(at + I18n.text("选项数量必须为 2～6。", locale))
				else:
					for option in options:
						if not option is String or option.strip_edges().is_empty(): errors.append(at + I18n.text("选项不能为空。", locale))
			if op == "wait":
				if not _number(c.get("seconds")) or float(c.get("seconds", -1)) < 0 or float(c.get("seconds", 0)) > 60:
					errors.append(at + I18n.text("等待时间应在 0～60 秒。", locale))
			if op in ["transfer", "sound"]:
				var path := str(c.get("scene" if op == "transfer" else "path", ""))
				if not path.begins_with("res://") or not ResourceLoader.exists(path):
					errors.append(at + I18n.text("资源路径不存在。", locale))
				else:
					var resource := load(path)
					if op == "transfer" and not resource is PackedScene: errors.append(at + I18n.text("传送目标必须是场景。", locale))
					if op == "sound" and not resource is AudioStream: errors.append(at + I18n.text("音效目标必须是音频。", locale))
			if op == "custom" and str(c.get("name", "")).strip_edges().is_empty(): errors.append(at + I18n.text("自定义指令需要名称。", locale))
		if not stack.is_empty(): errors.append(prefix + I18n.text("条件分支未闭合，请添加结束分支。", locale))
	return errors

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and abs(float(value)) <= 1.0e9
