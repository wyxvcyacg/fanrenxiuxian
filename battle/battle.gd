extends Node
## 战斗场景：一场简化的「回合制 · 灵气 + 术法」战斗（觅长生式）。
##
## 规则：
##   - 双方都有「丹田灵气(qi)」，施放术法要消耗灵气。
##   - 每人每回合自动回气 15，也可以用一次行动「吐纳」回更多。
##   - 玩家回合选一项行动，随后进入敌人回合，如此往复，直到一方倒下。
##   - 五行相克：攻方属性克制受方属性时伤害 ×1.5（金→木→土→水→火→金）。
##   - 护盾先于血量承伤，且不会自动回复，只能靠「聚盾」补充。
##   - 战斗结束会把胜负写回 GameState（apply_battle_result），并自动存档。
##
## 数据/表现解耦：本场景只通过 GameState 读长期数据、结算胜败；
## 临时的战斗状态（血量/灵气/护盾）只存在本地 Fighter 里，打完即弃。

## 五行相克表：attacker_key → victim_value（被克，伤害 ×1.5）
const KE: Dictionary = { "金": "木", "木": "土", "土": "水", "水": "火", "火": "金" }
## 每回合自动回气量
const REGEN := 15
## 「吐纳」一次的回气量
const BREATHE := 40

## 战斗双方
var _player: Fighter
var _enemy: Fighter
## 回合归属："player" / "enemy" / "over"
var _state: String = "player"
## 玩家本命灵根名（战斗内不再改变）
var _root: String = ""

## 控件引用
var _lbl_ptitle: Label
var _lbl_phpshield: Label
var _lbl_pqi: Label
var _lbl_etitle: Label
var _lbl_ehpshield: Label
var _lbl_equi: Label
var _lbl_log: Label
var _action_row: HBoxContainer
var _end_panel: VBoxContainer
var _lbl_result: Label


func _ready() -> void:
	_init_fighters()
	_build_ui()
	_start_player_turn()


# ============================================================================
#  战斗初始化
# ============================================================================
func _init_fighters() -> void:
	var p: PlayerData = GameState.player
	_root = str(p.main_element()[0]) if int(p.main_element()[1]) > 0 else ""

	# 玩家：HP/灵气上限随境界成长
	_player = Fighter.new("你", 60 + p.realm * 30, 60 + p.realm * 20, _root)

	# 敌修：强度随玩家境界成长，本命五行随机一个
	var e := PlayerData.ELEMENTS[randi() % PlayerData.ELEMENTS.size()]
	_enemy = Fighter.new("游方散修", 60 + p.realm * 40, 50 + p.realm * 15, e)


# ============================================================================
#  UI 构建（代码动态创建，保持与主界面一致的深色仙侠风）
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

	# 标题 + 说明
	var title := Label.new()
	title.text = "☯ 历练战"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("e8c766")
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "每回合回气 %d，吐纳可多回。灵气即法力，五行术法是灵根的延伸。" % REGEN
	hint.add_theme_font_size_override("font_size", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color("aab3c6")
	vbox.add_child(hint)

	# 敌我状态区
	_etitle = _mk_caption(vbox, "敌：")
	_ehpshield = _mk_stat(vbox, "气血/护盾：")
	_equi = _mk_stat(vbox, "灵气：")
	_mk_gap(vbox)
	_ptitle = _mk_caption(vbox, "我：")
	_phpshield = _mk_stat(vbox, "气血/护盾：")
	_pqi = _mk_stat(vbox, "灵气：")

	_mk_gap(vbox)
	_mk_caption2(vbox, "行动")

	# 操作区（玩家回合的行动按钮）
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)
	_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_action_row)
	_build_player_actions()

	# 战斗日志（可滚动）
	_mk_caption2(vbox, "战况")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_lbl_log = Label.new()
	_lbl_log.add_theme_font_size_override("font_size", 16)
	_lbl_log.modulate = Color("c9d1e8")
	_lbl_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_lbl_log)

	# 结算面板（结束后显示）
	_end_panel = VBoxContainer.new()
	_end_panel.add_theme_constant_override("separation", 12)
	vbox.add_child(_end_panel)
	_lbl_result = Label.new()
	_lbl_result.add_theme_font_size_override("font_size", 20)
	_lbl_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_panel.add_child(_lbl_result)
	_end_panel.hide()


