extends Node
## 全局游戏状态：持有唯一的 PlayerData，并负责
## “时间流逝 / 修炼 / 境界突破 / 坐化判定”这些核心规则。
##
## 通过 signal `data_changed` 通知 UI 刷新——UI 只读数据、只触发操作，
## 所有对玩家状态的改动都必须经过这里，保证逻辑单一来源。

## 出生可自由分配的五行灵根总点数。
const TOTAL_ELEMENT_POINTS := 12
## 单属性灵根点数的分配上限。
const MAX_ELEMENT := 5

## 境界表：数组下标即境界(0 起)。每项 = { name, need, lifespan, cost, min_element }
##   - need        ：在本境界累计多少修为才能突破
##   - lifespan    ：突破成功【后】的寿元上限
##   - cost        ：突破消耗的灵石
##   - min_element ：突破要求主灵根至少达到的点数（越高境越吃资质）
const REALMS: Array[Dictionary] = [
	{ "name": "练气", "need": 100,  "lifespan": 120,  "cost": 20,  "min_element": 1 },
	{ "name": "筑基", "need": 300,  "lifespan": 250,  "cost": 60,  "min_element": 2 },
	{ "name": "金丹", "need": 800,  "lifespan": 500,  "cost": 200, "min_element": 3 },
	{ "name": "元婴", "need": 2000, "lifespan": 1000, "cost": 600, "min_element": 4 },
	{ "name": "化神", "need": 5000, "lifespan": 2500, "cost": 1800,"min_element": 5 },
]

## 数据变化信号：任何影响 UI 的状态改动后都要 emit，让界面自动刷新。
signal data_changed

## 当前玩家的数据（唯一数据源）
var player: PlayerData


func _ready() -> void:
	# 启动时尝试读档；无档则自动新开。
	player = SaveSystem.load_player()
	SaveSystem.save_player(player)  # 确保 save/load 路径立即可用并留底
	notify_change()


## 当前境界的定义（便捷封装，UI 不必碰数组下标）。
func current_realm() -> Dictionary:
	return REALMS[player.realm]


## 是否已达最高境界（无法再突破）。
func is_max_realm() -> bool:
	return player.realm >= REALMS.size() - 1


## 是否已坐化（游戏结束条件：年龄达到寿元上限）。
func is_dead() -> bool:
	return player.age >= player.lifespan


## 通知所有监听方刷新 UI。
func notify_change() -> void:
	data_changed.emit()


## 剩余可分配的自由灵根点数。
func free_points() -> int:
	return TOTAL_ELEMENT_POINTS - player.sum_element()


## 给指定五行+1 点。返回是否成功（自由点够且未超单属性上限 5）。
func allocate_element(elt: String) -> bool:
	if free_points() <= 0:
		return false
	if int(player.elements[elt]) >= MAX_ELEMENT:
		return false
	player.elements[elt] = int(player.elements[elt]) + 1
	notify_change()
	return true


## 把指定五行 –1 点，退还为自由点。返回是否成功（该属性有点可退）。
func return_element(elt: String) -> bool:
	if int(player.elements[elt]) <= 0:
		return false
	player.elements[elt] = int(player.elements[elt]) - 1
	notify_change()
	return true


## 每年修炼获得的修为：主灵根 × 8，若是纯单灵根再 +8（资质更纯更快），
## 再加主修功法的额外加成。
## 主灵根为 0 时返回 0（还没分配灵根，无法修炼）。
func cultivation_per_year() -> int:
	var me := player.main_element()
	if me[1] <= 0:
		return 0
	var eff := int(me[1]) * 8
	if player.is_pure_root():
		eff += 8
	eff += int(active_gongfa().get("cult_per_year", 0))
	return eff


## 打坐修炼一年。时间 +1，修为按主灵根效率增长。
## 已坐化返回 false；未分配灵根也返回 false。
func cultivate_one_year() -> bool:
	if is_dead():
		return false
	var per_year := cultivation_per_year()
	if per_year <= 0:
		return false
	player.age += 1
	player.cultivation += per_year
	notify_change()
	return true


## 主灵根是否满足突破当前境界的资质门槛。
func has_enough_element() -> bool:
	var me: int = player.main_element()[1]
	return me >= int(current_realm().min_element)


