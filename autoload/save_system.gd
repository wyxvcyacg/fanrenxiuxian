extends Node
## 存档系统。
##
## 这里刻意写得像一个“接口”：对外只暴露 save_player / load_player 两个方法。
## 当前实现是把玩家数据序列化为 JSON 存到本地（user:// 是 Godot 的沙盒用户目录）。
##
## 这正是“先单机后联网”预留的那道缝：
## 以后想联网时，只需在下方换成“把 PlayerData.to_dict() 上传到服务器 / 从服务器拉取”，
## 改这里即可，游戏本体与 UI 完全不用动。

const SAVE_PATH := "user://save.json"


## 保存玩家数据到本地。成功返回 true。
func save_player(p: PlayerData) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	# to_dict() 就是数据模型与存储层之间的契约，JSON 只是其中一种实现。
	file.store_string(JSON.stringify(p.to_dict(), "\t"))
	file.close()
	return true


## 读取玩家数据；没有存档则返回一份全新的 PlayerData。
func load_player() -> PlayerData:
	if not FileAccess.file_exists(SAVE_PATH):
		return PlayerData.new()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return PlayerData.new()
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		# 存档损坏时退回新档，避免游戏无法启动。
		push_warning("存档解析失败，已回退为新档。")
		return PlayerData.new()
	return PlayerData.from_dict(json.data)
