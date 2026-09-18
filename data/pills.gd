class_name Pills
extends RefCounted
## 丹药模板表。每味丹药 = 静态配置，不持有数量。
## 数量记在 PlayerData.pills（id -> 数量），与 items.gd / techniques.gd 同构。
##
## 字段说明：
##   - 通用：id / name / desc / cost（购买价格，灵石）
##   - 战斗丹药（战斗内吞服，占用一回合）：
##       heal_hp —— 恢复气血
##       heal_qi —— 恢复丹田灵气
##       shield  —— 获得护盾
##   - 突破丹药（突破时自动服用，见 GameState.try_breakthrough）：
##       breakthrough_bonus —— 突破成功率加成(%)（凝神丹）
##       protect_realm      —— 突破失败时是否护住道基不跌落境界（洗髓丹）
##   字段为 0 / false 表示“无此效果”，UI 据此拼接说明文案。

## 所有丹药（按 id 建索引）。
const PILLS: Dictionary = {
	"活血丹": {
		"id": "活血丹", "name": "活血丹", "cost": 20,
		"desc": "以灵草简单炼成，危急时吞服能活血疗伤。",
		"heal_hp": 30, "heal_qi": 0, "shield": 0,
		"breakthrough_bonus": 0, "protect_realm": false,
	},
	"回气丹": {
		"id": "回气丹", "name": "回气丹", "cost": 16,
		"desc": "通络聚灵之丹，战斗中可补足丹田灵气。",
		"heal_hp": 0, "heal_qi": 45, "shield": 0,
		"breakthrough_bonus": 0, "protect_realm": false,
	},
	"聚元丹": {
		"id": "聚元丹", "name": "聚元丹", "cost": 45,
		"desc": "疗伤回气兼顾，均衡而不凡。",
		"heal_hp": 18, "heal_qi": 20, "shield": 0,
		"breakthrough_bonus": 0, "protect_realm": false,
	},
	"凝神丹": {
		"id": "凝神丹", "name": "凝神丹", "cost": 60,
		"desc": "固守心神，突破瓶颈时大幅提升成功机率(+20%)。",
		"heal_hp": 0, "heal_qi": 0, "shield": 0,
		"breakthrough_bonus": 20, "protect_realm": false,
	},
	"洗髓丹": {
		"id": "洗髓丹", "name": "洗髓丹", "cost": 80,
		"desc": "伐毛洗髓，突破失败时护住道基，不再跌落境界。",
		"heal_hp": 0, "heal_qi": 0, "shield": 0,
		"breakthrough_bonus": 0, "protect_realm": true,
	},
}


## 取一味丹药模板；未知 id 返回空字典。
static func def(id: String) -> Dictionary:
	return PILLS.get(id, {})


## 拼接“效果说明”文本（供商店/提示用）。
static func effect_text(d: Dictionary) -> String:
	var parts: Array[String] = []
	var h := int(d.get("heal_hp", 0))
	var q := int(d.get("heal_qi", 0))
	var s := int(d.get("shield", 0))
	if h > 0:
		parts.append("战斗回血 %d" % h)
	if q > 0:
		parts.append("战斗回气 %d" % q)
	if s > 0:
		parts.append("护盾 %d" % s)
	if int(d.get("breakthrough_bonus", 0)) > 0:
		parts.append("突破成功率 +%d%%" % int(d["breakthrough_bonus"]))
	if bool(d.get("protect_realm", false)):
		parts.append("突破失败不跌境")
	return "、".join(parts)


## 抽出所有可供商店/突破 UI 使用的丹药，按数组顺序返回。
static func shop_list() -> Array:
	return PILLS.values()