# 构建玩家的行动按钮：吐纳 / 基础灵击 / 聚盾 / 五行术法
func _build_player_actions() -> void:
	_mk_action("灵击(-10)", _act_basic)
	_mk_action("吐纳(+%d)" % BREATHE, _act_breathe)
	_mk_action("聚盾(-20)", _act_shield)
	# 五行术法：每个分到了灵根点数的属性对应一门术法，属性越强威力越高
	for e in PlayerData.ELEMENTS:
		if int(GameState.player.elements[e]) <= 0:
			continue
		_mk_action("%s·术(-30)" % e, _act_spell.bind(e))


func _mk_action(text: String, target: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(target)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_row.add_child(b)


func _mk_caption(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.modulate = Color("e8c766")
	parent.add_child(l)
	return l


func _mk_caption2(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color("aab3c6")
	parent.add_child(l)


func _mk_stat(parent: Node, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var c := Label.new()
	c.text = caption
	c.add_theme_font_size_override("font_size", 20)
	c.modulate = Color("aab3c6")
	row.add_child(c)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 20)
	v.modulate = Color("e8c766")
	row.add_child(v)
	return v


func _mk_gap(parent: Node) -> void:
	parent.add_child(HSeparator.new())


# ============================================================================
#  回合流程
# ============================================================================
## 进入玩家回合：回气 + 刷新 + 放开行动按钮
func _start_player_turn() -> void:
	if _over():
		return
	_state = "player"
	_player.gain_qi(REGEN)
	_refresh()
	_enable_actions(true)


## 进入敌人回合：回气 + 简单 AI 行动
func _start_enemy_turn() -> void:
	_state = "enemy"
	_enable_actions(false)
	_enemy.gain_qi(REGEN)
	_enemy_act()
	_refresh()
	if _over():
		return
	_start_player_turn()


## 敌人 AI：护盾被打光就补盾，灵气足则放大招，否则普攻。
func _enemy_act() -> void:
	var spell_cost := 25
	var shield_cost := 15
	var e := _enemy
	if e.qi >= spell_cost and (e.shield <= 0 or randi() % 2 == 0):
		e.try_pay_qi(spell_cost)
		var dmg := 9 + GameState.player.realm * 3
		_log("【%s】催动%s诀，灵光汹涌而来！" % [e.display_name, e.element])
		var r := _apply_damage(e, _player, dmg, e.element)
		_log("你被击中，本体检伤 %d%s。" % [r["dmg"], "（相克！）" if r["crit"] else ""])
	elif e.qi >= shield_cost and e.shield < 8:
		e.try_pay_qi(shield_cost)
		e.gain_shield(10 + GameState.player.realm * 2)
		_log("【%s】掐诀聚盾，护体灵光增厚。" % e.display_name)
	else:
		_log("【%s】挥剑直劈而来。" % e.display_name)
		var r := _apply_damage(e, _player, 4 + GameState.player.realm * 2)
		_log("你被击中，本体检伤 %d。" % r["dmg"])


## 伤害结算：attacker 的属性「atk_el」克制 target.element 时伤害 ×1.5。
## atk_el 与 attacker.element 分开传，方便术法用施放时的那门属性判克。
func _apply_damage(attacker: Fighter, target: Fighter, raw: int, atk_el: String = "") -> Dictionary:
	var dmg := raw
	var crit := false
	if atk_el != "" and KE.get(atk_el, "") == target.element:
		dmg = int(float(dmg) * 1.5)
		crit = true
	return { "dmg": dmg, "res": target.take_damage(dmg), "crit": crit }


## 战斗是否已结束（一方倒下）。结束时触发一次结算，保证只结算一次。
func _over() -> bool:
	if _state == "over":
		return true
	if _player.is_down() or _enemy.is_down():
		_finish_battle()
		return true
	return false


## 结算：写回长期数据、落档、显示结果与「返回」按钮。
func _finish_battle() -> void:
	if _state == "over":
		return
	_state = "over"
	_enable_actions(false)

	var win: bool = _enemy.is_down() and not _player.is_down()
	var r: Dictionary = GameState.apply_battle_result(win)
	SaveSystem.save_player(GameState.player)

	if win:
		_log("\n★ 你击败了敌修！")
		_lbl_result.text = "★ 大捷！\n修为 +%d，灵石 +%d" % [int(r["cultivation"]), int(r["stones"])]
	elif r["died"]:
		_lbl_result.text = "你重伤不支，寿元走到尽头……坐化道消。"
	else:
		_lbl_result.text = "你重伤落败，仓皇遁走。\n修为折半，损失灵石 %d，虚耗五年寿元。" % int(r["lost_stones"])

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(0, 52)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://main/main.tscn"))
	_end_panel.add_child(back)
	_end_panel.show()


# ============================================================================
#  玩家行动
# ============================================================================
func _act_basic() -> void:
	if _state != "player":
		return
	if not _pay(10):
		return
	var raw := 5 + GameState.player.realm * 2
	_log("你凝神一记「灵击」！")
	var r := _apply_damage(_player, _enemy, raw)
	_log("命中：本体检伤 %d。" % r["dmg"])
	_after_player_attack()


func _act_breathe() -> void:
	if _state != "player":
		return
	_player.gain_qi(BREATHE)
	_log("你盘膝吐纳，丹田灵气充盈 (+%d)。" % BREATHE)
	_start_enemy_turn()


func _act_shield() -> void:
	if _state != "player":
		return
	if not _pay(20):
		return
	var amount := 12 + GameState.player.realm * 3
	_player.gain_shield(amount)
	_log("你掐诀聚盾，护体灵光 +%d。" % amount)
	_start_enemy_turn()


## 一门五行术法：威力随该属性灵根点数成长，并以该属性判定相克。
func _act_spell(e: String) -> void:
	if _state != "player":
		return
	if not _pay(30):
		return
	var pt := int(GameState.player.elements[e])
	var raw := 12 + pt * 4 + GameState.player.realm * 2
	_log("你催动「%s」系术法，灵光破空！" % e)
	var r := _apply_damage(_player, _enemy, raw, e)
	_log("命中：本体检伤 %d%s。" % [r["dmg"], "（相克！）" if r["crit"] else ""])
	_after_player_attack()


## 玩家攻击之后：判定敌方倒下，否则进入敌人回合。
func _after_player_attack() -> void:
	_refresh()
	if _over():
		return
	_start_enemy_turn()


## 尝试支付灵气；不足则提示并返回 false。
func _pay(cost: int) -> bool:
	if _player.try_pay_qi(cost):
		return true
	_log("灵气不足，行动失败！")
	_refresh()
	return false


# ============================================================================
#  刷新与启停
# ============================================================================
func _enable_actions(on: bool) -> void:
	for b in _action_row.get_children():
		if b is Button:
			b.disabled = not on


func _refresh() -> void:
	_etitle.text = "敌：%s  ·  本命 %s" % [_enemy.display_name, _enemy.element]
	_ehpshield.text = "%d / %d  (护盾 %d)" % [_enemy.hp, _enemy.max_hp, _enemy.shield]
	_equi.text = "%d / %d" % [_enemy.qi, _enemy.max_qi]

	var root_tip := "（未定）" if _root == "" else _root + " 系"
	_ptitle.text = "我：%s  ·  本命 %s" % [_player.display_name, root_tip]
	_phpshield.text = "%d / %d  (护盾 %d)" % [_player.hp, _player.max_hp, _player.shield]
	_pqi.text = "%d / %d" % [_player.qi, _player.max_qi]


## 追加一行战斗日志，只保留最近若干行。
func _log(text: String) -> void:
	_lbl_log.text += text + "\n"
	var lines := _lbl_log.text.split("\n")
	if lines.size() > 40:
		_lbl_log.text = "\n".join(lines.slice(lines.size() - 40))