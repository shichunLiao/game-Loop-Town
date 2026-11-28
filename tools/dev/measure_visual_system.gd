extends SceneTree
## Fixed-box pass-two comparison; coordinates intentionally match the pass-one method.

const BOXES := {
	"town_entrance":[Rect2i(140,500,55,82),Rect2i(215,500,55,82)],
	"wax_museum":[Rect2i(140,500,55,82),Rect2i(215,500,55,82)],
	"clock_tower":[Rect2i(270,500,65,82),Rect2i(350,500,65,82)]
}

func _initialize() -> void:
	var result := {"method":"sRGB luma; fixed actor/context boxes; mean local 4-neighbour edge delta","scenes":{}}
	for scene_id: String in BOXES:
		var scene := {}
		for phase: String in ["before","after"]:
			var image := Image.load_from_file("res://docs/visual-pass-2/"+phase+"/1280x720/"+scene_id+".png")
			var actor: Rect2i = BOXES[scene_id][0]
			var context: Rect2i = BOXES[scene_id][1]
			var actor_luma := _mean_luma(image,actor)
			var context_luma := _mean_luma(image,context)
			scene[phase] = {"actor_luma":snappedf(actor_luma,.01),"context_luma":snappedf(context_luma,.01),"luma_gap":snappedf(absf(actor_luma-context_luma),.01),"actor_edge":snappedf(_edge(image,actor),.01),"context_edge":snappedf(_edge(image,context),.01)}
			scene[phase]["edge_separation"] = snappedf(float(scene[phase].actor_edge)-float(scene[phase].context_edge),.01)
		scene["luma_gap_gain"] = snappedf(float(scene.after.luma_gap)-float(scene.before.luma_gap),.01)
		scene["edge_separation_gain"] = snappedf(float(scene.after.edge_separation)-float(scene.before.edge_separation),.01)
		result.scenes[scene_id] = scene
	var file := FileAccess.open("res://docs/visual-pass-2/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print(JSON.stringify(result,"  "))
	quit()

func _luma(color: Color) -> float:
	return (color.r*.2126+color.g*.7152+color.b*.0722)*255.0

func _mean_luma(image: Image, box: Rect2i) -> float:
	var total := 0.0
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x):
			total += _luma(image.get_pixel(x,y))
	return total/float(box.size.x*box.size.y)

func _edge(image: Image, box: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y: int in range(box.position.y,box.end.y-1):
		for x: int in range(box.position.x,box.end.x-1):
			var center := _luma(image.get_pixel(x,y))
			total += absf(center-_luma(image.get_pixel(x+1,y)))+absf(center-_luma(image.get_pixel(x,y+1)))
			count += 2
	return total/float(count)
