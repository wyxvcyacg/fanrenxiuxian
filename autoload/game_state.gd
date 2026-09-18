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


## 每年修炼获得的修为：主灵根 × 8，若是纯单灵根再 +8（资质更纯更快）。
## 主灵根为 0 时返回 0（还没分配灵根，无法修炼）。
func cultivation_per_year() -> int:
	var me := player.main_element()
	if me[1] <= 0:
		return 0
	var eff := int(me[1]) * 8
	if player.is_pure_root():
		eff += 8
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


## 尝试突破当前境界。需要：非最高境界 + 未坐化 + 修为满 + 灵石足 + 主灵根达标。
## 成功返回 true，否则 false。
func try_breakthrough() -> bool:
	if is_max_realm():
		return false
	if is_dead():
		return false
	var cfg: Dictionary = current_realm()
	if player.cultivation < cfg.need:
		return false
	if player.spirit_stones < cfg.cost:
		return false
	if player.main_element()[1] < int(cfg.min_element):
		return false

	# 突破成功：进境、清空修为、扣灵石、大幅延长寿元。
	player.realm += 1
	player.cultivation = 0
	player.spirit_stones -= cfg.cost
	player.lifespan = REALMS[player.realm].lifespan
	notify_change()
	return true


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