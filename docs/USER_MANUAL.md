# Map Event Kit User Manual

Version **0.1.0-alpha** · 2026-10-17 · [GitHub source](https://github.com/NoHaxJsut-Luck/godot-map-event-kit) · [Technical documentation](TECHNICAL.md)

[English](#english) · [日本語](#日本語) · [한국어](#한국어) · [中文](#中文)

## English

### Start here

Map Event Kit adds RPG Maker style event pages and command lists to Godot. Use it for NPC conversations, treasure chests, switches and map transfers. This manual covers installation and everyday editing.

Use **Godot 4.7.2 Standard**, with the Compatibility renderer, for the tested setup. Windows is the tested platform; other Godot 4 versions and platforms are unverified. Godot 3 is unsupported. **The plugin interface and demo are currently in Chinese.** This manual is available in four languages; the Chinese labels below identify the actual buttons. There is no interface language selector yet.

Download the repository using **Code → Download ZIP**, extract it, and import `project.godot` in Godot. Press **F5**. On Windows, the supplied `Launch Demo.cmd` and `Open Editor.cmd` also work when Godot is discoverable; otherwise use Godot's project manager. The engine is not included.

Move with **WASD / arrow keys**. Approach an event and press **E / Enter / Space**. Click dialogue buttons, or select a focused button with the keyboard and confirm. Try the locked gate, open the chest twice, then enter the ruins. The chest should award only ten coins. Save in the ruins, restart and load to check persistence. The demo's reset button clears current progress but keeps the disk save.

### Install in your project

1. Start with a copy of your project. Copy only `addons/map_event_kit` into its `addons` folder; keep its own `project.godot`.
2. Open **Project → Project Settings → Plugins** and enable **Map Event Kit / 地图事件工坊**. Wait for the initial import to finish. The plugin registers the `MapEvents` autoload.
3. If your project already uses an autoload named `MapEvents`, resolve that conflict before continuing. The plugin does not replace it.
4. In your map scene, add a **MEKMapEvent** node. Set **Event Id** to a unique value such as `village_npc_01`. Set **Display Name** to its visible label. Save the scene.
5. Add your `Node2D` player to the **map_event_player** group. For a `CharacterBody2D` player, merge the following into the existing script; do not create a second `_ready()` or `_physics_process()`.

```gdscript
func _ready() -> void:
    add_to_group("map_event_player")
    MapEvents.place_player.call_deferred(self)

func _physics_process(delta: float) -> void:
    if MapEvents.busy:
        velocity = Vector2.ZERO
        return
    # Keep your existing movement code here.
```

The demo already includes this integration. Your project needs its own movement and map collisions. Blank-project installation has passed; compatibility with arbitrary existing projects has not been verified. Check existing input, dialogue and save systems when integrating.

### Create your first conversation

1. Click **地图事件** in Godot's main screen tabs, then **新建事件** (New event).
2. In the left column, leave **出现条件 → 无条件** (Condition → Always) and **触发方式 → 确认键交互** (Trigger → Interact). Set **示例外观 → 角色** (Appearance → NPC). Click **应用事件页** (Apply page).
3. Select the default **显示文字** (Show text) command in the middle column. On the right, enter **说话人** (Speaker) and **消息内容** (Message), then click **应用指令** (Apply command).
4. Click **另存为…** (Save as) and save as `res://events/village_npc.tres`; create the `events` folder if necessary.
5. Return to the 2D scene and select your event node. Drag the saved resource into its **Data** property. Save the scene.
6. Run the game, approach the event and press E.

**Apply, then save.** Text entered into a form is not committed until you click its Apply button. Apply the event name with **应用名称**. Save before switching resources or closing the editor. Stop and restart the game to test edits.

### Edit commands and pages

| Task | Button or field |
|---|---|
| Open an existing resource | 打开事件…; or double-click its `.tres` file |
| Add a command | Select its type, then + 插入; inserted after the selected command |
| Duplicate or remove a command | 复制指令 / 删除 |
| Reorder commands | 上移 / 下移 |
| Add, copy or remove a page | + 页 / 复制 / 删除 in the left column |
| Change page priority | ↑ / ↓ in the left column |
| Undo or redo applied edits | 撤销 / 重做 |
| Validate and save | 检查事件, then 保存 |

The **lowest matching page** in the list wins. Choose one condition per page: **无条件** (Always), **全局开关** (Global switch), **独立开关** (Self switch), or **变量阈值** (Variable at least the specified value). Unset switches are false; unset variables are zero.

**确认键交互** uses E or `ui_accept`, within **Interaction Radius** (default 64 pixels). **靠近触发** fires when the player enters a 30-pixel radius; it is not a collision trigger. **自动执行** runs once on entering the active page and can run again after a page change or scene reload. Only one event runs at a time.

### Make a chest that opens once

Create two pages, in this order. Apply every edited command and page, then save.

| Setting | Page 1 | Page 2 |
|---|---|---|
| Condition | 无条件 | 独立开关, key `A`, ON |
| Trigger | 确认键交互 | 确认键交互 |
| Appearance | 关闭的宝箱 | 打开的宝箱 |
| Commands in order | 增加变量: `coins`, 10; 设置独立开关: `A`, ON; 显示文字: “Found 10 coins!” | 显示文字: “The chest is empty.” |

Page 2 must be below page 1. Run the game and interact twice. Coins increase only once. Reuse the same event resource for another chest, but give that node a different **Event Id**. To keep progress across restarts, save the game.

### Choices and branches

Insert **显示选项** (Show choices), enter a question and 2–6 options, one per line, and set the result variable to `answer`. The first option writes **0**, the second **1**. Follow it with this list:

```text
条件：变量     answer == 0
  显示文字    You chose the first option.
否则
  显示文字    You chose another option.
结束分支
```

Add these as individual commands; the editor displays indentation automatically. Each condition needs **结束分支** (End branch). **结束事件** ends the entire event instead. Use **检查事件** to catch missing branch endings.

### Transfer to another map

Save the destination scene, for example `res://maps/ruins.tscn`. Add a `Marker2D` named `Arrival` directly below its root and position it at the entrance. Include a player with the integration above. Add **切换地图** (Transfer), set the scene path and spawn path `Arrival`, apply and save. A nested marker uses a relative path such as `Spawns/Arrival`. Transfer ends the current command list; commands after it do not run.

### Command reference

| Command in the editor | What to enter or expect |
|---|---|
| 显示文字 | Speaker and message; waits for confirmation |
| 显示选项 | Question, 2–6 option lines, result variable; zero-based result |
| 设置全局开关 | Switch name and ON/OFF; shared between maps |
| 设置独立开关 | Switch name and ON/OFF; local to this event identity |
| 设置变量 | Variable name and integer value |
| 增加变量 | Variable name and integer amount; negative values subtract |
| 条件：全局开关 | Switch name and expected ON/OFF |
| 条件：独立开关 | Self-switch name and expected ON/OFF |
| 条件：变量 | Variable, comparison and integer value |
| 否则 | Optional alternative inside a condition |
| 结束分支 | Close the current condition |
| 等待 | Duration from 0 to 60 seconds |
| 切换地图 | Existing `res://` scene and relative spawn path |
| 播放音效 | Existing `res://` audio path and volume in dB; does not wait |
| 自定义指令 | Command name and text argument; requires a code handler |
| 结束事件 | Stop this event immediately |

### Save progress and resolve problems

The demo has Save and Load buttons. In your own UI, call `MapEvents.save_game()` and `MapEvents.load_game()` and check the returned `Error` for `OK`. Both reject requests while an event is active. The default path is `user://map_event_kit/save_01.json`, with a `.bak` of the previous save. Only event switches, variables, scene and player position are included; add your inventory and other game data through your own save integration.

| Problem | Action |
|---|---|
| No 地图事件 tab or MEKMapEvent node | Enable the plugin, wait for import, then reopen the project if necessary. |
| E does nothing | Check Data, unique Event Id, player group, active-page condition and distance. Check whether another Control consumes the key. |
| Changes disappeared | Click 应用指令 / 应用事件页 before 保存. |
| Chest gives rewards again | Put the self-switch page last, enable A on page 1, and avoid changing the scene path or Event Id after saving. |
| Player moves during dialogue | Add the `MapEvents.busy` check to every movement path in your controller. |
| Player appears at the wrong entrance | Check the marker path and the deferred `place_player` call. |
| Save/load fails | Close the event first; check return codes and ensure the scene is saved and a player is registered. |

This Alpha provides map events. It does not include battles, an inventory database, movement routes, parallel events, multiplayer, RPG Maker project import or save migration. See the [technical document](TECHNICAL.md) for custom commands and integration details. Source and bundled demo assets use the repository's [MIT license](../LICENSE).

## 日本語

### はじめに

Map Event Kit は、RPG Maker 風のイベントページとコマンドリストを Godot に追加するプラグインです。NPC との会話、宝箱、スイッチ、マップ移動を作れます。

動作確認済みの環境は **Windows、Godot 4.7.2 Standard、Compatibility レンダラー**です。ほかの Godot 4 バージョンと OS は未検証で、Godot 3 には対応していません。**現在、プラグインの画面とデモは中国語です。** 本マニュアルは4言語対応ですが、画面の言語切り替え機能はありません。以下では実際の中国語ラベルを併記します。

[GitHub](https://github.com/NoHaxJsut-Luck/godot-map-event-kit) の **Code → Download ZIP** から取得して展開し、Godot で `project.godot` をインポートして **F5** を押します。Windows 用の `Launch Demo.cmd` と `Open Editor.cmd` は Godot が検出できる環境で利用できます。検出できない場合は Godot のプロジェクトマネージャーを使ってください。エンジンは同梱していません。

**WASD / 方向キー**で移動し、イベントに近づいて **E / Enter / Space** で調べます。会話ボタンはクリック、またはキーボードで選択して決定できます。鍵のかかった門を調べ、宝箱を2回開けてから遺跡へ進んでください。コインが10枚だけ増えることを確認します。遺跡で保存し、再起動後に読み込むと進行状況を復元できます。デモのリセットは現在の進行状況を消しますが、保存ファイルは削除しません。

### 自分のプロジェクトに導入する

1. プロジェクトのコピーで作業します。`addons/map_event_kit` だけをコピー先の `addons` に入れます。既存の `project.godot` はそのまま使用してください。
2. **プロジェクト → プロジェクト設定 → プラグイン**で **Map Event Kit / 地图事件工坊** を有効にし、インポート完了を待ちます。`MapEvents` が自動ロードに追加されます。
3. 同名の自動ロードがすでにある場合は、先に名前の競合を解消します。プラグインは既存のものを上書きしません。
4. マップシーンに **MEKMapEvent** ノードを追加します。**Event Id** に `village_npc_01` など、同じマップで重複しない値を設定し、**Display Name** に表示名を入力してシーンを保存します。
5. `Node2D` のプレイヤーを **map_event_player** グループに登録します。`CharacterBody2D` を使う場合は、既存のスクリプトに次を組み込みます。同じ関数を二重に定義しないでください。

```gdscript
func _ready() -> void:
    add_to_group("map_event_player")
    MapEvents.place_player.call_deferred(self)

func _physics_process(delta: float) -> void:
    if MapEvents.busy:
        velocity = Vector2.ZERO
        return
    # ここに既存の移動処理を残します。
```

デモでは接続済みです。自分のプロジェクトでは移動処理とマップの衝突判定を用意してください。空のプロジェクトへの導入は検証済みですが、任意の既存プロジェクトでの互換性は未検証です。入力、会話、セーブの既存システムとの接続を確認してください。

### 最初の会話を作る

1. Godot 上部の **地图事件** を開き、**新建事件**（新規イベント）を押します。
2. 左側で **出现条件 → 无条件**（出現条件 → 無条件）、**触发方式 → 确认键交互**（トリガー → 決定キー）を選びます。**示例外观 → 角色**（仮の外観 → NPC）を選んで **应用事件页**（ページを適用）を押します。
3. 中央の **显示文字**（文章の表示）を選び、右側の **说话人**（話者）と **消息内容**（本文）を編集して **应用指令**（コマンドを適用）を押します。
4. **另存为…**（名前を付けて保存）で `res://events/village_npc.tres` に保存します。必要なら `events` フォルダーを作成します。
5. 2D 画面に戻り、イベントノードの **Data** に保存したリソースをドラッグします。シーンを保存します。
6. ゲームを実行し、近づいて E を押します。

**適用してから保存してください。** 入力しただけではリソースに反映されません。名前は **应用名称** で適用します。別のリソースを開く前や終了前に保存し、変更を試すときはゲームを再起動します。

### 編集操作とページの選び方

| 操作 | 中国語のボタン |
|---|---|
| 開く | 打开事件…、または `.tres` をダブルクリック |
| コマンドを追加 | 種類を選択して + 插入。選択中のコマンドの直後に追加 |
| コマンドを複製・削除 | 复制指令 / 删除 |
| コマンドを並べ替え | 上移 / 下移 |
| ページを追加・複製・削除 | 左側の + 页 / 复制 / 删除 |
| ページの優先順位を変更 | 左側の ↑ / ↓ |
| 元に戻す・やり直す | 撤销 / 重做 |
| 検査・保存 | 检查事件 → 保存 |

条件を満たすページのうち、**一番下のページが優先**されます。条件は **无条件**（無条件）、**全局开关**（共通スイッチ）、**独立开关**（セルフスイッチ）、**变量阈值**（変数が指定値以上）のいずれか1つです。未設定のスイッチは OFF、変数は0として扱います。

**确认键交互** は E または `ui_accept` で起動し、距離は **Interaction Radius**（初期値64ピクセル）です。**靠近触发** は30ピクセル未満の範囲に入ると起動し、衝突判定ではありません。**自动执行** はそのページが有効になったときに1回実行され、ページ切り替えやシーンの再読み込みで再実行できます。同時に実行できるイベントは1つです。

### 一度だけ開く宝箱

次の順序で2ページを作り、各変更を適用して保存します。

| 項目 | ページ1 | ページ2 |
|---|---|---|
| 条件 | 无条件 | 独立开关、名前 `A`、ON |
| 起動方法 | 确认键交互 | 确认键交互 |
| 外観 | 关闭的宝箱 | 打开的宝箱 |
| コマンドの順序 | 增加变量：`coins` に10加算 → 设置独立开关：`A` を ON → 显示文字：「10コインを手に入れた！」 | 显示文字：「空っぽだ。」 |

ページ2を下に置き、2回調べてコインが1回だけ増えることを確認します。同じリソースを別の宝箱に使うときは、ノードの **Event Id** を変えてください。再起動後も状態を残すにはゲームを保存します。

### 選択肢と条件分岐

**显示选项**（選択肢の表示）で質問、1行1項目の選択肢を2～6個、結果変数 `answer` を入力します。最初の選択肢は **0**、2番目は **1** です。続けて次のコマンドを個別に追加します。

```text
条件：变量     answer == 0
  显示文字    最初の選択肢を選びました。
否则
  显示文字    ほかの選択肢を選びました。
结束分支
```

字下げは自動表示されます。条件ごとに **结束分支**（分岐終了）が必要です。**结束事件** はイベント全体を終了する別のコマンドです。**检查事件** で閉じ忘れを確認できます。

### 別のマップへ移動する

移動先を `res://maps/ruins.tscn` などに保存し、そのルート直下に `Arrival` という `Marker2D` を置きます。上記の接続済みプレイヤーも配置します。**切换地图**（マップ移動）にシーンのパスと出現地点 `Arrival` を入力して適用・保存します。マーカーが入れ子なら `Spawns/Arrival` のようにルートからの相対パスを指定します。移動すると現在のコマンドリストは終了し、後続のコマンドは実行されません。

### コマンド一覧

| 中国語のコマンド | 設定と動作 |
|---|---|
| 显示文字 | 話者と本文。決定を待つ |
| 显示选项 | 質問、2～6個の選択肢、結果変数。結果は0から |
| 设置全局开关 | 全マップ共通のスイッチ名と ON/OFF |
| 设置独立开关 | このイベント専用のスイッチ名と ON/OFF |
| 设置变量 | 変数名と整数値 |
| 增加变量 | 変数名と加算値。負の値で減算 |
| 条件：全局开关 | 共通スイッチ名と比較する ON/OFF |
| 条件：独立开关 | セルフスイッチ名と比較する ON/OFF |
| 条件：变量 | 変数名、比較方法、整数値 |
| 否则 | 条件を満たさない場合の処理 |
| 结束分支 | 現在の条件分岐を閉じる |
| 等待 | 0～60秒待つ |
| 切换地图 | 存在する `res://` シーンと出現地点の相対パス |
| 播放音效 | 存在する `res://` 音声ファイルと音量 dB。再生終了は待たない |
| 自定义指令 | 名前と文字列引数。受け取り側のコードが必要 |
| 结束事件 | イベントを終了する |

### 保存とトラブル対処

デモには保存・読み込みボタンがあります。自作 UI からは `MapEvents.save_game()` と `MapEvents.load_game()` を呼び、戻り値の `Error` が `OK` か確認します。イベント実行中は保存も読み込みも拒否されます。標準の保存先は `user://map_event_kit/save_01.json` で、前回分を `.bak` に保持します。保存対象はイベントのスイッチ、変数、シーン、プレイヤー位置です。所持品などは独自のセーブ処理に接続してください。

| 症状 | 確認すること |
|---|---|
| タブやノードが見つからない | プラグインを有効化し、インポートを待つ。必要ならプロジェクトを開き直す |
| E で起動しない | Data、重複しない Event Id、プレイヤーのグループ、ページ条件、距離、入力を消費する Control を確認 |
| 編集が消える | 应用指令 / 应用事件页 を押してから 保存 |
| 宝箱の報酬が繰り返される | セルフスイッチのページを最後に置き、ページ1で A を ON にする。保存後にシーンパスや Event Id を変更しない |
| 会話中も移動する | すべての移動処理で `MapEvents.busy` を確認 |
| 出現位置が違う | マーカーのパスと遅延呼び出しの `place_player` を確認 |
| 保存・読み込みに失敗する | イベントを終了し、戻り値、シーンの保存、プレイヤーの登録を確認 |

この Alpha に戦闘、所持品データベース、移動ルート、並列イベント、マルチプレイ、RPG Maker プロジェクトの取り込み、セーブデータ移行は含まれません。拡張方法は[英語の技術文書](TECHNICAL.md)を参照してください。ソースと同梱デモ素材のライセンスは [MIT](../LICENSE) です。

## 한국어

### 시작하기

Map Event Kit는 Godot에 RPG Maker 방식의 이벤트 페이지와 명령 목록을 추가하는 플러그인입니다. NPC 대화, 보물 상자, 스위치, 맵 이동을 만들 수 있습니다.

검증 환경은 **Windows, Godot 4.7.2 Standard, Compatibility 렌더러**입니다. 다른 Godot 4 버전과 운영체제는 미검증이며 Godot 3은 지원하지 않습니다. **현재 플러그인 화면과 데모는 중국어입니다.** 이 매뉴얼은 네 언어로 제공되지만 화면 언어 전환 기능은 없습니다. 아래에는 실제 중국어 버튼 이름을 함께 표시합니다.

[GitHub](https://github.com/NoHaxJsut-Luck/godot-map-event-kit)에서 **Code → Download ZIP**으로 내려받아 압축을 풉니다. Godot에서 `project.godot`를 가져온 뒤 **F5**를 누릅니다. Windows의 `Launch Demo.cmd`와 `Open Editor.cmd`는 Godot을 찾을 수 있을 때 사용할 수 있습니다. 찾지 못하면 Godot 프로젝트 관리자를 이용하세요. 엔진은 포함되어 있지 않습니다.

**WASD / 방향키**로 이동하고 이벤트에 접근해 **E / Enter / Space**로 상호작용합니다. 대화 버튼을 클릭하거나 키보드로 선택하고 확인하세요. 잠긴 문을 조사한 뒤 상자를 두 번 열고 유적으로 이동해 보세요. 동전은 총 10개만 증가해야 합니다. 유적에서 저장하고 게임을 다시 실행해 불러오세요. 데모의 초기화 버튼은 현재 진행 상태만 지우며 저장 파일은 삭제하지 않습니다.

### 기존 프로젝트에 설치하기

1. 프로젝트 복사본에서 시작하세요. `addons/map_event_kit`만 자신의 `addons` 폴더에 복사합니다. 기존 `project.godot`는 유지하세요.
2. **프로젝트 → 프로젝트 설정 → 플러그인**에서 **Map Event Kit / 地图事件工坊**을 활성화하고 가져오기가 끝날 때까지 기다립니다. `MapEvents` 자동 로드가 등록됩니다.
3. 이미 같은 이름의 자동 로드가 있다면 이름 충돌을 먼저 해결하세요. 플러그인은 기존 항목을 덮어쓰지 않습니다.
4. 맵 씬에 **MEKMapEvent** 노드를 추가합니다. **Event Id**에 같은 맵에서 중복되지 않는 `village_npc_01` 같은 값을 입력하고, **Display Name**에 표시 이름을 입력한 뒤 씬을 저장합니다.
5. `Node2D` 플레이어를 **map_event_player** 그룹에 넣습니다. `CharacterBody2D` 플레이어라면 아래 내용을 기존 스크립트에 합치세요. 같은 함수를 중복으로 만들지 마세요.

```gdscript
func _ready() -> void:
    add_to_group("map_event_player")
    MapEvents.place_player.call_deferred(self)

func _physics_process(delta: float) -> void:
    if MapEvents.busy:
        velocity = Vector2.ZERO
        return
    # 기존 이동 코드를 여기에 유지합니다.
```

데모에는 연결이 완료되어 있습니다. 자신의 프로젝트에는 이동 코드와 맵 충돌 처리가 필요합니다. 빈 프로젝트 설치는 검증했지만 모든 기존 프로젝트와의 호환성은 검증하지 않았습니다. 기존 입력, 대화, 저장 시스템과의 연결을 확인하세요.

### 첫 대화 만들기

1. Godot 상단의 **地图事件** 탭에서 **新建事件**(새 이벤트)을 누릅니다.
2. 왼쪽에서 **出现条件 → 无条件**(등장 조건 → 항상), **触发方式 → 确认键交互**(실행 방식 → 확인 키)를 선택합니다. **示例外观 → 角色**(임시 외형 → NPC)를 선택한 뒤 **应用事件页**(페이지 적용)를 누릅니다.
3. 가운데의 기본 **显示文字**(텍스트 표시) 명령을 선택합니다. 오른쪽 **说话人**(화자)과 **消息内容**(내용)을 수정하고 **应用指令**(명령 적용)을 누릅니다.
4. **另存为…**(다른 이름으로 저장)를 눌러 `res://events/village_npc.tres`로 저장합니다. 필요하면 `events` 폴더를 만드세요.
5. 2D 화면에서 이벤트 노드를 선택하고 저장한 리소스를 **Data** 속성으로 드래그합니다. 씬을 저장합니다.
6. 게임을 실행하고 이벤트 가까이에서 E를 누릅니다.

**적용한 다음 저장하세요.** 입력만 하면 리소스에 반영되지 않습니다. 이벤트 이름은 **应用名称**으로 적용합니다. 다른 리소스를 열거나 종료하기 전에 저장하고, 변경 사항은 게임을 다시 실행해 확인하세요.

### 편집과 페이지 우선순위

| 작업 | 중국어 버튼 |
|---|---|
| 리소스 열기 | 打开事件… 또는 `.tres` 더블 클릭 |
| 명령 추가 | 유형을 선택하고 + 插入. 선택한 명령 다음에 삽입 |
| 명령 복제 또는 삭제 | 复制指令 / 删除 |
| 명령 순서 변경 | 上移 / 下移 |
| 페이지 추가 또는 복제 또는 삭제 | 왼쪽의 + 页 / 复制 / 删除 |
| 페이지 우선순위 변경 | 왼쪽의 ↑ / ↓ |
| 실행 취소 또는 다시 실행 | 撤销 / 重做 |
| 검사하고 저장 | 检查事件 → 保存 |

조건을 만족하는 페이지 중 **가장 아래에 있는 페이지가 우선**입니다. 페이지당 조건 하나를 선택합니다. **无条件**(항상), **全局开关**(전역 스위치), **独立开关**(셀프 스위치), **变量阈值**(변수가 지정값 이상)입니다. 설정하지 않은 스위치는 OFF, 변수는 0입니다.

**确认键交互**는 E 또는 `ui_accept`로 실행하며 **Interaction Radius**의 기본값은 64픽셀입니다. **靠近触发**는 플레이어가 30픽셀 미만 범위에 들어오면 실행하며 충돌 기반 트리거는 아닙니다. **自动执行**는 해당 페이지가 활성화될 때 한 번 실행하며, 페이지가 바뀌거나 씬을 다시 불러오면 재실행될 수 있습니다. 이벤트는 한 번에 하나만 실행됩니다.

### 한 번만 열리는 상자 만들기

아래 순서대로 두 페이지를 만들고 각 명령과 페이지를 적용한 뒤 저장합니다.

| 항목 | 페이지 1 | 페이지 2 |
|---|---|---|
| 조건 | 无条件 | 独立开关, 이름 `A`, ON |
| 실행 방식 | 确认键交互 | 确认键交互 |
| 외형 | 关闭的宝箱 | 打开的宝箱 |
| 명령 순서 | 增加变量: `coins`에 10 추가 → 设置独立开关: `A` ON → 显示文字: “동전 10개를 얻었다!” | 显示文字: “상자가 비어 있다.” |

페이지 2를 아래에 놓고 두 번 상호작용해 동전이 한 번만 늘어나는지 확인하세요. 다른 상자에서 같은 리소스를 사용하려면 노드의 **Event Id**를 다르게 설정합니다. 재시작 후에도 진행을 유지하려면 게임을 저장하세요.

### 선택지와 조건 분기

**显示选项**(선택지 표시)에서 질문, 한 줄에 하나씩 2~6개의 선택지, 결과 변수 `answer`를 입력합니다. 첫 선택지는 **0**, 두 번째는 **1**을 기록합니다. 다음 명령들을 각각 추가하세요.

```text
条件：变量     answer == 0
  显示文字    첫 번째 선택지를 골랐습니다.
否则
  显示文字    다른 선택지를 골랐습니다.
结束分支
```

들여쓰기는 자동 표시됩니다. 조건마다 **结束分支**(분기 종료)가 필요합니다. **结束事件**는 이벤트 전체를 종료하는 별도 명령입니다. **检查事件**로 누락된 분기 종료를 확인하세요.

### 다른 맵으로 이동하기

목적지 씬을 `res://maps/ruins.tscn` 같은 경로에 저장합니다. 루트 바로 아래에 `Arrival`이라는 `Marker2D`를 추가하고 입구에 배치하세요. 위 연결 코드를 사용하는 플레이어도 있어야 합니다. **切换地图**(맵 이동)에 씬 경로와 출현 지점 `Arrival`을 입력하고 적용한 뒤 저장합니다. 중첩된 마커라면 `Spawns/Arrival`처럼 루트 기준 상대 경로를 사용하세요. 맵 이동은 현재 명령 목록을 끝내므로 뒤에 놓인 명령은 실행되지 않습니다.

### 명령 목록

| 중국어 명령 | 설정과 동작 |
|---|---|
| 显示文字 | 화자와 내용. 확인을 기다림 |
| 显示选项 | 질문, 선택지 2~6개, 결과 변수. 결과는 0부터 시작 |
| 设置全局开关 | 모든 맵에서 공유하는 스위치 이름과 ON/OFF |
| 设置独立开关 | 이 이벤트만 사용하는 스위치 이름과 ON/OFF |
| 设置变量 | 변수 이름과 정수 값 |
| 增加变量 | 변수 이름과 증가량. 음수이면 감소 |
| 条件：全局开关 | 전역 스위치 이름과 비교할 ON/OFF |
| 条件：独立开关 | 셀프 스위치 이름과 비교할 ON/OFF |
| 条件：变量 | 변수, 비교 연산, 정수 값 |
| 否则 | 조건이 거짓일 때 실행할 분기 |
| 结束分支 | 현재 조건 분기를 닫음 |
| 等待 | 0~60초 대기 |
| 切换地图 | 존재하는 `res://` 씬과 출현 지점 상대 경로 |
| 播放音效 | 존재하는 `res://` 오디오 경로와 dB 음량. 재생 종료를 기다리지 않음 |
| 自定义指令 | 명령 이름과 문자열 인수. 별도 처리 코드 필요 |
| 结束事件 | 현재 이벤트 종료 |

### 저장과 문제 해결

데모에는 저장과 불러오기 버튼이 있습니다. 자신의 UI에서는 `MapEvents.save_game()`과 `MapEvents.load_game()`을 호출하고 반환된 `Error`가 `OK`인지 확인하세요. 이벤트 실행 중에는 둘 다 거부됩니다. 기본 경로는 `user://map_event_kit/save_01.json`이며 이전 저장은 `.bak`에 보관됩니다. 이벤트 스위치, 변수, 현재 씬과 플레이어 위치만 저장합니다. 인벤토리 등은 자신의 저장 시스템에 연결해야 합니다.

| 문제 | 확인할 내용 |
|---|---|
| 탭이나 이벤트 노드가 없음 | 플러그인을 활성화하고 가져오기를 기다립니다. 필요하면 프로젝트를 다시 엽니다 |
| E를 눌러도 반응 없음 | Data, 고유 Event Id, 플레이어 그룹, 페이지 조건, 거리, 키 입력을 소비하는 Control을 확인합니다 |
| 수정 내용이 사라짐 | 应用指令 / 应用事件页를 누른 다음 保存을 누릅니다 |
| 상자 보상을 반복 지급함 | 셀프 스위치 페이지를 마지막에 두고 페이지 1에서 A를 ON으로 설정합니다. 저장 후 씬 경로나 Event Id를 바꾸지 마세요 |
| 대화 중에도 이동함 | 모든 이동 경로에 `MapEvents.busy` 검사를 추가합니다 |
| 출현 위치가 잘못됨 | 마커 경로와 지연 호출한 `place_player`를 확인합니다 |
| 저장 또는 불러오기 실패 | 이벤트를 종료하고 반환값, 씬 저장 여부, 플레이어 등록을 확인합니다 |

이 Alpha에는 전투, 인벤토리 데이터베이스, 이동 경로, 병렬 이벤트, 멀티플레이, RPG Maker 프로젝트 가져오기, 저장 데이터 마이그레이션이 포함되어 있지 않습니다. 확장 방법은 [영문 기술 문서](TECHNICAL.md)를 참고하세요. 소스와 데모 에셋에는 [MIT 라이선스](../LICENSE)가 적용됩니다.

## 中文

### 开始使用

Map Event Kit 为 Godot 提供 RPG Maker 风格的事件页和指令列表，可用来制作 NPC 对话、宝箱、开关和地图传送。本手册直接介绍安装与操作。

已验证环境是 **Windows、Godot 4.7.2 标准版、Compatibility 渲染器**。其他 Godot 4 版本和系统尚未验证，不支持 Godot 3。**插件界面和演示目前是中文。** 本手册提供四种语言，插件暂时没有界面语言切换功能。

在 [GitHub](https://github.com/NoHaxJsut-Luck/godot-map-event-kit) 点击 **Code → Download ZIP**，解压后用 Godot 导入 `project.godot`，按 **F5** 运行。Windows 用户也可使用 `Launch Demo.cmd` 和 `Open Editor.cmd`；如果脚本找不到 Godot，改用引擎的项目管理器打开。压缩包不包含引擎。

用 **WASD / 方向键**移动，靠近事件后按 **E / 回车 / 空格**交互。对话按钮可以点击，也可用键盘选择并确认。建议先调查锁门，打开宝箱两次，再进入遗迹，确认金币只增加10枚。在遗迹保存，重启后读取，检查进度恢复。演示中的重置按钮只清空当前进度，不删除磁盘存档。

### 安装到自己的项目

1. 先在项目副本中接入。只复制 `addons/map_event_kit` 到自己的 `addons` 文件夹，继续使用自己的 `project.godot`。
2. 打开 **项目 → 项目设置 → 插件**，启用 **Map Event Kit / 地图事件工坊**，等待导入完成。插件会注册 `MapEvents` 自动加载。
3. 如果项目已有同名自动加载，先解决命名冲突。插件不会覆盖已有项。
4. 在地图场景添加 **MEKMapEvent** 节点。将 **Event Id** 设为同地图唯一的值，例如 `village_npc_01`；在 **Display Name** 填写显示名称，保存场景。
5. 将 `Node2D` 玩家加入 **map_event_player** 分组。若玩家使用 `CharacterBody2D`，把下面代码合入已有脚本，不要重复定义 `_ready()` 或 `_physics_process()`。

```gdscript
func _ready() -> void:
    add_to_group("map_event_player")
    MapEvents.place_player.call_deferred(self)

func _physics_process(delta: float) -> void:
    if MapEvents.busy:
        velocity = Vector2.ZERO
        return
    # 在这里保留你原来的移动逻辑。
```

演示项目已经完成接入。自己的项目仍需提供角色移动和地图碰撞。已验证空白项目安装，尚未验证任意已有项目的兼容性；接入时需检查现有输入、对话和存档系统。

### 制作第一段对话

1. 点击 Godot 顶部的 **地图事件**，再点 **新建事件**。
2. 左栏保持 **出现条件 → 无条件**、**触发方式 → 确认键交互**。设置 **示例外观 → 角色**，点 **应用事件页**。
3. 选择中间默认的 **显示文字** 指令，在右栏填写 **说话人** 和 **消息内容**，点 **应用指令**。
4. 点击 **另存为…**，保存为 `res://events/village_npc.tres`；如无 `events` 文件夹，先创建。
5. 返回 2D 场景，选中事件节点，把保存的资源拖到 **Data** 属性中。保存场景。
6. 运行游戏，靠近后按 E。

**先应用，再保存。** 只在表单里输入不会写入资源。修改事件名称后点 **应用名称**。切换资源或关闭编辑器前保存；测试修改时停止游戏并重新运行。

### 编辑指令和事件页

| 需要做什么 | 操作 |
|---|---|
| 打开已有资源 | 打开事件…，或双击 `.tres` 文件 |
| 添加指令 | 选择类型，点击 + 插入；插在当前选中指令后面 |
| 复制或删除指令 | 复制指令 / 删除 |
| 调整指令顺序 | 上移 / 下移 |
| 添加、复制或删除事件页 | 左栏的 + 页 / 复制 / 删除 |
| 调整事件页优先级 | 左栏的 ↑ / ↓ |
| 撤销或重做已应用的修改 | 撤销 / 重做 |
| 检查并保存 | 检查事件 → 保存 |

**最下方满足条件的事件页优先。** 每页选择一个条件：无条件、全局开关、独立开关、变量阈值。变量阈值表示“大于等于指定值”。未设置的开关默认为关闭，变量默认为0。

**确认键交互**使用 E 或 `ui_accept`，距离由 **Interaction Radius** 决定，默认64像素。**靠近触发**是在进入30像素范围时触发，不是碰撞触发。**自动执行**在进入当前页时执行一次，切换页面或重新加载场景后可以再次执行。同一时间只执行一个事件。

### 制作只能领取一次的宝箱

按下面顺序建立两页，每次修改指令或页面后点击应用，最后保存。

| 设置 | 第1页 | 第2页 |
|---|---|---|
| 条件 | 无条件 | 独立开关，名称 `A`，开启 |
| 触发 | 确认键交互 | 确认键交互 |
| 外观 | 关闭的宝箱 | 打开的宝箱 |
| 指令顺序 | 增加变量：`coins`，10 → 设置独立开关：`A`，开启 → 显示文字：“获得10枚金币！” | 显示文字：“宝箱已经空了。” |

第2页必须放在第1页下方。运行后交互两次，金币应只增加一次。其他宝箱可以使用同一资源，但节点必须设置不同的 **Event Id**。想在重启后保留状态，需要保存游戏进度。

### 制作选项和条件分支

插入 **显示选项**，填写提问，输入2～6个选项，每行一个，结果变量填写 `answer`。第一个选项写入 **0**，第二个写入 **1**。之后逐条添加：

```text
条件：变量     answer == 0
  显示文字    你选择了第一项。
否则
  显示文字    你选择了其他项。
结束分支
```

缩进由编辑器自动显示。每个条件必须配一个 **结束分支**。**结束事件** 会终止整个事件，不能代替结束分支。点击 **检查事件** 可发现分支未闭合的问题。

### 传送到另一张地图

保存目标场景，例如 `res://maps/ruins.tscn`。在场景根节点下添加名为 `Arrival` 的 `Marker2D`，放在入口位置，并配置接入完成的玩家。添加 **切换地图** 指令，填写目标场景路径和出生点 `Arrival`，应用并保存。若出生点位于子节点内，填写 `Spawns/Arrival` 这样的相对路径。传送会结束当前指令列表，后面的指令不会继续执行。

### 指令速查

| 指令 | 填写内容或效果 |
|---|---|
| 显示文字 | 说话人和正文，等待玩家确认 |
| 显示选项 | 提问、2～6行选项、结果变量；结果从0开始 |
| 设置全局开关 | 开关名、开启或关闭；跨地图共享 |
| 设置独立开关 | 开关名、开启或关闭；只属于该事件身份 |
| 设置变量 | 变量名和整数值 |
| 增加变量 | 变量名和整数增量，负数表示减少 |
| 条件：全局开关 | 开关名和需要匹配的开关值 |
| 条件：独立开关 | 独立开关名和需要匹配的开关值 |
| 条件：变量 | 变量名、比较方式和整数值 |
| 否则 | 条件不满足时执行的分支 |
| 结束分支 | 关闭当前条件分支 |
| 等待 | 0～60秒 |
| 切换地图 | 已存在的 `res://` 场景路径、出生点相对路径 |
| 播放音效 | 已存在的 `res://` 音频路径、dB 音量；不等待播放结束 |
| 自定义指令 | 名称和文本参数，需要配套代码接收 |
| 结束事件 | 立即结束本次事件 |

### 保存进度和常见问题

演示提供保存、读取按钮。自己的 UI 可调用 `MapEvents.save_game()` 和 `MapEvents.load_game()`，检查返回的 `Error` 是否为 `OK`。事件执行中不允许存读档。默认存档路径是 `user://map_event_kit/save_01.json`，上次存档保留为 `.bak`。只保存事件开关、变量、场景和玩家位置；背包等额外数据需要接入自己的存档逻辑。

| 问题 | 处理方法 |
|---|---|
| 找不到插件页签或事件节点 | 启用插件并等待导入，必要时重新打开项目 |
| 按 E 没反应 | 检查 Data、唯一 Event Id、玩家分组、当前页条件和距离；检查是否有 Control 消费了输入 |
| 修改后没保存下来 | 先点击应用指令或应用事件页，再保存 |
| 宝箱反复发奖励 | 独立开关页放到最后，第1页开启 A；存档后不要随意改场景路径或 Event Id |
| 对话时角色还能走 | 在所有移动逻辑入口检查 `MapEvents.busy` |
| 传送出生点不对 | 检查 Marker 路径，以及延迟调用的 `place_player` |
| 存读档失败 | 先结束事件，检查返回值，确认场景已保存、玩家已注册 |

这个 Alpha 暂不包含战斗、背包数据库、移动路线、并行事件、多人游戏、RPG Maker 工程导入和存档迁移。扩展方法见[英文技术文档](TECHNICAL.md)。代码和随附演示素材采用 [MIT 许可证](../LICENSE)。
