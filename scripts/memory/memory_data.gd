class_name MemoryData
extends Resource

## 记忆碎片 / 线索数据。
##
## 关键设计（提示词【八】）：同一段文本在不同上下文下含义不同，因此
## [member text_early] 与 [member text_late] 共用同一段文字，只有
## [member double_meaning] 里记录“第二次理解”是什么。
## 绝不写两套文案，绝不把真相直接告诉玩家。

enum Category {
	RESIDENTS,   ## 居民
	Suzu,        ## 小铃
	MORRIS,      ## 莫里斯
	PIERROT,     ## 皮埃罗
	DRY_WELL,    ## 枯井
	CLOCK_TOWER, ## 钟楼
	FIRE,        ## 火灾
	FRAGMENT,    ## 记忆碎片
	LOOP,        ## 循环
	ENDING,      ## 结局
}

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## 笔记本上浮现的正文。必须自带双重解释。
@export_multiline var text: String = ""
## 说话者（可为空，表示是主角自己的记录）。
@export var speaker: String = ""
@export var category: Category = Category.FRAGMENT
## 解锁条件标识，由 GameManager 的 flag 系统判定；空表示一开始就拥有。
@export var unlock_condition: StringName = &""
## 是否是需要主动拾取的“记忆碎片”（影响笔记本表现与结局判定）。
@export var is_fragment: bool = false
## 第五章之后重读时的补充说明。仅供开发参考，不直接展示给玩家。
@export_multiline var double_meaning: String = ""

## 展示用分类名。
func get_category_label() -> String:
	match category:
		Category.RESIDENTS: return "居民"
		Category.Suzu: return "小铃"
		Category.MORRIS: return "莫里斯"
		Category.PIERROT: return "皮埃罗"
		Category.DRY_WELL: return "枯井"
		Category.CLOCK_TOWER: return "钟楼"
		Category.FIRE: return "火灾"
		Category.FRAGMENT: return "记忆碎片"
		Category.LOOP: return "循环"
		Category.ENDING: return "结局"
	return "未分类"


static func category_order() -> Array[Category]:
	return [
		Category.RESIDENTS,
		Category.Suzu,
		Category.MORRIS,
		Category.PIERROT,
		Category.DRY_WELL,
		Category.CLOCK_TOWER,
		Category.FIRE,
		Category.FRAGMENT,
		Category.LOOP,
		Category.ENDING,
	]
