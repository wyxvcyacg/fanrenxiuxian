extends Node
## 主场景：负责搭建修仙 UI 面板，并把这些控件绑定到 GameState 的数据与信号。
##
## 演示要点：
##   - 表现层(UI) 只通过 GameState 读写玩家数据，绝不越过它直接改状态。
##   - 订阅 data_changed 信号自动刷新，逻辑改动后 UI 无需手动同步。

# ---- 控件引用缓存 ----
var _lbl_realm: Label
var _lbl_age: Label
var _lbl_stones: Label
var _lbl_talent: Label
var _lbl_need: Label
var _lbl_status: Label
var _bar_cult: ProgressBar
var _btn_cult: Button
var _lbl_free: Label
var _element_vals: Dictionary = {}  # 五行名 -> 数值 Label
var _lbl_fabao_now: Label  # 当前装备法宝的展示
var _fabao_btns: Dictionary = {}  # 法宝 id -> 操作按钮（购买/装备）
var _lbl_gongfa_now: Label  # 当前主修功法展示
var _gongfa_btns: Dictionary = {}  # 功法 id -> 操作按钮（习得/主修）
var _btn_breakthrough: Button  # 突破按钮（文案里显示成功率）
var _pill_btns: Dictionary = {}  # 丹药 id -> 购买按钮
var _btn_life: Button  # 传世重修的按钮（仅坐化后显示）


func _ready() -> void:
	_build_ui()
	# 订阅数据变化，自动刷新面板
	GameState.data_changed.connect(_refresh)
	_refresh()


## 主灵根的资质描述：XX（N）+ 纯/杂灵根
func _element_desc() -> String:
	var me: Array = GameState.player.main_element()
	if int(me[1]) <= 0:
		return "未分配灵根"
	var s := "%s（%d）" % [me[0], int(me[1])]
	s += " · 纯灵根" if GameState.player.is_pure_root() else " · 多灵根"
	return s


# ============================================================================
#  UI 构建（用代码动态创建，演示 process 方式；同样也可以在编辑器里搭 .tscn）
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
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	root.add_child(margin)

	# 整页放进 ScrollContainer，避免内容多时在竖屏(720 高)上溢出
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "《修仙修炼录》"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 属性信息区
	_lbl_realm = _add_info(vbox, "境界")
	_lbl_age = _add_info(vbox, "年龄(年)")
	_lbl_stones = _add_info(vbox, "灵石")
	_lbl_talent = _add_info(vbox, "本命灵根")

	# 修为进度
	_bar_cult = ProgressBar.new()
	_bar_cult.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(_bar_cult)
	_lbl_need = _add_info(vbox, "修为")

	# 五行灵根分配区（用剩余自由点数决定能加多少）
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	vbox.add_child(sec)
	var head := HBoxContainer.new()
	sec.add_child(head)
	var sec_title := Label.new()
	sec_title.text = "五行灵根"
	sec_title.add_theme_font_size_override("font_size", 20)
	sec_title.modulate = Color("e8c766")
	head.add_child(sec_title)
	_lbl_free = Label.new()
	_lbl_free.add_theme_font_size_override("font_size", 18)
	_lbl_free.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_lbl_free)
	for e in PlayerData.ELEMENTS:
		_add_element_row(sec, e)

	# 状态提示（默认提示 / 突破结果 / 坐化等）
	_lbl_status = Label.new()
	_lbl_status.add_theme_font_size_override("font_size", 18)
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_status)

	# 操作按钮
	_btn_cult = _mk_button("打坐修炼一年", _on_cultivate)
	vbox.add_child(_btn_cult)
	_btn_breakthrough = _mk_button("尝试突破瓶颈", _on_breakthrough)
	vbox.add_child(_btn_breakthrough)
	vbox.add_child(_mk_button("外出历练", _on_map))

	# 传世重修按钮：平时隐藏，坐化后方可点击转世
	_btn_life = _mk_button("传世 · 转世重修", _on_new_life)
	_btn_life.hide()
	vbox.add_child(_btn_life)

	# 法宝板块
	_build_fabao_section(vbox)
	# 功法板块
	_build_gongfa_section(vbox)
	# 丹药板块
	_build_pills_section(vbox)

	# 存/读档
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 10)
	vbox.add_child(save_row)
	var btn_save := _mk_button("保存", _on_save)
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(btn_save)
	var btn_load := _mk_button("读档", _on_load)
	btn_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(btn_load)