## 基础突破成功率（%），不含丹药加成。
## 与主灵根成正比，纯灵根再高一层。这是“风险”的来源：不再是达标即成功。
func breakthrough_rate() -> int:
	var me := player.main_element()[1]
	var rate := 40 + me * 8
	if player.is_pure_root():
		rate += 10
	return clampi(rate, 0, 95)


## 尝试突破当前境界。
## 需要：非最高境界 + 未坐化 + 修为满 + 灵石足 + 主灵根达标（缺一即 locked 直接返回）。
##
## 突破改成“看脸”——不再是达标即成功：
##   - 成功率为 breakthrough_rate()；若持有凝神丹会自动服用，再 +20%。
##   - 失败 = 走火入魔：损失三成修为；另有 5% 概率跌落境界（道基不稳）。
##     若持有洗髓丹会自动服用，护住道基不跌落。
##
## 返回结果字典：
##   ok / locked / success_rate / used_bonus / used_protect /
##   dropped（是否跌境）/ lose_cult（走的修为）/ success（内部冗余，含在 ok）
func try_breakthrough() -> Dictionary:
	if is_max_realm() or is_dead():
		return { "ok": false, "locked": true }
	var cfg: Dictionary = current_realm()
	if player.cultivation < cfg.need \
			or player.spirit_stones < cfg.cost \
			or player.main_element()[1] < int(cfg.min_element):
		return { "ok": false, "locked": true }

	# 基础成功率 + 自动服用凝神丹加成
	var rate := breakthrough_rate()
	var used_bonus := false
	if count_pill("凝神丹") > 0:
		consume_pill("凝神丹")
		rate += int(Pills.def("凝神丹").get("breakthrough_bonus", 0))
		used_bonus = true

	# 判定成败
	if randi() % 100 < rate:
		player.realm += 1
		player.cultivation = 0
		player.spirit_stones -= int(cfg.cost)
		player.lifespan = REALMS[player.realm].lifespan
		notify_change()
		return { "ok": true, "locked": false, "success_rate": rate, "used_bonus": used_bonus }

	# 失败：走火入魔，损失三成修为
	var lose_cult := int(player.cultivation * 0.3)
	player.cultivation = maxi(player.cultivation - lose_cult, 0)

	# 5% 概率道基不稳、跌落境界；洗髓丹可护道基
	var dropped := false
	var used_protect := false
	if randi() % 20 == 0 and player.realm > 0:
		if count_pill("洗髓丹") > 0:
			consume_pill("洗髓丹")
			used_protect = true
		else:
			player.realm -= 1
			player.lifespan = REALMS[player.realm].lifespan
			player.cultivation = maxi(player.cultivation, int(REALMS[player.realm].need))
			dropped = true

	notify_change()
	return {
		"ok": false, "locked": false,
		"success_rate": rate, "used_bonus": used_bonus,
		"used_protect": used_protect, "dropped": dropped, "lose_cult": lose_cult,
	}


## 战斗结算：把一场战斗的胜负结果写入长期成长数据。
##   胜利：获得修为 + 灵石；
##   失败：重伤退场——修为折半、损失四成灵石、虚耗五年寿元，
##        若因此达到寿元上限则代价直接是坐化（可用 is_dead() 判断）。
## 返回描述明细的字典，供战斗场景展示结算文本。
func apply_battle_result(win: bool) -> Dictionary:
	var p := player
	var out := {}
	if win:
		var cult_gain := 20 + p.realm * 15
		var stone_gain := 20 + p.realm * 10
		p.cultivation += cult_gain
		p.spirit_stones += stone_gain
		out = { "win": true, "cultivation": cult_gain, "stones": stone_gain }
	else:
		var lost_stones := int(p.spirit_stones * 0.4)
		p.cultivation = int(p.cultivation * 0.5)
		p.spirit_stones = maxi(p.spirit_stones - lost_stones, 0)
		p.age += 5
		out = { "win": false, "lost_stones": lost_stones, "died": is_dead() }
	notify_change()
	return out


# ============================================================================
#  法宝 / 背包
# ============================================================================
## 背包里是否已持有指定法宝。
func has_fabao(id: String) -> bool:
	return int(player.inventory.get(id, 0)) > 0


