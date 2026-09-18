class_name Techniques
extends RefCounted
## 功法模板表。每门功法 = 静态配置，不持有“是否已习得/是否主修”这类进度数据。
##
## 设计要点（与 items.gd 一致）：
##   - 玩家学过哪些功法、主修哪门，都记在 PlayerData（techniques / active_gongfa）。
##   - 这里只有只读配置；以后联网“功法库”可由服务器下发，本地只是默认库。
##
## 字段说明：
##   - id / name / desc      ：标识与文案
##   - cost                  ：习得所需灵石
##   - realm_min             ：习得所需最低境界下标（对应 GameState.REALMS）
##   - cult_per_year         ：装备主修后，每年额外增加的修为
##   - spell_cost_qi         ：专属神通消耗的丹田灵气
##   - spell_base            ：专属神通的基础伤害（再叠加境界与法宝攻击）
##   - spell_name            ：专属神通名称

## 所有功法（按 id 建索引）。
const ALL: Dictionary = {
	"炼气吐纳诀": {
		"id": "炼气吐纳诀", "name": "炼气吐纳诀", "realm_min": 0, "cost": 40,
		"desc": "散修通用的入门功法，吐纳效率中庸，附一招「凝气掌」。",
		"cult_per_year": 4, "spell_cost_qi": 20, "spell_base": 10, "spell_name": "凝气掌",
	},
	"离火真经": {
		"id": "离火真经", "name": "离火真经", "realm_min": 0, "cost": 90,
		"desc": "重在御火，修炼略快，神通「离火焚天」火威凌厉。",
		"cult_per_year": 8, "spell_cost_qi": 30, "spell_base": 16, "spell_name": "离火焚天",
	},
	"青木长生功": {
		"id": "青木长生功", "name": "青木长生功", "realm_min": 1, "cost": 160,
		"desc": "纳木气以养寿元，修炼平缓但吐纳生生不息，神通「青木回春」。",
		"cult_per_year": 6, "spell_cost_qi": 24, "spell_base": 14, "spell_name": "青木回春",
	},
}


## 取一门功法模板；未知 id 返回空字典（不提供“空功法”，未主修时视为无加成）。
static func def(id: String) -> Dictionary:
	return ALL.get(id, {})


## 按数组顺序列出全部功法（供商店 UI 遍历）。
static func list_all() -> Array:
	return ALL.values()
