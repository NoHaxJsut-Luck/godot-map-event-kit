extends Node

signal changed
const CoreI18n = preload("res://addons/map_event_kit/core/localization.gd")
const LANGUAGES := ["auto", "en", "ja", "ko", "zh_CN"]
const NAMES := ["Auto", "English", "日本語", "한국어", "简体中文"]
const MESSAGES := {
	"跟随系统": ["System language", "システム言語", "시스템 언어"],
	"一个宝箱，一把钥匙，一段由你编排的冒险。": ["A chest, a key, an adventure you create.", "宝箱と鍵から始まる、あなたが作る冒険。", "상자와 열쇠로 시작하는, 직접 만드는 모험."],
	"02   静谧遗迹": ["02   Silent Ruins", "02   静寂の遺跡", "02   고요한 유적"],
	"01   苔石小院": ["01   Mossstone Courtyard", "01   苔石の中庭", "01   이끼돌 안뜰"],
	"事件观察窗": ["Event observer", "イベントモニター", "이벤트 모니터"],
	"状态随你的选择实时变化": ["Your choices change the state", "選択に応じて状態が変化します", "선택에 따라 상태가 바뀝니다"],
	"最近执行": ["Recent actions", "最近の実行", "최근 실행"],
	"靠近一个地图事件\n按 E 或回车开始。": ["Approach an event.\nPress E or Enter to begin.", "イベントに近づいて\nE または Enter を押してください。", "이벤트에 다가가\nE 또는 Enter를 누르세요."],
	"WASD / 方向键移动     E / 回车交互": ["WASD / Arrows: move     E / Enter: interact", "WASD / 矢印キー：移動     E / Enter：調べる", "WASD / 방향키: 이동     E / Enter: 상호작용"],
	"先和守门人聊聊，再找到宝箱中的钥匙。": ["Talk to the guard, then find the key in the chest.", "門番と話してから、宝箱の鍵を探しましょう。", "문지기와 대화한 뒤 상자에서 열쇠를 찾으세요."],
	"读取": ["Load", "ロード", "불러오기"],
	"重置": ["Reset", "リセット", "초기화"],
	"本演示使用自绘几何图形，无外部游戏素材。": ["Original geometric artwork; no external game assets.", "自作の図形を使用しています。外部のゲーム素材は使っていません。", "직접 그린 도형을 사용하며 외부 게임 소재는 사용하지 않습니다."],
	"钥匙开关    %s\n宝箱独立开关    %s\n金币变量    %d\n抵达遗迹    %s": ["Key switch    %s\nChest self switch    %s\nCoins    %d\nVisited ruins    %s", "鍵スイッチ    %s\n宝箱セルフスイッチ    %s\n所持金    %d\n遺跡に到着    %s", "열쇠 스위치    %s\n상자 셀프 스위치    %s\n금화    %d\n유적 도착    %s"],
	"是": ["Yes", "はい", "예"],
	"否": ["No", "いいえ", "아니요"],
	"已保存：地图、位置、开关、变量和宝箱状态。": ["Saved: map, position, switches, variables and chest state.", "マップ、位置、スイッチ、変数、宝箱の状態を保存しました。", "맵, 위치, 스위치, 변수, 상자 상태를 저장했습니다."],
	"还没有存档。": ["No save file yet.", "セーブデータがありません。", "아직 저장 파일이 없습니다."],
	"读取失败：%s": ["Load failed: %s", "ロード失敗：%s", "불러오기 실패: %s"],
	"语言偏好保存失败：%s": ["Could not save language preference: %s", "言語設定を保存できませんでした：%s", "언어 설정을 저장하지 못했습니다: %s"],
	"事件进行中 · 使用鼠标或方向键 / 回车选择": ["Event active · Choose with the mouse or arrows / Enter", "イベント実行中 · マウスまたは矢印キー / Enter で選択", "이벤트 진행 중 · 마우스 또는 방향키 / Enter로 선택"],
	"E / 回车  ·  ": ["E / Enter  ·  ", "E / Enter  ·  ", "E / Enter  ·  "],
	"守门人": ["Guard", "門番", "문지기"],
	"旧宝箱": ["Old chest", "古い宝箱", "오래된 상자"],
	"遗迹门": ["Ruins gate", "遺跡の門", "유적 문"],
	"返回小院": ["Return to courtyard", "中庭に戻る", "안뜰로 돌아가기"],
	"回响石碑": ["Echo stone", "こだまの石碑", "메아리 비석"],
	"事件": ["Event", "イベント", "이벤트"],
	"继续  ↵": ["Continue  ↵", "続ける  ↵", "계속  ↵"],
	"你掀开了宝箱。里面是一把铜钥匙和 10 枚金币。": ["You open the chest. Inside are a copper key and 10 gold coins.", "宝箱を開けると、銅の鍵と金貨10枚が入っていました。", "상자를 열었습니다. 안에는 구리 열쇠와 금화 10개가 있습니다."],
	"获得铜钥匙 × 1，金币 +10。\n再来调查时，宝箱会记住自己已经被打开。": ["Obtained 1 copper key and 10 gold coins.\nThe chest will remember that it has already been opened.", "銅の鍵を1つ、金貨を10枚手に入れました。\nもう一度調べても、宝箱は開封済みの状態を覚えています。", "구리 열쇠 1개와 금화 10개를 얻었습니다.\n다시 조사해도 상자는 이미 열린 상태를 기억합니다."],
	"宝箱已经空了。\n你不会重复获得里面的物品。": ["The chest is empty.\nYou cannot collect its contents again.", "宝箱は空です。\n中身を繰り返し手に入れることはできません。", "상자는 비어 있습니다.\n안에 있던 물건을 다시 얻을 수는 없습니다."],
	"欢迎来到苔石小院。遗迹的门需要一把铜钥匙。\n这里的对话、宝箱和门，都由事件列表驱动。": ["Welcome to Mossstone Courtyard. You need a copper key to open the ruins gate.\nThe conversations, chest and gate here are all controlled by event lists.", "苔石の中庭へようこそ。遺跡の門を開けるには銅の鍵が必要です。\nここの会話も宝箱も門も、イベントリストで動いています。", "이끼돌 안뜰에 오신 것을 환영합니다. 유적 문을 열려면 구리 열쇠가 필요합니다.\n이곳의 대화, 상자, 문은 모두 이벤트 목록으로 동작합니다."],
	"需要我给你一点提示吗？": ["Would you like a hint?", "ヒントが必要ですか？", "힌트가 필요하신가요?"],
	"请给我提示": ["Give me a hint", "ヒントをください", "힌트를 주세요"],
	"我自己探索": ["I'll explore on my own", "自分で探索します", "직접 탐험할게요"],
	"你已经拿到钥匙了！去小院北侧的遗迹门吧。": ["You already have the key! Head to the ruins gate on the north side of the courtyard.", "もう鍵を手に入れたのですね！中庭の北側にある遺跡の門へ向かいましょう。", "이미 열쇠를 찾으셨군요! 안뜰 북쪽에 있는 유적 문으로 가세요."],
	"看看小路右侧的宝箱。按 E 或回车就能调查它。": ["Look inside the chest to the right of the path. Press E or Enter to examine it.", "小道の右側にある宝箱を見てください。E または Enter で調べられます。", "길 오른쪽에 있는 상자를 살펴보세요. E 또는 Enter로 조사할 수 있습니다."],
	"好奇心会为你指路。祝你探索愉快。": ["Let your curiosity guide you. Enjoy exploring!", "好奇心が道を教えてくれるでしょう。探索を楽しんでください。", "호기심이 길을 안내해 줄 거예요. 즐거운 탐험 되세요!"],
	"铜钥匙恰好与锁孔吻合。\n通往遗迹的门打开了。": ["The copper key fits the lock perfectly.\nThe gate to the ruins opens.", "銅の鍵が鍵穴にぴったり合いました。\n遺跡へ続く門が開きます。", "구리 열쇠가 자물쇠에 꼭 맞습니다.\n유적으로 향하는 문이 열렸습니다."],
	"门锁着。\n需要先找到铜钥匙。": ["The gate is locked.\nFind the copper key first.", "門には鍵がかかっています。\n先に銅の鍵を探しましょう。", "문이 잠겨 있습니다.\n먼저 구리 열쇠를 찾아야 합니다."],
	"你抵达了静谧遗迹。\n这是进入地图时自动执行的事件。": ["You have arrived at the Silent Ruins.\nThis event runs automatically when you enter the map.", "静寂の遺跡に到着しました。\nこれはマップに入ると自動で実行されるイベントです。", "고요한 유적에 도착했습니다.\n이 이벤트는 맵에 들어오면 자동으로 실행됩니다."],
	"可以保存后重启，再读取进度。\n返回小院后，宝箱的独立开关仍然有效。": ["Save, restart, and load your progress.\nThe chest's self switch stays set when you return to the courtyard.", "保存して再起動した後、続きから再開できます。\n中庭に戻っても、宝箱のセルフスイッチは保持されます。", "저장한 뒤 재시작하여 진행 상황을 불러올 수 있습니다.\n안뜰로 돌아가도 상자의 셀프 스위치는 유지됩니다."],
	"路牌：北侧是遗迹，东侧藏着一只旧宝箱。\n离开这块区域后，再走近可以重新触发。": ["Sign: Ruins to the north. An old chest is hidden to the east.\nLeave this area and approach again to trigger this event once more.", "看板：北に遺跡、東には古い宝箱が隠されています。\nこの場所から離れて近づくと、もう一度イベントが発生します。", "표지판: 북쪽에는 유적이 있고 동쪽에는 오래된 상자가 숨겨져 있습니다.\n이 구역을 벗어났다가 다시 다가오면 이벤트가 다시 실행됩니다."],
}
const EVENT_NAMES := {"guide_01":"守门人", "chest_01":"旧宝箱", "gate_01":"遗迹门", "sign_01":"路牌", "return_01":"返回小院", "arrival_01":"回响石碑"}
const OPS := {"text":"显示文字", "choices":"显示选项", "set_switch":"设置全局开关", "set_self_switch":"设置独立开关", "set_variable":"设置变量", "add_variable":"增加变量", "if_switch":"条件：全局开关", "if_self_switch":"条件：独立开关", "if_variable":"条件：变量", "else":"否则", "end":"结束分支", "wait":"等待", "transfer":"切换地图", "sound":"播放音效", "custom":"自定义指令", "stop":"结束事件"}
var choice := "auto"
var language := "en"
var settings_path := "user://map_event_kit/demo_settings.cfg"

func _ready() -> void:
	load_preference()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-language="):
			set_language(arg.trim_prefix("--demo-language="), false)

func load_preference() -> void:
	var config := ConfigFile.new()
	var saved := "auto"
	if config.load(settings_path) == OK: saved = str(config.get_value("demo", "language", "auto"))
	set_language(saved, false)

func set_language(value: String, persist := true) -> Error:
	choice = value if value in LANGUAGES else "auto"
	language = CoreI18n.resolve(OS.get_locale_language() if choice == "auto" else choice)
	get_parent().set_text_translator(text)
	changed.emit()
	if not persist: return OK
	var error := DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	if error != OK: return error
	var config := ConfigFile.new()
	config.set_value("demo", "language", choice)
	return config.save(settings_path)

func text(source: String) -> String:
	if language == "zh_CN": return source
	if not MESSAGES.has(source): return CoreI18n.text(source, language)
	return str(MESSAGES[source][["en", "ja", "ko"].find(language)])
