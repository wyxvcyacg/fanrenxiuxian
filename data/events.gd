class_name Events
extends RefCounted
## 剧情奇遇 / 事件表。每个事件 = 静态叙事配置 + 一组可供玩家上演的“多选分支”。
##
## 结构与 GameState 逻辑一致（数据/表现解耦）：
##   - 事件只是“文本 + 选项 + 效果”的纯数据，不持有任何玩家进度。
##   - 玩家选了哪个选项、得到什么，由 GameState.apply_event_outcome(effect) 落地，
##     本表只管“有哪几个奇遇、每个奇遇有哪几个分支”。
##
## choices[].effect 支持的键见 GameState.apply_event_outcome：
##   stones / age / lifespan / cultivation / pill(+pill_count) / gongfa / fabao
##   battle:true 表示“触发一场战斗”，由调用方切换战斗场景，不走 apply_event_outcome。

## 所有奇遇（按 id 建索引）。
const ALL: Dictionary = {
	"迷途道童": {
		"id": "迷途道童",
		"text": "山道旁，一名迷路的道童怯生生地望着你，求你好心送他一程。",
		"choices": [
			{ "text": "顺路送他一程（虚耗一年寿元）",
			  "flavor": "你牵着小道童走了一程，他感激涕零，从怀里掏出一把灵石相谢。",
			  "effect": { "age": 1, "stones": 35 } },
			{ "text": "赠他几枚灵石，让他自行归去",
			  "flavor": "你用灵石化去他的不安，道童连声称谢，临别时嘴里嘟囔着几句吐纳口诀，你似有所悟。",
			  "effect": { "stones": -10, "cultivation": 18 } },
			{ "text": "心有戒备，云淡风轻地走过",
			  "flavor": "你冷然走过，不多管闲事。道童在身后嘀咕了几句，你只当没听见。",
			  "effect": { "stones": 5 } },
		],
	},
	"神秘古洞": {
		"id": "神秘古洞",
		"text": "一处无名古洞，洞口半掩，隐约透出灵光与低沉的兽吼。",
		"choices": [
			{ "text": "谨慎退走，不涉险地",
			  "flavor": "你在洞外捡到几枚散落的灵石，头也不回地退走了。",
			  "effect": { "stones": 18 } },
			{ "text": "小心翼翼地摸黑探洞寻宝",
			  "flavor": "你屏息摸入洞中，寻得一处前人遗蜕，得到几味丹药和些许灵石。",
			  "effect": { "pill": "活血丹", "pill_count": 2, "stones": 30 } },
			{ "text": "祭出神通，强闯洞府",
			  "flavor": "一声兽吼，洞中盘踞的妖兽应声而出，要与你一战。",
			  "effect": { "battle": true } },
		],
	},
	"无主洞府": {
		"id": "无主洞府",
		"text": "一座久无人居的洞府，丹炉尚温，案上散落着几枚丹药与一卷残经。",
		"choices": [
			{ "text": "收下丹药与灵石，悄然离去",
			  "flavor": "你拾起丹药与灵石，不惊动此地，转身离开。",
			  "effect": { "pill": "聚元丹", "pill_count": 1, "stones": 40 } },
			{ "text": "端坐参悟那卷残经",
			  "flavor": "残经晦涩，你却从中悟出了半篇吐纳之法，门外汉竟也习得一门功法。",
			  "effect": { "gongfa": "炼气吐纳诀", "cultivation": 20 } },
			{ "text": "闭关三月，炼化洞府灵脉（虚耗两年寿元）",
			  "flavor": "你在此闭关炼化，借灵脉之力飞速凝练修为。",
			  "effect": { "age": 2, "cultivation": 30 } },
		],
	},
}


## 取一个事件模板；未知 id 返回空字典。
static func def(id: String) -> Dictionary:
	return ALL.get(id, {})


## 随机抽取一个奇遇 id。
static func random_id() -> String:
	var ids: Array = ALL.keys()
	return str(ids[randi() % ids.size()])
