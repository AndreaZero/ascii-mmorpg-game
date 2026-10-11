extends RefCounted
## Run against the live scene through Godot AI game_eval; restores the player afterwards.
func run_checks(game: Node) -> Dictionary:
	var rig = game.player_rig
	var saved: Transform3D = game.player.transform
	var saved_velocity: Vector3 = game.move_velocity
	var max_stance_slide := 0.0
	var max_floor_error := 0.0
	var max_leg_length := 0.0
	var swing_frames := 0
	var states: Array[String] = []
	for running in [false,true]:
		game.player.position = Vector3(-5,-0.13,4)
		game.player.rotation.y = 0
		rig.reset_pose()
		for frame in range(180):
			var previous: Array[Vector3] = [rig.legs[0].foot,rig.legs[1].foot]
			var was_swinging: Array[bool] = [rig.legs[0].swing,rig.legs[1].swing]
			var step := Vector3(0,0,(4.3 if running else 2.2)/60.0)
			game.player.position += step
			rig.advance(1.0/60.0,step,running)
			for i in range(2):
				var leg: Dictionary = rig.legs[i]
				if not leg.swing and not was_swinging[i]:
					max_stance_slide = maxf(max_stance_slide,Vector2(leg.foot.x,leg.foot.z).distance_to(Vector2(previous[i].x,previous[i].z)))
				if not leg.swing:
					max_floor_error = maxf(max_floor_error,absf(leg.foot.y-game.player.position.y-0.08*1.2))
				else:
					swing_frames += 1
				max_leg_length = maxf(max_leg_length,leg.shin.scale.y)
		states.append(rig.state)
	var phase_before: float = rig.phase
	for frame in range(90):
		rig.advance(1.0/60.0,Vector3.ZERO,false)
	var idle_stops: bool = rig.state=="idle" and is_equal_approx(rig.phase,phase_before) and rig.locomotion==0
	var obstacle: Vector3 = game.blockers[0]
	var direction: Vector3 = game.camera.global_basis.x.normalized()
	game.player.position = Vector3(obstacle.x,-0.13,obstacle.y)-direction*(obstacle.z+0.255)
	game.move_velocity = direction*2.2
	rig.reset_pose()
	var blocked_step: Vector3 = game._move_player(Vector2.RIGHT,1.0/60.0,false)
	rig.advance(1.0/60.0,blocked_step,false)
	var blocked_stops: bool = blocked_step.length()<0.0001 and rig.state=="idle"
	game._sync_reflection_pose()
	var reflection_matches := true
	for pair in game.pose_pairs:
		if not pair[0].transform.is_equal_approx(pair[1].transform):
			reflection_matches = false
	game.player.transform = saved
	game.move_velocity = saved_velocity
	rig.reset_pose()
	game._sync_reflection_pose()
	return {"states":states,"stance_slide_metres":max_stance_slide,"floor_error_metres":max_floor_error,"longest_shin_local":max_leg_length,"swing_frames":swing_frames,"idle_stops":idle_stops,"blocked_stops":blocked_stops,"reflection_matches":reflection_matches,"passed":max_stance_slide<0.0001 and max_floor_error<0.0001 and max_leg_length<0.501 and idle_stops and blocked_stops and reflection_matches and swing_frames>100}
