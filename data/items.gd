class_name Items
extends RefCounted
## 法宝模板表。每件法宝 = 一张静态配置，不持有数量/是否已装备等“进度型”数据。
##
## 设计要点：
##   - 模板是只读的常量表，与存档 / 玩家背包彻底解耦。
##   - 玩家拥有哪些法宝、装备了哪一件，统统记在 PlayerData 里（inventory/fabao），
##     以后要联网，法宝配置由服务器下发即可，这里只是“本地默认库”。
##
## 字段说明：
##   - id         ：全局唯一标识（也作为存档里的键）
##   - name       ：展示名称
##   - desc       ：说明文案
##   - cost       ：购买价格（灵石）
##   - atk_bonus  ：装备后，五行术法额外增加的伤害
##   - hp_bonus   ：装备后，战斗中气血上限的增加量

## 空位：表示“没有装备法宝”。仅作占位，不出现在商店里。
const EMPTY_FABAO := { "id": "", "name": "无", "desc": "赤手空拳。", "cost": 0, "atk_bonus": 0, "hp_bonus": 0 }

## 所有可购买的法宝（按 id 建索引的字典，方便查找）。
const FABAO: Dictionary = {
	"青锋剑": {
		"id": "青锋剑", "name": "青锋剑", "cost": 60,
		"desc": "炼气期常用的飞剑，剑芒凌厉，术法威力略有提升。",
		"atk_bonus": 8, "hp_bonus": 0,
	},
	"护体玄衣": {
		"id": "护体玄衣", "name": "护体玄衣", "cost": 50,
		"desc": "以妖兽皮鞣制，内嵌聚灵纹，穿之气血充盈，更耐苦战。",
		"atk_bonus": 0, "hp_bonus": 20,
	},
	"紫府玉印": {
		"id": "紫府玉印", "name": "紫府玉印", "cost": 120,
		"desc": "一方温润玉印，攻守兼备，据传为某位金丹真人所留。",
		"atk_bonus": 5, "hp_bonus": 12,
	},
}


## 根据 id 取法宝模板；未找到或为空串时返回“无”空位定义。
static func def(id: String) -> Dictionary:
	if id == "":
		return EMPTY_FABAO
	return FABAO.get(id, EMPTY_FABAO)


## 按数组顺序列出所有可购买法宝（供商店 UI 遍历）。
static func shop_list() -> Array:
	return FABAO.values()