## 生成一行“名称：值”，返回值的 Label 供缓存。
func _add_info(root: Node, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	var cap := Label.new()
	cap.text = caption + "："
	cap.add_theme_font_size_override("font_size", 22)
	cap.modulate = Color("aab3c6")
	row.add_child(cap)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 22)
	val.modulate = Color("e8c766")
	row.add_child(val)
	return val


## 生成一个按钮，并把点击事件接上。
func _mk_button(text: String, target: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(target)
	return b


## 构建「法宝」板块：当前装备 + 商店列表（购买/装备/已装备）。
func _build_fabao_section(parent: Node) -> void:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	parent.add_child(sec)

	var head := HBoxContainer.new()
	sec.add_child(head)
	var sec_title := Label.new()
	sec_title.text = "法宝"
	sec_title.add_theme_font_size_override("font_size", 20)
	sec_title.modulate = Color("e8c766")
	head.add_child(sec_title)
	_lbl_fabao_now = Label.new()
	_lbl_fabao_now.add_theme_font_size_override("font_size", 16)
	_lbl_fabao_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_fabao_now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_lbl_fabao_now)

	# 商店逐件法宝：一行「名称 属性·价格」+ 一个操作按钮
	for d in Items.shop_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sec.add_child(row)

		var info := Label.new()
		var atk := int(d.get("atk_bonus", 0))
		var hp := int(d.get("hp_bonus", 0))
		var line := "%s  (%d灵石)" % [d["name"], int(d["cost"])]
		if atk > 0:
			line += " 攻+%d" % atk
		if hp > 0:
			line += " 血+%d" % hp
		info.text = line
		info.add_theme_font_size_override("font_size", 17)
		info.modulate = Color("aab3c6")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var id: String = str(d["id"])
		var btn := _mk_button("购买", _on_fabao.bind(id))
		btn.custom_minimum_size = Vector2(88, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		_fabao_btns[id] = btn


## 构建「功法」板块：当前主修 + 功法库列表（习得/主修/已主修）。
func _build_gongfa_section(parent: Node) -> void:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	parent.add_child(sec)

	var head := HBoxContainer.new()
	sec.add_child(head)
	var sec_title := Label.new()
	sec_title.text = "功法"
	sec_title.add_theme_font_size_override("font_size", 20)
	sec_title.modulate = Color("e8c766")
	head.add_child(sec_title)
	_lbl_gongfa_now = Label.new()
	_lbl_gongfa_now.add_theme_font_size_override("font_size", 16)
	_lbl_gongfa_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_gongfa_now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_lbl_gongfa_now)

	# 功法库逐门：一行「名称 + 修炼加成 + 境界门槛 · 灵石」+ 一个操作按钮
	for d in Techniques.list_all():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sec.add_child(row)

		var req_name: String = GameState.REALMS[int(d["realm_min"])]["name"]
		var info := Label.new()
		info.text = "%s (修+%d · %s境) %d灵石" % [
			d["name"], int(d["cult_per_year"]), req_name, int(d["cost"])]
		info.add_theme_font_size_override("font_size", 17)
		info.modulate = Color("aab3c6")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var id: String = str(d["id"])
		var btn := _mk_button("习得", _on_gongfa.bind(id))
		btn.custom_minimum_size = Vector2(88, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		_gongfa_btns[id] = btn


## 构建「丹药」板块：一行「名称 + 效果 + 价格 · 持有数」+ 一个购买按钮。
func _build_pills_section(parent: Node) -> void:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	parent.add_child(sec)

	var head := HBoxContainer.new()
	sec.add_child(head)
	var sec_title := Label.new()
	sec_title.text = "丹药"
	sec_title.add_theme_font_size_override("font_size", 20)
	sec_title.modulate = Color("e8c766")
	head.add_child(sec_title)

	for d in Pills.shop_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sec.add_child(row)

		var info := Label.new()
		var eff := Pills.effect_text(d)
		info.text = "%s（%d灵石）" % [d["name"], int(d["cost"])]
		if eff != "":
			info.text += " ｜ " + eff
		info.add_theme_font_size_override("font_size", 17)
		info.modulate = Color("aab3c6")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)

		var id: String = str(d["id"])
		var btn := _mk_button("购买", _on_pill.bind(id))
		btn.custom_minimum_size = Vector2(88, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		_pill_btns[id] = btn


## 生成一个五行灵根行：[名称] [数值] [-] [+]
func _add_element_row(parent: Node, elt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_l := Label.new()
	name_l.text = elt
	name_l.custom_minimum_size = Vector2(48, 0)
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.modulate = Color("aab3c6")
	row.add_child(name_l)

	var val_l := Label.new()
	val_l.text = "0"
	val_l.set_meta("elt", elt)
	val_l.add_theme_font_size_override("font_size", 20)
	val_l.modulate = Color("e8c766")
	val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val_l)
	_element_vals[elt] = val_l

	var minus := Button.new()
	minus.text = "－"
	minus.custom_minimum_size = Vector2(44, 36)
	minus.pressed.connect(_on_element_minus.bind(elt))
	row.add_child(minus)

	var plus := Button.new()
	plus.text = "＋"
	plus.custom_minimum_size = Vector2(44, 36)
	plus.pressed.connect(_on_element_plus.bind(elt))
	row.add_child(plus)


# ============================================================================
#  交互接口
# ============================================================================
func _on_cultivate() -> void:
	if GameState.is_dead():
		_lbl_status.text = "你已寿元耗尽，无法再修炼……"
	elif not GameState.cultivate_one_year():
		_lbl_status.text = "请先为五行灵根分配点数，主灵根为 0 无法修炼。"
	else:
		_lbl_status.text = "你盘坐修炼一年，吐纳灵气，向本命灵根印证大道。"


func _on_element_plus(elt: String) -> void:
	if not GameState.allocate_element(elt):
		_lbl_status.text = "分配失败：检查剩余自由点数与单属性上限 5。"
	else:
		_lbl_status.text = "灵根 %s 提升。" % elt


func _on_element_minus(elt: String) -> void:
	if GameState.return_element(elt):
		_lbl_status.text = "灵根 %s 降低。" % elt
	else:
		_lbl_status.text = ""  # 该属性已是 0，无可退还

## 进入地图历练：已坐化则不可外出，否则切换到地图场景。
func _on_map() -> void:
	if GameState.is_dead():
		_lbl_status.text = "你已寿元耗尽，坐化道消，无法再外出历练。"
		return
	get_tree().change_scene_to_file("res://map/map.tscn")


## 传世重修：把当前角色（已坐化）的遗泽带回一世新身。
func _on_new_life() -> void:
	_lbl_status.text = "你盘坐入定，眼前斗转星移——\n就此转世重修，这一世的遗泽随你而来：\n" + GameState.start_new_life()
	# 转世后仍是此界面，数据变化会触发 _refresh 自动更新显示


## 法宝操作按钮：未拥有→购买，已拥有未装备→装备，已装备→卸下。
func _on_fabao(id: String) -> void:
	if not GameState.has_fabao(id):
		if GameState.buy_fabao(id):
			_lbl_status.text = "你购得法宝「%s」。" % Items.def(id)["name"]
		else:
			_lbl_status.text = "灵石不足，买不起这件法宝。"
	elif GameState.player.fabao == id:
		GameState.unequip_fabao()
		_lbl_status.text = "你收起了法宝。"  # 按钮状态由 _refresh 统一刷新
	else:
		GameState.equip_fabao(id)
		_lbl_status.text = "你祭出法宝「%s」傍身。" % Items.def(id)["name"]


## 功法操作按钮：未习得且境界达标→习得；已习得未主修→设为主修；已是主修→不可点。
func _on_gongfa(id: String) -> void:
	if not GameState.has_technique(id):
		if GameState.learn_technique(id):
			_lbl_status.text = "你参悟玄经，习得功法「%s」！" % Techniques.def(id)["name"]
		else:
			var d: Dictionary = Techniques.def(id)
			if GameState.player.realm < int(d.get("realm_min", 0)):
				var req_name: String = GameState.REALMS[int(d["realm_min"])]["name"]
				_lbl_status.text = "境界不足，需%s境方可参悟。" % req_name
			elif GameState.player.spirit_stones < int(d.get("cost", 0)):
				_lbl_status.text = "灵石不足，参悟需要 %d 枚灵石。" % int(d["cost"])
	else:
		GameState.set_gongfa(id)
		_lbl_status.text = "你改以「%s」为主修功法，吐纳为之一新。" % Techniques.def(id)["name"]


## 丹药购买按钮：购买一枚对应丹药。
func _on_pill(id: String) -> void:
	if GameState.buy_pill(id):
		_lbl_status.text = "你购入丹药「%s」。" % Pills.def(id)["name"]
	else:
		_lbl_status.text = "灵石不足，买不起这味丹药。"


func _on_breakthrough() -> void:
	if GameState.is_dead():
		_lbl_status.text = "你已寿元耗尽，无法突破。"
		return
	var r: Dictionary = GameState.try_breakthrough()
	if r.get("locked", false):
		var p: PlayerData = GameState.player
		var cfg: Dictionary = GameState.current_realm()
		if p.cultivation < int(cfg.need):
			_lbl_status.text = "修为不足，尚难冲破瓶颈。"
		elif GameState.player.main_element()[1] < int(cfg.min_element):
			_lbl_status.text = "本命灵根不足（需主灵根 ≥ %d），资质难承载此境界。" % int(cfg.min_element)
		else:
			_lbl_status.text = "灵石不足，突破所需 %d 枚灵石。" % int(cfg.cost)
	elif r.get("ok", false):
		var note := ""
		if r.get("used_bonus", false):
			note = "（凝神丹加持，机率 +20）"
		_lbl_status.text = "轰——突破成功！寿元大增！成功机率 %d%%%s。" % [int(r["success_rate"]), note]
	else:
		var msg := "你冲击瓶颈，引来心魔，走火入魔！损失修为 %d，成功机率 %d%%。" % [
			int(r.get("lose_cult", 0)), int(r.get("success_rate", 0))]
		if r.get("used_protect", false):
			msg += "洗髓丹护住道基，境界得以保全。"
		elif r.get("dropped", false):
			msg += "道基不稳，境界跌落至「%s」！" % GameState.REALMS[GameState.player.realm]["name"]
		_lbl_status.text = msg
	GameState.notify_change()


func _on_save() -> void:
	_lbl_status.text = "已保存。" if SaveSystem.save_player(GameState.player) else "保存失败！"


func _on_load() -> void:
	GameState.player = SaveSystem.load_player()
	GameState.notify_change()
	_lbl_status.text = "已读档。"


# ============================================================================
#  刷新面板：只读 GameState 数据，逐项更新控件文本
# ============================================================================
func _refresh() -> void:
	var p: PlayerData = GameState.player
	var cfg: Dictionary = GameState.current_realm()
	var next_name: String = "已臻化神" if GameState.is_max_realm() else GameState.REALMS[p.realm + 1].name

	_lbl_realm.text = "%s → 下一境：%s" % [cfg.name, next_name]
	_lbl_age.text = "%d / %d" % [p.age, p.lifespan]
	_lbl_stones.text = str(p.spirit_stones)
	_lbl_talent.text = _element_desc()

	# 五行灵根：逐行更新数值 + 剩余点数 + 修炼按钮上的效率
	for e in PlayerData.ELEMENTS:
		_element_vals[e].text = str(int(p.elements[e]))
	_lbl_free.text = "剩余 %d 点" % GameState.free_points()
	_btn_cult.text = "打坐修炼一年（修为 +%d）" % GameState.cultivation_per_year()
	_btn_breakthrough.text = "尝试突破瓶颈（成功率 %d%%）" % GameState.breakthrough_rate()

	if GameState.is_max_realm():
		_bar_cult.value = 1.0
		_lbl_need.text = "已臻大圆满"
	else:
		var need: int = cfg.need
		_bar_cult.max_value = float(need)
		_bar_cult.value = minf(float(p.cultivation), float(need))
		_lbl_need.text = "%d / %d" % [p.cultivation, need]

	# 法宝板块：当前装备展示 + 每个按钮状态机（购买/装备/已装备/卸下）
	var eq: Dictionary = GameState.equipped_fabao()
	var eq_name: String = str(eq["name"])
	var eq_desc := ""
	if eq_name != "无":
		eq_desc = "%s  攻+%d 血+%d" % [eq_name, int(eq.get("atk_bonus", 0)), int(eq.get("hp_bonus", 0))]
	_lbl_fabao_now.text = "已装备：" + (eq_desc if eq_desc != "" else eq_name)
	for id in _fabao_btns:
		var btn: Button = _fabao_btns[id]
		if not GameState.has_fabao(id):
			var cost: int = int(Items.def(id)["cost"])
			btn.text = "购买"
			btn.disabled = p.spirit_stones < cost
		elif p.fabao == id:
			btn.text = "已装备"
			btn.disabled = true
		else:
			btn.text = "装备"
			btn.disabled = false

	# 功法板块：当前主修 + 每个按钮状态机（习得/主修/已主修）
	var gf: Dictionary = GameState.active_gongfa()
	_lbl_gongfa_now.text = "主修："
	_lbl_gongfa_now.text += str(gf.get("name", "无")) if not gf.is_empty() else "无"
	for id in _gongfa_btns:
		var gbtn: Button = _gongfa_btns[id]
		if not GameState.has_technique(id):
			gbtn.text = "习得"
			gbtn.disabled = p.spirit_stones < int(Techniques.def(id)["cost"]) \
				or p.realm < int(Techniques.def(id).get("realm_min", 0))
		elif p.active_gongfa == id:
			gbtn.text = "已主修"
			gbtn.disabled = true
		else:
			gbtn.text = "主修"
			gbtn.disabled = false

	# 丹药板块：按钮统一为「购买」，灵石不足则禁用；行首提示已通过构建时展示。
	for id in _pill_btns:
		var nbtn: Button = _pill_btns[id]
		nbtn.text = "购买"
		nbtn.disabled = p.spirit_stones < int(Pills.def(id).get("cost", 0))

	# 状态提示只在这里兜底（坐化/可突破），按钮操作的反馈会被保留不覆盖。
	if GameState.is_dead():
		_btn_life.show()
		_lbl_status.text = "你已寿元耗尽，坐化道消。可点击「传世 · 转世重修」开启新一世。"
	else:
		_btn_life.hide()
		if GameState.player.main_element()[1] == 0:
			_lbl_status.text = "请先分配五行灵根点数，开启修炼之路。"
		elif not GameState.is_max_realm() and p.cultivation >= cfg.need:
			_lbl_status.text = "修为已满，是时候尝试突破了！（成功率 %d%%；可备凝神丹/洗髓丹）" % GameState.breakthrough_rate()
