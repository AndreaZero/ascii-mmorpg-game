extends Node3D
## Distance-driven two-bone legs. Stance feet stay planted in world coordinates.

const HIP_HEIGHT := 0.88
const LEG_LENGTH := 0.50
const ANKLE_HEIGHT := 0.08
const STANCE := 0.56
var torso: Node3D
var head: Node3D
var cape: Node3D
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var legs: Array[Dictionary] = []
var lantern_mount: Node3D
var lantern: OmniLight3D
var phase := 0.0
var clock := 0.0
var locomotion := 0.0
var run_blend := 0.0
var state := "idle"
var previous_position := Vector3.ZERO
var initialized := false
var was_moving := false

func pivot(parent: Node3D, node_name: String, position_value: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = position_value
	parent.add_child(node)
	return node

func build(art: Node) -> void:
	var cloth: Material = art._mat(Color("344855"),0,2)
	var steel: Material = art._mat(Color("a7bac0"),0,3)
	var leather: Material = art._mat(Color("62645b"),0,2)
	var black: Material = art._mat(Color("141d24"),0,2)
	torso = pivot(self,"Torso",Vector3(0,HIP_HEIGHT,0))
	art._box(torso,Vector3(0,0,0),Vector3(0.34,0.20,0.23),leather)
	art._box(torso,Vector3(0,0.29,0),Vector3(0.43,0.43,0.27),cloth)
	art._box(torso,Vector3(0,0.30,0.15),Vector3(0.32,0.35,0.055),steel)
	art._box(torso,Vector3(0,0.065,0.02),Vector3(0.38,0.075,0.28),leather)
	head = pivot(torso,"Head",Vector3(0,0.63,0))
	art._sphere(head,Vector3.ZERO,Vector3(0.23,0.27,0.24),cloth)
	art._sphere(head,Vector3(0,-0.01,0.16),Vector3(0.16,0.18,0.09),black)
	art._box(head,Vector3(0,-0.10,0.21),Vector3(0.25,0.065,0.04),leather)
	cape = pivot(torso,"Cape",Vector3(0,0.5,-0.08))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for col in range(8):
		var x0 := float(col)/8.0
		var x1 := float(col+1)/8.0
		var a := Vector3((x0-0.5)*0.5,0,-0.15)
		var b := Vector3((x1-0.5)*0.5,0,-0.15)
		var c := Vector3((x0-0.5)*0.78,-0.83,-0.26-(0.065 if col%2 else 0.0))
		var d := Vector3((x1-0.5)*0.78,-0.83,-0.26-(0.065 if (col+1)%2 else 0.0))
		for v in [a,b,c,b,d,c]:
			surface.add_vertex(v)
	surface.generate_normals()
	art._mesh(cape,surface.commit(),Vector3.ZERO,cloth)
	for i in range(2):
		var side := -1.0 if i==0 else 1.0
		var hip := Vector3(side*0.17,HIP_HEIGHT,0)
		var thigh := limb(art,"Thigh%d"%i,0.09,cloth)
		var shin := limb(art,"Shin%d"%i,0.075,steel)
		var knee: MeshInstance3D = art._sphere(self,Vector3.ZERO,Vector3.ONE*0.105,steel)
		var boot: MeshInstance3D = art._box(self,Vector3.ZERO,Vector3(0.19,0.16,0.33),leather)
		boot.name = "Boot%d"%i
		legs.append({"hip":hip,"thigh":thigh,"shin":shin,"knee":knee,"boot":boot,"anchor":Vector3.ZERO,"start":Vector3.ZERO,"goal":Vector3.ZERO,"swing":false,"foot":Vector3.ZERO,"swing_origin":STANCE})
		var shoulder := pivot(torso,"Shoulder%d"%i,Vector3(side*0.29,0.44,0))
		art._sphere(shoulder,Vector3.ZERO,Vector3(0.17,0.12,0.18),steel)
		art._box(shoulder,Vector3(0,-0.15,0),Vector3(0.13,0.30,0.14),cloth)
		var elbow := pivot(shoulder,"Elbow",Vector3(0,-0.29,0))
		art._box(elbow,Vector3(0,-0.135,0),Vector3(0.115,0.27,0.13),steel)
		art._sphere(elbow,Vector3(0,-0.29,0),Vector3(0.075,0.09,0.075),leather)
		arms.append(shoulder)
		forearms.append(elbow)
		if i==1:
			lantern_mount = pivot(elbow,"Lantern",Vector3(0,-0.33,0))
			art._branch(lantern_mount,Vector3.ZERO,Vector3(0,-0.12,0),0.018,steel)
			art._box(lantern_mount,Vector3(0,-0.24,0),Vector3(0.16,0.22,0.16),art._mat(Color("ffc77d"),2.5))
			art._box(lantern_mount,Vector3(0,-0.12,0),Vector3(0.20,0.035,0.20),leather)
			art._box(lantern_mount,Vector3(0,-0.36,0),Vector3(0.20,0.035,0.20),leather)
			lantern = OmniLight3D.new()
			lantern.light_color = Color("ffbf7c")
			lantern.light_energy = 2.8
			lantern.omni_range = 4.5
			lantern.position.y = -0.24
			lantern_mount.add_child(lantern)
		else:
			art._box(elbow,Vector3(0,-0.57,0.025),Vector3(0.04,0.48,0.065),steel)
			art._box(elbow,Vector3(0,-0.34,0.025),Vector3(0.22,0.035,0.07),steel)
	reset_pose()

func limb(art: Node, node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.top_radius = radius
	mesh.bottom_radius = radius*0.8
	mesh.radial_segments = 7
	var instance: MeshInstance3D = art._mesh(self,mesh,Vector3.ZERO,material)
	instance.name = node_name
	return instance

func reset_pose() -> void:
	phase = 0.0
	locomotion = 0.0
	run_blend = 0.0
	was_moving = false
	previous_position = global_position
	for leg in legs:
		var neutral := to_global(Vector3(leg.hip.x,ANKLE_HEIGHT,0.03))
		leg.anchor = neutral
		leg.start = neutral
		leg.goal = neutral
		leg.foot = neutral
		leg.swing = false
	initialized = true
	advance(0.0,Vector3.ZERO,false)

func place_limb(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	mesh.position = (a+b)*0.5
	mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	mesh.scale = Vector3(1,a.distance_to(b),1)

func solve_leg(leg: Dictionary, foot_world: Vector3) -> void:
	var ankle := to_local(foot_world)
	var hip: Vector3 = leg.hip+Vector3(0,torso.position.y-HIP_HEIGHT,0)
	var offset := ankle-hip
	var distance_value := clampf(offset.length(),0.01,LEG_LENGTH*2.0-0.001)
	var axis := offset.normalized()
	var bend := Vector3.FORWARD*-1.0
	bend = (bend-axis*bend.dot(axis)).normalized()
	var knee := hip+axis*distance_value*0.5+bend*sqrt(maxf(0.0,LEG_LENGTH*LEG_LENGTH-distance_value*distance_value*0.25))
	place_limb(leg.thigh,hip,knee)
	place_limb(leg.shin,knee,ankle)
	leg.knee.position = knee
	leg.boot.position = ankle+Vector3(0,0,0.065)
	leg.boot.rotation.x = -0.15*sin(phase*TAU)*locomotion if leg.swing else 0.0
	leg.foot = foot_world

func advance(delta: float, displacement: Vector3, running: bool) -> void:
	if not initialized:
		return
	clock += delta
	var distance_value := Vector2(displacement.x,displacement.z).length()
	var moving := distance_value>0.0001
	if moving and not was_moving:
		phase = STANCE*0.5
	locomotion = move_toward(locomotion,1.0 if moving else 0.0,delta*7.0)
	run_blend = move_toward(run_blend,1.0 if running and moving else 0.0,delta*5.0)
	state = ("run" if running else "walk") if moving else "idle"
	var cycle_distance := lerpf(1.50,2.00,run_blend)
	phase = fposmod(phase+distance_value/cycle_distance,1.0)
	var wave := sin(phase*TAU)
	torso.position.y = HIP_HEIGHT-0.035*run_blend+cos(phase*TAU*2.0)*0.022*locomotion+sin(clock*1.6)*0.005*(1.0-locomotion)
	torso.rotation = Vector3(0.08*run_blend,0.05*wave*locomotion,0.025*wave*locomotion)
	head.rotation.y = -torso.rotation.y*0.5
	cape.rotation.x = 0.10+run_blend*0.30+sin(phase*TAU*2.0)*0.06*locomotion
	cape.rotation.z = wave*0.07*locomotion+sin(clock*1.2)*0.015
	var direction := displacement.normalized() if moving else global_basis.z.normalized()
	var scale_value := global_basis.y.length()
	for i in legs.size():
		var leg: Dictionary = legs[i]
		var leg_phase := fposmod(phase+float(i)*0.5,1.0)
		var floor_height := global_position.y+ANKLE_HEIGHT*scale_value
		var foot: Vector3 = leg.foot
		if moving:
			var swing := leg_phase>=STANCE
			if swing and not leg.swing:
				leg.start = leg.anchor
				leg.swing_origin = leg_phase
				leg.goal = global_position+global_basis.x*leg.hip.x+direction*cycle_distance*(1.0-leg_phase+STANCE*0.5)
				leg.goal.y = floor_height
			if swing:
				var t: float = (leg_phase-leg.swing_origin)/(1.0-leg.swing_origin)
				foot = leg.start.lerp(leg.goal,smoothstep(0.0,1.0,t))
				foot.y = floor_height+sin(t*PI)*lerpf(0.16,0.28,run_blend)
			else:
				if leg.swing:
					leg.anchor = leg.goal
				foot = leg.anchor
				foot.y = floor_height
			leg.swing = swing
		else:
			var neutral := to_global(Vector3(leg.hip.x,ANKLE_HEIGHT,0.03))
			foot = foot.lerp(neutral,1.0-exp(-delta*14.0))
			leg.anchor = foot
			leg.swing = false
		solve_leg(leg,foot)
		var arm_wave := sin((phase+float(i)*0.5)*TAU)
		arms[i].rotation.x = -arm_wave*lerpf(0.48,0.7,run_blend)*locomotion
		arms[i].rotation.z = 0.12 if i==0 else -0.17
		forearms[i].rotation.x = -0.18-run_blend*0.5
	# Cancel the arm rotation so the hanging lantern remains approximately vertical.
	lantern_mount.rotation.x = -arms[1].rotation.x-forearms[1].rotation.x-torso.rotation.x+wave*0.10*locomotion
	lantern_mount.rotation.z = sin(phase*TAU+0.6)*0.10*locomotion
	previous_position = global_position
	was_moving = moving
