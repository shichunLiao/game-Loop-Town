extends SceneTree
## Pass-two contract: inherited region families, adaptive/graded actor treatment and responsive HUD.

var _passed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	assert(value,message)
	_passed += 1
	print("PASS visual-system: ",message)

func _run() -> void:
	var examples := {
		"town_entrance":"town", "old_theater":"theater", "back_stage":"backstage",
		"wax_lane":"wax", "wax_museum":"museum", "wax_basement":"basement",
		"train_station":"station", "well_interior":"well", "fire_town":"fire", "clock_tower":"clocktower"
	}
	for room_id: String in examples:
		var profile := ExplorationVisualProfile.room_profile(room_id)
		_check(str(profile["family"])==str(examples[room_id]),room_id+" inherits "+str(examples[room_id])+" family")
		_check(float(profile["far_contrast"])<=0.80 and float(profile["far_saturation"])<=0.85,room_id+" keeps quantified far-plane separation")
		_check(float(profile["mid_brightness"])>float(profile["far_brightness"]),room_id+" mid plane reads above far plane")
	var interior := ExplorationVisualProfile.room_profile("inside_building_town_entrance_0")
	_check(str(interior["family"])=="town","building interior inherits parent region family")

	var bright := ShaderMaterial.new()
	bright.shader = load("res://assets/environments/exploration/actors/rim_light.gdshader") as Shader
	ExplorationVisualProfile.configure_actor(bright,"player","hero","fire_town")
	var dark := ShaderMaterial.new()
	dark.shader = bright.shader
	ExplorationVisualProfile.configure_actor(dark,"player","hero","well_interior")
	_check(float(bright.get_shader_parameter("outline_width"))<float(dark.get_shader_parameter("outline_width")),"bright fire background uses a quieter dark edge")
	_check(float(dark.get_shader_parameter("rim_width"))>float(bright.get_shader_parameter("rim_width")),"dark well background lifts the directional rim")

	for role: String in ["player","npc","enemy","boss","keeper"]:
		var material := ShaderMaterial.new()
		material.shader = bright.shader
		ExplorationVisualProfile.configure_actor(material,role,"hero","town_entrance")
		var expected_high := role in ["player","boss","keeper"]
		_check(bool(material.get_shader_parameter("high_quality"))==expected_high,role+" receives importance-based 8/4-tap quality")

	for actor_id: String in ["hero","may_idle","keeper_hidden","detective"]:
		var region: Vector4 = ExplorationVisualProfile.FACE_REGIONS[actor_id]
		_check(region.y-region.x<=0.35 and region.w-region.z<=0.27,actor_id+" face lift excludes most clothing")

	for size: Vector2 in [Vector2(1280,720),Vector2(1920,1080)]:
		var layout := ExplorationHUD.hud_layout(size,false,900)
		var objective: Rect2 = layout["objective"]
		var counter: Rect2 = layout["counter"]
		var direction: Rect2 = layout["direction"]
		var prompt: Rect2 = layout["prompt"]
		_check(not objective.intersects(counter) and not counter.intersects(direction),str(size)+" top-right HUD stack does not overlap")
		_check(prompt.size.x<=620 and prompt.end.x<=size.x-40 and prompt.position.x>=40,str(size)+" bottom prompt is capped and in bounds")
		_check((layout["toast"] as Rect2).end.x<=size.x and (layout["controls"] as Rect2).end.y<=size.y,str(size)+" tutorial and controls remain in bounds")

	var shader_source := FileAccess.get_file_as_string("res://assets/environments/exploration/actors/rim_light.gdshader")
	_check(shader_source.contains("if (high_quality)"),"outline shader exposes four/eight tap path")
	_check(shader_source.contains("face_region"),"face lift is driven by actor-local region")
	print("VISUAL_SYSTEM_QA: ",_passed," passed / 0 failed")
	quit()
