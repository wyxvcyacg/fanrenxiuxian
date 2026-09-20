extends Node
## 地图历练场景：提供几处历练地点，用于丰富核心循环。
##
## 地点：
##   - 切磋散修 ：直接进入战斗（保留原有战斗入口）
##   - 灵脉洞府 ：闭关静修，连续修炼三年
##   - 秘境探宝 ：随机事件（得灵石 / 得丹药 / 遇敌战斗 / 空手而归）
##   - 云游奇遇 ：随机抽一个“剧情奇遇”，给出多选分支（叙事数据驱动）
##
## 数据/表现解耦：本场景只通过 GameState 读写长期数据并结算事件，
## 临时的“当前正在看哪个事件”只存在于本地变量，不入档。

## 当前正在展示的奇遇 id
var _event_id: String = ""
## 当前事件的 choices 数组（缓存避免反复取表）
var _event_choices: Array = []

## 控件引用
var _lbl_stat: Label        # 顶部简要状态
var _content: VBoxContainer # 可变区域：历练地点列表 或 奇遇分支
var _lbl_msg: Label         # 结果/提示文本


func _ready() -> void:
	_build_ui()
	_show_locations()


# ============================================================================
#  UI 构建
# ============================================================================
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color("171229")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "☯ 外出历练"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("e8c766")
	vbox.add_child(title)

	_lbl_stat = Label.new()
	_lbl_stat.add_theme_font_size_override("font_size", 16)
	_lbl_stat.modulate = Color("aab3c6")
	vbox.add_child(_lbl_stat)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)

	_lbl_msg = Label.new()
	_lbl_msg.add_theme_font_size_override("font_size", 17)
	_lbl_msg.modulate = Color("c9d1e8")
	_lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_msg)

	var back := Button.new()
	back.text = "返回洞府"
	back.custom_minimum_size = Vector2(0, 52)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://main/main.tscn"))
	vbox.add_child(back)


# ============================================================================
#  展示“历练地点”列表
# ============================================================================
func _show_locations() -> void:
	_event_id = ""
	_clear_content()
	_lbl_msg.text = ""
	_refresh_stat()

	var loc := HBoxContainer.new()
	_content.add_child(loc)
	var label := Label.new()
	label.text = "历练之地"
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("e8c766")
	loc.add_child(label)

	_location_row("切磋 · 战散修", _on_spar)
	_location_row("灵脉洞府 · 闭关三年", _on_close)
	_location_row("秘境 · 探宝", _on_treasure)
	_location_row("云游 · 奇遇", _on_adventure)


func _location_row(text: String, target: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(target)
	_content.add_child(b)


# ============================================================================
#  地点行为
# ============================================================================
## 切磋：直接进入战斗场景。
func _on_spar() -> void:
	if GameState.is_dead():
		_lbl_msg.text = "你已寿元耗尽，坐化道消，无法再外出。"
		return
	get_tree().change_scene_to_file("res://battle/battle.tscn")


## 闭关：连续修炼三年（复用修炼规则，寿元相应流逝）。
func _on_close() -> void:
	if GameState.is_dead():
		_lbl_msg.text = "你已寿元耗尽，无法闭关。"
		return
	var gained := 0
	for i in 3:
		if not GameState.cultivate_one_year():
			break
		gained += 1
	_lbl_msg.text = "你在灵脉洞府闭关 %d 年，吐纳周天，修为大有长进。" % gained
	_refresh_stat()


## 探宝：随机决定此行收获。
func _on_treasure() -> void:
	if GameState.is_dead():
		_lbl_msg.text = "你已寿元耗尽，无法再涉险探宝。"
		return
	var roll := randi() % 100
	if roll < 35:
		var stones := 15 + GameState.player.realm * 10
		GameState.apply_event_outcome({ "stones": stones })
		_lbl_msg.text = "你寻得一处前人遗府，收获灵石 %d 枚！" % stones
	elif roll < 65:
		var pid: String = str((["活血丹", "回气丹", "聚元丹"])[randi() % 3])
		GameState.apply_event_outcome({ "pill": pid, "pill_count": 1 })
		_lbl_msg.text = "你采到珍稀灵草，炼成「%s」一枚收入囊中。" % Pills.def(pid).get("name", pid)
	else:
		_lbl_msg.text = "你碰上一头守护灵草的妖兽，不留神惊动了它。"
		get_tree().change_scene_to_file("res://battle/battle.tscn")
	_refresh_stat()


## 云游：随机抽一个剧情奇遇，换成多选分支视图。
func _on_adventure() -> void:
	if GameState.is_dead():
		_lbl_msg.text = "你已寿元耗尽，坐化道消，无法再云游。"
		return
	_event_id = Events.random_id()
	var ev := Events.def(_event_id)
	_event_choices = ev["choices"]
	_show_event(ev)


# ============================================================================
#  奇遇的多选分支
# ============================================================================
func _show_event(ev: Dictionary) -> void:
	_clear_content()
	_lbl_msg.text = ""

	var title := Label.new()
	title.text = "奇遇 · " + str(ev.get("title", ev.get("id", "")))
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color("e8c766")
	_content.add_child(title)

	var text := Label.new()
	text.text = str(ev["text"])
	text.add_theme_font_size_override("font_size", 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.modulate = Color("c9d1e8")
	_content.add_child(text)

	_content.add_child(HSeparator.new())
	for i in _event_choices.size():
		var c: Dictionary = _event_choices[i]
		var b := Button.new()
		b.text = "[%d] %s" % [i + 1, str(c["text"])]
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_on_choice.bind(i))
		_content.add_child(b)


## 选择一个分支：结算效果；若是战斗则切换到战斗场景，否则展示结局并返回地点列表。
func _on_choice(idx: int) -> void:
	var c: Dictionary = _event_choices[idx]
	var effect: Dictionary = c.get("effect", {})
	var flavor: String = str(c.get("flavor", ""))

	if effect.has("battle"):
		_lbl_msg.text = flavor
		get_tree().change_scene_to_file("res://battle/battle.tscn")
		return

	var summary: String = GameState.apply_event_outcome(effect)
	var out := flavor
	if summary != "":
		out += "\n（" + summary + "）"
	_lbl_msg.text = out

	# 结算后回地点列表（寿元耗尽则不会再让你出门）
	_show_locations()
	if GameState.is_dead():
		_lbl_msg.text = out + "\n你因寿元耗尽，坐化道消……"


# ============================================================================
#  工具
# ============================================================================
## 清空可变内容区（重新铺当前视图的控件）。
func _clear_content() -> void:
	for child in _content.get_children():
		child.free()


func _refresh_stat() -> void:
	var p: PlayerData = GameState.player
	_lbl_stat.text = "境界 %s | 寿元 %d/%d | 灵石 %d" % [
		GameState.current_realm()["name"], p.age, p.lifespan, p.spirit_stones]
