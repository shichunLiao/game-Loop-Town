extends SceneTree
## Contract checks for the visual pass: quantified depth, role outlines and scene wiring.

var _passed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	assert(value, message)
	_passed += 1
	print("PASS visual: ",message)

func _run() -> void:
	for room_id: String in ["town_entrance","wax_museum","clock_tower"]:
		var profile := ExplorationVisualProfile.room_profile(room_id)
		_check(float(profile["far_contrast"])<=0.80,room_id+" far contrast reduced >=20%")
		_check(float(profile["far_saturation"])<=0.85,room_id+" far saturation reduced >=15%")
		_check(float(profile["far_fog"])>=0.18,room_id+" far fog separates plane")
		_check(float(profile["mid_brightness"])>float(profile["far_brightness"]),room_id+" mid plane reads above far plane")
		_check((profile["play_accent"] as Color).get_luminance()>(profile["fog_color"] as Color).get_luminance(),room_id+" gameplay edge accent exceeds fog")
	var expected_width := {"player":1.85,"npc":1.50,"enemy":1.82,"boss":2.0,"keeper":1.94}
	var expected_outline := {"player":Color(0.13,0.075,0.055,0.98),"npc":Color(0.14,0.09,0.07,0.90),"enemy":Color(0.19,0.045,0.035,0.98)}
	for role: String in expected_width:
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/environments/exploration/actors/rim_light.gdshader") as Shader
		ExplorationVisualProfile.configure_actor(material,role,"","unknown_room")
		_check(absf(float(material.get_shader_parameter("outline_width"))-float(expected_width[role]))<0.01,role+" screen-pixel outline width")
		_check(float(material.get_shader_parameter("rim_width"))<1.0,role+" uses narrow directional rim, not full glow")
		if expected_outline.has(role):
			_check((material.get_shader_parameter("outline_color") as Color).is_equal_approx(expected_outline[role]),role+" outline palette")
	var host := Node2D.new()
	root.add_child(host)
	var targets := [["hero","player"],["may_idle","boss"],["keeper_back","keeper"],["enemies_a", "enemy"],["enemies_b","enemy"]]
	for target: Array in targets:
		var visual := ExplorationArt.visual(host,str(target[0]),105,0 if str(target[0]).begins_with("enemies") else -1,str(target[1]))
		_check(visual.texture!=null,str(target[0])+" keeps core art")
		_check(visual.material is ShaderMaterial,str(target[0])+" receives shared actor material")
		_check(visual.get_parent().get_node_or_null("VisualGrounding")!=null,str(target[0])+" receives contact shadow")
		visual.queue_free()
		var grounding := host.get_node_or_null("VisualGrounding")
		if grounding!=null:
			grounding.queue_free()
		await process_frame
	host.queue_free()
	await process_frame
	print("VISUAL_PASS_QA: ",_passed," passed / 0 failed")
	quit()
