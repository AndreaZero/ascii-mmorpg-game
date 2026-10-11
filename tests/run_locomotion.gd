extends SceneTree
## Run with: godot --headless --path . --script res://tests/run_locomotion.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/glade.tscn") as PackedScene
	if scene == null:
		push_error("Could not load the clearing scene.")
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	var result: Dictionary = load("res://tests/locomotion_probe.gd").new().run_checks(game)
	print(JSON.stringify(result, "  "))
	var passed: bool = result.get("passed", false)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
