class_name PlayerData
extends RefCounted
## 玩家数据模型。纯数据 + 序列化能力，与表现层(UI)完全解耦。
##
## 设计要点：这是全项目唯一一份“玩家状态”的来源。
## UI 只负责读取和触发操作，绝不应该在这里之外再散落状态副本。
## 这也是“先单机后联网”的根基：以后要联机，只需让
## to_dict/from_dict 成为与服务器同步的契约即可，游戏逻辑不用重写。

## 五行属性键，顺序即展示/平局判定顺序。
const ELEMENTS: Array[String] = ["金", "木", "水", "火", "土"]

## 当前境界下标（对应 GameState.REALMS 表）
var realm: int = 0
## 当前年龄（单位：年），每打坐修炼一年 +1
var age: int = 1
## 当前寿元上限（境界突破后大幅提升）
var lifespan: int = 120
## 当前修为（向突破所需的累计值）
var cultivation: int = 0
## 灵石（突破、日后购买物都会消耗）
var spirit_stones: int = 50
## 五行灵根点数：每项 0~5，总和不超过 GameState.TOTAL_ELEMENT_POINTS。
## 主灵根(最高单项)决定修炼效率，并约束能否冲击高境界。
var elements: Dictionary = {}
## 背包：法宝 id -> 拥有数量。
var inventory: Dictionary = {}
## 当前已装备的法宝 id；空串表示未装备。
## 战斗读取加成时请走 GameState.equipped_fabao()，以保证返回的是合法模板。
var fabao: String = ""
## 已习得的功法 id 集合（id -> 1）。
var techniques: Dictionary = {}
## 当前主修功法 id；空串表示未主修任何功法。
## 主修功法影响修炼效率，并在战斗解锁专属神通。读取请走 GameState.active_gongfa()。
var active_gongfa: String = ""
## 丹药背包：丹药 id -> 数量。
var pills: Dictionary = {}


func _init() -> void:
	# 初始化五行全为 0
	for e in ELEMENTS:
		elements[e] = 0


## 五行点数之和（已分配的自由点）。
func sum_element() -> int:
	var s := 0
	for e in ELEMENTS:
		s += int(elements[e])
	return s


## 主灵根：取点数最高的属性。[0]=名，[1]=值；平局取 ELEMENTS 中靠前者。
func main_element() -> Array:
	var best_name := ELEMENTS[0]
	var best := 0
	for e in ELEMENTS:
		var v := int(elements[e])
		if v > best:
			best = v
			best_name = e
	return [best_name, best]


## 是否“单灵根”：只有一种属性达到最高值（越纯资质越好）。
func is_pure_root() -> bool:
	var me := main_element()[1]
	if me <= 0:
		return false
	var count := 0
	for e in ELEMENTS:
		if int(elements[e]) >= me:
			count += 1
	return count == 1


## 序列化：转成可保存的字典。这是存档/上送服务器的“契约格式”。
func to_dict() -> Dictionary:
	return {
		"realm": realm,
		"age": age,
		"lifespan": lifespan,
		"cultivation": cultivation,
		"spirit_stones": spirit_stones,
		"elements": elements,
		"inventory": inventory,
		"fabao": fabao,
		"techniques": techniques,
		"active_gongfa": active_gongfa,
		"pills": pills,
	}


## 反序列化：从字典恢复出新的 PlayerData（与 to_dict 一一对应）。
## 用 get 提供默认值，保证旧档缺失字段时也能安全读入。
static func from_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.realm = int(d.get("realm", 0))
	p.age = int(d.get("age", 1))
	p.lifespan = int(d.get("lifespan", 120))
	p.cultivation = int(d.get("cultivation", 0))
	p.spirit_stones = int(d.get("spirit_stones", 50))
	# 兼容旧存档：缺失 elements 时保持默认全 0
	var elems: Dictionary = d.get("elements", {})
	if elems is Dictionary:
		for e in ELEMENTS:
			p.elements[e] = int(elems.get(e, 0))
	# 法宝字段：旧档没有时保持“空背包/未装备”
	var inv: Dictionary = d.get("inventory", {})
	p.inventory = inv if inv is Dictionary else {}
	p.fabao = str(d.get("fabao", ""))
	# 功法字段：旧档没有时保持“未习得/未主修”
	var techn: Dictionary = d.get("techniques", {})
	p.techniques = techn if techn is Dictionary else {}
	p.active_gongfa = str(d.get("active_gongfa", ""))
	# 丹药字段：旧档没有时保持空背包
	var pl: Dictionary = d.get("pills", {})
	p.pills = pl if pl is Dictionary else {}
	return p
