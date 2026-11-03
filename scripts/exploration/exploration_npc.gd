class_name ExplorationNPC
extends Node2D

var spec: Dictionary
var session: ExplorationSession
var data: Dictionary
var visual: Sprite2D
var focused: bool = false
var _clock: float = 0
var _stutter: float = 0
var _line: int = 0
var _font: Font

func _ready() -> void:
	position = ExplorationCatalog.vec(spec["pos"])
	data = ExplorationArt.actors()["npcs"][str(spec.get("type",spec["id"]))].duplicate(true)
	data["name"] = str(spec.get("role",data["name"]))
	visual = ExplorationArt.visual(self,str(data["atlas"]),120,int(data["cell"]))
	_font = load("res://assets/ui/exploration/chinese.tres") as Font

func talk() -> void:
	_stutter = .7
	var demo: Node = get_tree().get_first_node_in_group("exploration_demo")
	var lines: Array = data["lines"]
	var text: String = str(lines[_line % lines.size()])
	_line += 1
	session.switches["talked_"+str(spec["id"])] = true
	var regional_room: String = str(ExplorationCatalog.room(session.room_id).get("parent_region",session.room_id))
	var hints: Array[String] = []
	for id: String in ExplorationJournal.definitions()["gates"]:
		var gate: Dictionary = ExplorationJournal.definitions()["gates"][id]
		if str(gate["hint_room"])==regional_room:
			session.switches["hint_"+id] = true
			if not session.has("opened_"+id) and not hints.has(str(gate["text"])):
				hints.append(str(gate["text"]))
	if not hints.is_empty():
		text += "\n\n「道路的事」\n"+hints[0]
	var quest: Dictionary = ExplorationJournal.side_task(str(spec.get("quest_id","")))
	var choices: Array = []
	if not quest.is_empty():
		var id: String = str(quest["id"])
		var status: String = str(session.quest_state.get(id,""))
		if status=="accepted" and session.has(str(quest["flag"])):
			session.quest_state[id] = "rewarded"
			if str(session.quest_state.get("tracked",""))==id:
				session.quest_state["tracked"] = "main"
			demo.player.health = mini(100,demo.player.health+30)
			demo.player.energy = minf(100,demo.player.energy+40)
			text = "你找到它了。纸上留下的事，我会记住。\n\n委托完成：「"+str(quest["title"])+"」\n生命恢复 30，墨光恢复 40。谢谢你没有把这当成无关紧要的事。"
		elif status=="":
			text += "\n\n「委托："+str(quest["title"])+"」\n"+str(quest["text"])+"\n回报：生命恢复 30、墨光恢复 40。"
			choices = [{"label":"接受委托并追踪", "action":func(): ExplorationJournal.accept(session,id); demo.close_overlay(); demo.hud.toast("已接受委托 · L 查看任务与地点")},{"label":"稍后再来", "action":demo.close_overlay}]
		elif status=="accepted":
			text += "\n\n还在等你寻找的线索：\n"+str(quest["text"])
		elif status=="rewarded":
			text += "\n\n你带回的那张纸，我已经收好了。"
	session.changed.emit()
	session.save()
	demo.show_dialogue(str(data["name"]),text,choices)

func interaction_prompt() -> String:
	var quest: Dictionary = ExplorationJournal.side_task(str(spec.get("quest_id","")))
	if not quest.is_empty() and str(session.quest_state.get(str(quest["id"]),""))=="accepted" and session.has(str(quest["flag"])):
		return "E  交付线索 · "+str(data["name"])
	return "E  交谈 · "+str(data["name"])

func _process(delta: float) -> void:
	visible = true
	modulate = Color(.78,.73,.68,.8) if session.stage>=4 and str(spec.get("type",spec["id"]))!="conductor" else Color.WHITE
	_stutter = maxf(0,_stutter-delta)
	if _stutter <= 0:
		_clock += delta
	visual.rotation = sin(_clock*1.7+int(data["cell"]))*0.014
	visual.position.y = -60+sin(_clock*2.0)*1.1
	queue_redraw()

func _draw() -> void:
	var quest: Dictionary = ExplorationJournal.side_task(str(spec.get("quest_id","")))
	if not quest.is_empty() and str(session.quest_state.get(str(quest["id"]),""))!="rewarded":
		var accepted: bool = str(session.quest_state.get(str(quest["id"]),""))=="accepted"
		var ready: bool = accepted and session.has(str(quest["flag"]))
		draw_circle(Vector2(0,-133),13,Color("182b30"))
		draw_string(_font,Vector2(-5,-127),"?" if ready else "·" if accepted else "!",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("edc78a"))
	if focused:
		draw_string(_font,Vector2(-105,-158),str(data["name"]),HORIZONTAL_ALIGNMENT_CENTER,210,16,Color("e9d5ac"))
