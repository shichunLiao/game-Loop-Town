class_name ExplorationBuildingFeature
extends ExplorationInteractable
## A hotspot lives in its building's world coordinates, with an actual hurtbox.

var building: ExplorationBuilding
var feature: String = "door"

func _ready() -> void:
	super._ready()
	if feature == "window":
		ExplorationHitArea.hurtbox(self,16,Vector2(46,52),Vector2(0,-24))

func is_finished() -> bool:
	if building == null:
		return true
	if feature == "clue":
		return true
	return false

func prompt() -> String:
	if feature == "door":
		return "E  推门进入 · "+str(building.spec["name"])
	if feature == "window":
		return "E  查看破窗" if building.window_broken() else "E  "+("熄灭窗灯" if building.light_on() else "点亮窗灯")+"  /  J 攻击窗户"
	if feature == "clue":
		return "E  翻阅 · "+str(building.spec["clue_title"])
	return "E  调查 · "+str(building.spec["name"])

func can_receive_hit() -> bool:
	return feature == "window" and not building.window_broken()

func receive_hit(_amount: int, _origin: Vector2, _kind: String = "slash") -> void:
	if can_receive_hit():
		building.break_window()

func _process(delta: float) -> void:
	_clock += delta
	visible = not is_finished()
	queue_redraw()

func _draw() -> void:
	if is_finished():
		return
	if feature == "clue":
		draw_rect(Rect2(-17,-25,34,25),Color("776046"))
		draw_rect(Rect2(-13,-28,26,16),Color("dccba7"))
		for y: int in [-24,-19]:
			draw_line(Vector2(-8,y),Vector2(8,y),Color("876c4b"),1,true)
		if not focused:
			draw_circle(Vector2(0,-43),3,Color("bfe9dc"))
	if focused:
		var height: float = -29 if feature == "window" else -82 if feature == "door" else -54
		draw_circle(Vector2(0,height),12,Color("17232b"))
		draw_arc(Vector2(0,height),12,0,TAU,20,Color("c9b687"),1,true)
		draw_string(_font,Vector2(-5,height+6),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e9dcc0"))
