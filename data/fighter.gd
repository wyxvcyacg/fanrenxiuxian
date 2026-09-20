class_name Fighter
extends RefCounted
## 战斗单元（玩家或敌人）的数据模型。只存“一场战斗内”的瞬时状态。
##
## 与 PlayerData 的分工：
##   - PlayerData 是跨战斗的长期成长（境界/灵石/灵根…），会被存档。
##   - Fighter 只描述开打这一场时双方的即时战力（血量/护盾/丹田灵气），打完即弃、不入档。
## 这样即使以后要联网，战斗只是“客户端内的一次模拟”，随时可以重开。

## 名号
var display_name: String = ""
## 生命：归零则战败
var hp: int = 0
var max_hp: int = 0
## 护盾：受击时先抵消护盾，护盾不会自动恢复，只能通过“聚盾”补充
var shield: int = 0
## 丹田灵气：施放术法要消耗的“法力值”，靠吐纳/每回合回气恢复
var qi: int = 0
var max_qi: int = 0
## 本命五行：用于五行相克判定（攻方克受方时伤害提升）
var element: String = ""


## 构造一个战斗单元。进场时丹田只有一半灵气，需要回气/吐纳。
func _init(n: String = "", h: int = 1, q: int = 10, e: String = "") -> void:
	display_name = n
	max_hp = h
	hp = h
	max_qi = q
	qi = q / 2
	element = e


## 回复灵气（吐纳/每回合回气），不会溢出上限。
func gain_qi(amount: int) -> void:
	qi = mini(qi + amount, max_qi)


## 是否已战败（血量耗尽）。
func is_down() -> bool:
	return hp <= 0


## 施放术法消耗灵气；灵气不足时返回 false（无法施放）。
func try_pay_qi(cost: int) -> bool:
	if qi < cost:
		return false
	qi -= cost
	return true


## 受到一次伤害：先扣护盾，剩余才扣本体血量。
## 返回一个字典，方便 UI 展示这次受击的明细。
func take_damage(raw: int) -> Dictionary:
	var dmg := raw
	var res := { "shield": 0, "hp": 0 }
	if shield > 0:
		var absorbed := mini(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		res["shield"] = absorbed
	if dmg > 0:
		hp = maxi(hp - dmg, 0)
		res["hp"] = dmg
	return res


## 施加护盾（聚盾）。
func gain_shield(amount: int) -> void:
	shield += amount
