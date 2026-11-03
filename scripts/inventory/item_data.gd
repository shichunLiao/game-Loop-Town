class_name ItemData
extends Resource

## 道具 / 消耗品数据。第一章可拾取的信件、剪刀、纽扣等都用它描述。

enum Kind {
	KEY_ITEM,   ## 关键道具，不可消耗（信件、布偶、大剪刀）
	CONSUMABLE, ## 消耗品（投掷物）
	RELIC,      ## 决斗掉落物，提供被动效果
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var kind: Kind = Kind.KEY_ITEM
## 可消耗道具的持有数量上限。
@export var max_stack: int = 1
## 作为武器时覆盖玩家基础攻击力的伤害值；<= 0 表示沿用玩家默认攻击。
@export var attack_damage: int = 0
## 拾取时写入的剧情 flag，便于关卡逻辑判定进度。
@export var grants_flag: StringName = &""
## 是否在拿到后立即打开笔记本（记忆碎片为 true，普通道具为 false）。
@export var opens_notebook: bool = false

func is_stackable() -> bool:
	return kind == Kind.CONSUMABLE and max_stack > 1
