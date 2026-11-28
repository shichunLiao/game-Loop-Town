extends SceneTree
## Deterministic screenshot measurements. Rectangles are fixed between before/after.

const BOXES := {
	"town_entrance": [Rect2i(140,500,55,82),Rect2i(215,500,55,82)],
	"wax_museum": [Rect2i(140,500,55,82),Rect2i(215,500,55,82)],
	"clock_tower": [Rect2i(270,500,65,82),Rect2i(350,500,65,82)]
}

func _initialize() -> void:
	var result := {"method":"sRGB luma 0.2126R + 0.7152G + 0.0722B; fixed actor/context rectangles; mean local 4-neighbour edge delta","scenes":{}}
	for scene_id: String in BOXES:
		var scene_result := {}
		for phase: String in ["before","after"]:
			var image := Image.load_from_file("res://docs/visual-pass-1/"+phase+"/"+scene_id+".png")
			var actor_box: Rect2i = BOXES[scene_id][0]
			var context_box: Rect2i = BOXES[scene_id][1]
			var actor_luma := _mean_luma(image,actor_box)
			var context_luma := _mean_luma(image,context_box)
			scene_result[phase] = {
				"actor_luma":snappedf(actor_luma,0.01),
				"context_luma":snappedf(context_luma,0.01),
				"luma_gap":snappedf(absf(actor_luma-context_luma),0.01),
				"actor_edge":snappedf(_edge_energy(image,actor_box),0.01),
				"context_edge":snappedf(_edge_energy(image,context_box),0.01)
			}
		for phase: String in ["before","after"]:
			scene_result[phase]["edge_separation"] = snappedf(float(scene_result[phase].actor_edge)-float(scene_result[phase].context_edge),0.01)
		scene_result["luma_gap_gain"] = snappedf(float(scene_result.after.luma_gap)-float(scene_result.before.luma_gap),0.01)
		scene_result["actor_edge_gain"] = snappedf(float(scene_result.after.actor_edge)-float(scene_result.before.actor_edge),0.01)
		scene_result["edge_separation_gain"] = snappedf(float(scene_result.after.edge_separation)-float(scene_result.before.edge_separation),0.01)
		result.scenes[scene_id] = scene_result
	var file := FileAccess.open("res://docs/visual-pass-1/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print(JSON.stringify(result,"  "))
	quit()

func _luma(color: Color) -> float:
	return (color.r*0.2126+color.g*0.7152+color.b*0.0722)*255.0

func _mean_luma(image: Image,box: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x):
			total += _luma(image.get_pixel(x,y))
	return total/float(box.size.x*box.size.y)

func _edge_energy(image: Image,box: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(box.position.y,box.end.y-1):
		for x: int in range(box.position.x,box.end.x-1):
			var center := _luma(image.get_pixel(x,y))
			total += absf(center-_luma(image.get_pixel(x+1,y)))+absf(center-_luma(image.get_pixel(x,y+1)))
			count += 2
	return total/float(count)