## 当前装备的法宝模板；未装备返回 Items.EMPTY_FABAO。
## 归一化入口：战斗/UI 都从这里取，保证 id 必定对得上模板。
func equipped_fabao() -> Dictionary:
	return Items.def(player.fabao)


## 批量法宝加成（供战斗等场景一次性读取，避免多次取模板）。
func fabao_bonus() -> Dictionary:
	var d := equipped_fabao()
	return { "atk": int(d.get("atk_bonus", 0)), "hp": int(d.get("hp_bonus", 0)) }


## 购买法宝：需灵石足够且尚未拥有。成功扣灵石并入背包，返回是否成功。
func buy_fabao(id: String) -> bool:
	var d: Dictionary = Items.FABAO.get(id)
	if d.is_empty():
		return false
	if has_fabao(id):
		return false
	var cost := int(d.get("cost", 0))
	if player.spirit_stones < cost:
		return false
	player.spirit_stones -= cost
	player.inventory[id] = 1
	notify_change()
	return true


## 无条件把一件法宝放入背包（用于战斗掉落等免费途径）。已拥有则失败。
func grant_fabao(id: String) -> bool:
	if Items.FABAO.has(id) and not has_fabao(id):
		player.inventory[id] = 1
		notify_change()
		return true
	return false


## 装备一件已拥有的法宝。返回是否成功。
func equip_fabao(id: String) -> bool:
	if not has_fabao(id):
		return false
	player.fabao = id
	notify_change()
	return true


## 卸下当前法宝。无论是否装备都返回 true（幂等）。
func unequip_fabao() -> void:
	player.fabao = ""
	notify_change()


# ============================================================================
#  功法 / 神通
# ============================================================================
## 是否已习得指定功法。
func has_technique(id: String) -> bool:
	return int(player.techniques.get(id, 0)) > 0


## 当前主修功法模板；未主修返回空字典。
func active_gongfa() -> Dictionary:
	return Techniques.def(player.active_gongfa)


## 习得功法：需灵石足够 + 境界达标 + 尚未习得。成功扣灵石并入库，返回是否成功。
func learn_technique(id: String) -> bool:
	var d: Dictionary = Techniques.def(id)
	if d.is_empty() or has_technique(id):
		return false
	if int(d.get("realm_min", 0)) > player.realm:
		return false
	if player.spirit_stones < int(d.get("cost", 0)):
		return false
	player.spirit_stones -= int(d.get("cost", 0))
	player.techniques[id] = 1
	notify_change()
	return true


## 把一门已习得的功法设为主修。返回是否成功。
func set_gongfa(id: String) -> bool:
	if not has_technique(id):
		return false
	if player.active_gongfa == id:
		return false
	player.active_gongfa = id
	notify_change()
	return true


## 无条件获得一门功法（剧情奇遇等免费途径，不扣灵石）。
func grant_technique(id: String) -> bool:
	if Techniques.def(id).is_empty() or has_technique(id):
		return false
	player.techniques[id] = 1
	notify_change()
	return true


# ============================================================================
#  剧情奇遇 / 事件结算
# ============================================================================
## 把一个“事件选择的结果”写入长期数据。effect 字典支持的键：
##   stones(±) / age(+)/ lifespan(±) / cultivation(+)
##   pill(发丹药) + pill_count / gongfa(赠功法) / fabao(赠法宝)
## 返回本次变更的人类可读摘要（供地块 UI 展示），无变化返回空串。
## 注意：这里不处理 battle 效果——遇到战斗需由调用方切换战斗场景。
func apply_event_outcome(effect: Dictionary) -> String:
	var p := player
	var parts: Array[String] = []
	if effect.has("stones"):
		p.spirit_stones = maxi(p.spirit_stones + int(effect["stones"]), 0)
		parts.append("灵石%+d" % int(effect["stones"]))
	if effect.has("age"):
		var y := maxi(int(effect["age"]), 0)
		p.age += y
		if y > 0:
			parts.append("虚耗%+d年寿元" % (-y))
	if effect.has("lifespan"):
		var l := int(effect["lifespan"])
		p.lifespan = maxi(p.lifespan + l, 1)
		parts.append("寿元上限%+d" % l)
	if effect.has("cultivation"):
		p.cultivation = maxi(p.cultivation + int(effect["cultivation"]), 0)
		parts.append("修为%+d" % int(effect["cultivation"]))
	if effect.has("pill"):
		var pid := str(effect["pill"])
		var cnt := int(effect.get("pill_count", 1))
		grant_pill(pid, cnt)
		parts.append("丹药×%d·%s" % [cnt, Pills.def(pid).get("name", pid)])
	if effect.has("gongfa"):
		var gid := str(effect["gongfa"])
		if grant_technique(gid):
			parts.append("习得功法·%s" % Techniques.def(gid).get("name", gid))
	if effect.has("fabao"):
		var fid := str(effect["fabao"])
		if grant_fabao(fid):
			parts.append("获法宝·%s" % Items.def(fid).get("name", fid))
	notify_change()
	return "、".join(parts)


# ============================================================================
#  丹药 / 消耗品
# ============================================================================
## 当前拥有的某味丹药数量。
func count_pill(id: String) -> int:
	return int(player.pills.get(id, 0))


## 是否持有至少一枚某味丹药。
func has_pill(id: String) -> bool:
	return count_pill(id) > 0


## 购买丹药：需灵石足够且存在该模板。成功扣灵石并加一枚，返回是否成功。
func buy_pill(id: String) -> bool:
	if Pills.def(id).is_empty():
		return false
	var cost := int(Pills.def(id).get("cost", 0))
	if player.spirit_stones < cost:
		return false
	player.spirit_stones -= cost
	player.pills[id] = count_pill(id) + 1
	notify_change()
	return true


## 无条件发放丹药（奇遇/掉落等免费途径）。
func grant_pill(id: String, amount: int = 1) -> void:
	if Pills.def(id).is_empty() or amount <= 0:
		return
	player.pills[id] = count_pill(id) + amount
	notify_change()


## 消耗一枚丹药（战斗吞服 / 突破自动服用等）。数量不足返回 false。
func consume_pill(id: String) -> bool:
	var n := count_pill(id)
	if n <= 0:
		return false
	if n == 1:
		player.pills.erase(id)
	else:
		player.pills[id] = n - 1
	notify_change()
	return true


# ============================================================================
#  坐化传承（转世重修）
# ============================================================================
## 开始一世“传世”：从当前（已坐化）的角色继承部分遗产，新开一世。
## 继承规则：三成灵石、随机一门已习得功法、持有的丹药每味最多带 2 枚、
##           随机一件已拥有法宝。灵根 / 境界 / 寿元等重置为新档（需重新分配灵根）。
## 返回本次继承的人类可读摘要。
func start_new_life() -> String:
	var old := player
	var np := PlayerData.new()

	var parts: Array[String] = []

	# 三成灵石
	var stones := int(old.spirit_stones * 0.3)
	np.spirit_stones = stones
	if stones > 0:
		parts.append("继承灵石 %d" % stones)

	# 随机一门已习得的功法（沿用为“已习得”，不自动主修）
	var gids: Array = old.techniques.keys()
	if not gids.is_empty():
		var gid := str(gids[randi() % gids.size()])
		np.techniques[gid] = 1
		parts.append("沿用功法·%s" % Techniques.def(gid).get("name", gid))

	# 丹药：每味最多带 2 枚
	for pid in old.pills:
		if Pills.def(str(pid)).is_empty():
			continue
		var keep := mini(int(old.pills[pid]), 2)
		if keep > 0:
			np.pills[pid] = keep
			parts.append("%s×%d" % [Pills.def(str(pid)).get("name", str(pid)), keep])

	# 随机一件已拥有法宝（留作传家宝）
	var fids: Array = old.inventory.keys()
	if not fids.is_empty():
		var fid := str(fids[randi() % fids.size()])
		np.inventory[fid] = 1
		parts.append("传法宝·%s" % Items.def(fid).get("name", fid))

	# 落档并通知 UI
	player = np
	SaveSystem.save_player(player)
	notify_change()
	return "、".join(parts) if not parts.is_empty() else "这一次，你两手空空地重入轮回……"
