extends Node
## World-space ASCII art study: independent vegetation glyphs and surface-anchored hatching.

const VIEW_SIZE := Vector2i(1440, 900)
const START := Vector3(-3.8, -0.13, 3.5)
var rng := RandomNumberGenerator.new()
var world: Node3D
var scenery: Node3D
var camera: Camera3D
var reflection_camera: Camera3D
var player: Node3D
var reflected_player: Node3D
var player_rig: Node3D
var pose_pairs: Array[Array] = []
var move_velocity := Vector3.ZERO
var inspect_character := false
var lantern: OmniLight3D
var output: TextureRect
var ascii_material: ShaderMaterial
var water_material: ShaderMaterial
var info: Label
var status: Label
var player_label: Label
var elapsed := 0.0
var walking := false
var show_interface := true
var blockers: Array[Vector3] = []
var motes: Array[MeshInstance3D] = []
var orbit := 0.0
var zoom := 20.5
var glyph_texture: Texture2D
var glyph_materials: Array[ShaderMaterial] = []
var ascii_enabled := true
var glyph_scale := 1.0
var grass_instances: MultiMesh
var density_level := 2
var materials: Dictionary = {}

func _ready() -> void:
	rng.seed = 41073
	_setup_viewports()
	_build_world()
	_merge_scenery()
	_build_player()
	_build_reflections()
	_build_interface()
	_update_camera()
	_finalize_atlas.call_deferred()
	print("BLACKWATER | Glade ready. WASD / arrows: move. F: ASCII. +/-: glyph size. Wheel: zoom. H: interface.")

func _finalize_atlas() -> void:
	# A one-time readback supplies mip levels for small, oblique surface lettering.
	# Keep the painter and font alive until the viewport has actually drawn.
	await RenderingServer.frame_post_draw
	var atlas_image: Image = get_node("GlyphAtlas").get_texture().get_image()
	atlas_image.generate_mipmaps()
	glyph_texture = ImageTexture.create_from_image(atlas_image)
	for mat in glyph_materials:
		mat.set_shader_parameter("glyphs",glyph_texture)
	get_node("GlyphAtlas").render_target_update_mode = SubViewport.UPDATE_DISABLED

func _setup_viewports() -> void:
	var atlas := SubViewport.new()
	atlas.name = "GlyphAtlas"
	atlas.size = Vector2i(320,192)
	atlas.transparent_bg = true
	atlas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(atlas)
	var painter := Node2D.new()
	painter.set_script(load("res://scripts/glyph_atlas.gd"))
	atlas.add_child(painter)
	glyph_texture = atlas.get_texture()
	var view := SubViewport.new()
	view.name = "WorldViewport"
	view.size = VIEW_SIZE
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	world = Node3D.new()
	world.name = "Glade"
	view.add_child(world)
	scenery = Node3D.new()
	scenery.name = "ReflectableScenery"
	world.add_child(scenery)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 150.0
	world.add_child(camera)
	_setup_environment(world)
	output = TextureRect.new()
	output.name = "ASCII"
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output.texture = view.get_texture()
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.stretch_mode = TextureRect.STRETCH_SCALE
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ascii_material = ShaderMaterial.new()
	ascii_material.shader = load("res://shaders/ascii.gdshader")

	ascii_material.set_shader_parameter("enabled", true)
	ascii_material.set_shader_parameter("cell_size", 6.0)
	output.material = ascii_material
	add_child(output)

func _setup_environment(parent: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("090b13")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("91b4c0")
	env.ambient_light_energy = 0.20
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("080a12")
	env.fog_light_energy = 0.25
	env.fog_density = 0.002
	env_node.environment = env
	parent.add_child(env_node)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52,-32,0)
	moon.light_color = Color("a6c9c1")
	moon.light_energy = 1.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	parent.add_child(moon)

func _mat(color: Color, emission: float = 0.0, kind: int = 0) -> ShaderMaterial:
	color = Color(snappedf(color.r,0.04),snappedf(color.g,0.04),snappedf(color.b,0.04),color.a)
	var key := str(color) + str(emission) + str(kind)
	if materials.has(key):
		return materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/surface_glyphs.gdshader")
	mat.set_shader_parameter("glyphs",glyph_texture)
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("surface_kind",kind)
	mat.set_shader_parameter("glow",emission)
	materials[key] = mat
	glyph_materials.append(mat)
	return mat

func _merge_scenery() -> void:
	# Bake static objects by material: thousands of branches become a few draw calls.
	var batches: Dictionary = {}
	for child in scenery.get_children():
		if child is MeshInstance3D:
			var material_key: Material = child.material_override
			if not batches.has(material_key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[material_key] = surface
			batches[material_key].append_from(child.mesh,0,child.transform)
			scenery.remove_child(child)
			child.queue_free()
	for material_key in batches:
		_mesh(scenery,batches[material_key].commit(),Vector3.ZERO,material_key)

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent,mesh,pos,mat)

func _sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.height = 2.0
	mesh.radius = 1.0
	mesh.radial_segments = 9
	mesh.rings = 5
	var instance := _mesh(parent,mesh,pos,mat)
	instance.scale = scale_value
	return instance

func _branch(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.55
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	var instance := _mesh(parent,mesh,(a+b)*0.5,mat)
	var direction := (b-a).normalized()
	instance.quaternion = Quaternion(Vector3.UP,direction)

func _pond(p: Vector2, margin: float = 0.0) -> bool:
	var d := p-Vector2(3,3)
	return pow(d.x/(6.0+margin),2)+pow(d.y/(3.7+margin),2) < 1.0

func _build_world() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(90,90)
	var terrain := ShaderMaterial.new()
	terrain.shader = load("res://shaders/ground.gdshader")
	glyph_materials.append(terrain)
	_mesh(world,ground,Vector3(0,-0.13,0),terrain)
	_build_grass()
	_build_ruins()
	# Frame the clearing with a dense, uneven treeline; keep the foreground open.
	for i in range(26):
		var p := Vector3(rng.randf_range(-22,22),0,rng.randf_range(-21,11))
		if p.z > -7 and p.x > -11 and p.x < 12:
			continue
		if absf(p.x+1.6) < 3.0 and p.z > -16:
			continue
		_tree(p,rng.randf_range(4.5,8.5))
	for p in [Vector3(-10,0,2),Vector3(12,0,-2),Vector3(-12,0,-5),Vector3(9,0,-9)]:
		_tree(p,7.5)
	for i in range(42):
		var p := Vector3(rng.randf_range(-15,15),0,rng.randf_range(-12,12))
		if _pond(Vector2(p.x,p.z),-0.2):
			continue
		var s := rng.randf_range(0.15,0.65)
		var stone := _sphere(scenery,p+Vector3(0,s*0.24,0),Vector3(s,s*0.5,s*0.8),_mat(Color("354342").lightened(rng.randf_range(-0.18,0.12))))
		stone.rotation = Vector3(rng.randf(),rng.randf()*TAU,rng.randf())
	# Shore stones, reeds and low vegetation outline an irregular oval.
	for i in range(95):
		var angle := float(i)/95.0*TAU
		var p := Vector3(3+cos(angle)*6.1,0,3+sin(angle)*3.8)
		p += Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
		var s := rng.randf_range(0.16,0.44)
		_sphere(scenery,p,Vector3(s,s*0.5,s*0.8),_mat(Color("425951")))
		if i % 3 == 0:
			for j in range(4):
				var a := p+Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
				_branch(scenery,a,a+Vector3(0.08,rng.randf_range(0.5,1.1),0),0.022,_mat(Color("65704c")))
	# Fallen trunk beside the pool.
	_branch(scenery,Vector3(6.7,0.35,6.1),Vector3(10,0.5,4.7),0.4,_mat(Color("37342a")))
	for i in range(35):
		var p := Vector3(rng.randf_range(-11,11),rng.randf_range(0.3,2.3),rng.randf_range(-8,8))
		var mote := _sphere(world,p,Vector3.ONE*rng.randf_range(0.015,0.035),_mat(Color("b6d6a1"),2.0))
		motes.append(mote)

func _build_grass() -> void:
	# World-positioned glyphs, clustered by low-frequency noise. Empty ground is intentional.
	var grass_mesh := QuadMesh.new()
	grass_mesh.size = Vector2(0.13,0.27)
	grass_mesh.center_offset = Vector3(0,0.135,0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = grass_mesh
	var noise := FastNoiseLite.new()
	noise.seed = 183
	noise.frequency = 0.28
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var codes: Array[float] = []
	for i in range(62000):
		var p := Vector3(rng.randf_range(-22,22),0.015,rng.randf_range(-20,15))
		if _pond(Vector2(p.x,p.z),0.18):
			continue
		var path := absf(p.x+2.4+sin(p.z*0.38)*1.2)
		if path < 1.6:
			continue
		var patch := noise.get_noise_2d(p.x,p.z)
		if patch < -0.22 or rng.randf() > smoothstep(-0.22,0.25,patch)*0.90:
			continue
		var scale_value := rng.randf_range(0.65,1.30)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE*scale_value)
		transforms.append(Transform3D(basis,p))
		colors.append(Color("54795b").lerp(Color("8b9767"),rng.randf()*0.38).darkened(rng.randf()*0.40))
		codes.append([47.0,92.0,124.0,47.0,92.0][rng.randi_range(0,4)])
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i,transforms[i])
		multimesh.set_instance_color(i,colors[i])
		multimesh.set_instance_custom_data(i,Color(codes[i],0,0,0))
	var instance := MultiMeshInstance3D.new()
	instance.name = "WorldGlyphGrass"
	instance.multimesh = multimesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("glyphs",glyph_texture)
	glyph_materials.append(mat)
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(instance)
	grass_instances = multimesh
	_set_grass_density(2)

func _tree(p: Vector3, height: float) -> void:
	blockers.append(Vector3(p.x,p.z,0.65))
	var trunk := _mat(Color("514638"))
	_branch(scenery,p,p+Vector3(0.15,height,0),0.23,trunk)
	for root in range(5):
		var a := float(root)/5.0*TAU
		_branch(scenery,p+Vector3(0,0.45,0),p+Vector3(cos(a),0.02,sin(a))*0.9,0.10,trunk)
	for layer in range(5):
		var y := height*(0.25+float(layer)*0.14)
		var radius := height*0.23*(1.0-float(layer)*0.16)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ring: Array[Vector3] = []
		for j in range(17):
			var angle := float(j%16)/16.0*TAU
			var length_value := radius*(0.78 if j%2 else 1.0)
			ring.append(Vector3(cos(angle)*length_value,-0.1 if j%2 else -0.4,sin(angle)*length_value))
		for j in range(16):
			for v in [ring[j],Vector3(0.08,height*0.28,0),ring[j+1]]:
				st.add_vertex(v)
		st.generate_normals()
		_mesh(scenery,st.commit(),p+Vector3(0,y,0),_mat(Color("244437").lightened(float(layer)*0.018),0,1))
		for j in range(5):
			var angle := float(j)/5.0*TAU+float(layer)
			_branch(scenery,p+Vector3(0,y+0.3,0),p+Vector3(cos(angle)*radius,y-0.3,sin(angle)*radius),0.045,trunk)

func _build_ruins() -> void:
	var stone := _mat(Color("a39b83"))
	var dark_stone := _mat(Color("706d60"))
	# A full arch of individually weathered voussoirs.
	var origin := Vector3(-1.6,0,-5.0)
	for side in [-1.0,1.0]:
		blockers.append(Vector3(origin.x+side*2.2,origin.z,0.65))
		for row in range(7):
			var block := _box(scenery,origin+Vector3(side*2.2,0.28+row*0.55,0),Vector3(0.88,0.51,1.03),stone if row%2 else dark_stone)
			block.rotation.y = rng.randf_range(-0.055,0.055)
		_box(scenery,origin+Vector3(side*2.2,0.18,0),Vector3(1.3,0.36,1.4),dark_stone)
		_box(scenery,origin+Vector3(side*2.2,3.65,0),Vector3(1.12,0.24,1.23),stone)
	for i in range(15):
		var angle := float(i)/14.0*PI
		var block := _box(scenery,origin+Vector3(cos(angle)*2.2,3.65+sin(angle)*2.2,0),Vector3(0.51,0.79,1.03),stone if i%3 else dark_stone)
		block.rotation.z = angle-PI*0.5
	# Broken walls, exposed courses and scattered masonry.
	for side in [-1.0,1.0]:
		for col in range(5):
			blockers.append(Vector3(origin.x+side*(3.0+col*0.75),origin.z+0.15,0.43))
			for row in range(4-col/2):
				_box(scenery,origin+Vector3(side*(3.0+col*0.75),0.24+row*0.48,0.15),Vector3(0.7,0.43,0.8),dark_stone)
	for i in range(22):
		var block := _box(scenery,origin+Vector3(rng.randf_range(-5,5),0.15,rng.randf_range(-1.5,1.5)),Vector3(0.65,0.30,0.5),dark_stone)
		block.rotation.y = rng.randf()*TAU
	# Narrow teal runes draw the eye into the arch.
	for side in [-1.0,1.0]:
		for i in range(6):
			var rune := _box(scenery,origin+Vector3(side*2.2,1.1+i*0.32,0.53),Vector3(0.045,0.18,0.022),_mat(Color("83d6c2"),1.6))
			rune.rotation.z = -0.5 if i%2 else 0.5
	# A distant shrine beyond the gate.
	_box(scenery,Vector3(-1.6,0.25,-9),Vector3(1.8,0.5,1.3),stone)
	_sphere(scenery,Vector3(-1.6,1.25,-9),Vector3(0.25,0.52,0.25),_mat(Color("69bea9"),1.5))
	for p in [Vector3(-5.1,0,-3.3),Vector3(2.0,0,-3.3)]:
		_box(scenery,p+Vector3(0,0.5,0),Vector3(0.45,1,0.45),dark_stone)
		_sphere(scenery,p+Vector3(0,1.25,0),Vector3(0.15,0.32,0.15),_mat(Color("ffac53"),3.0))
		var light := OmniLight3D.new()
		light.position = p+Vector3(0,1.6,0)
		light.light_color = Color("ffa45c")
		light.light_energy = 3.5
		light.omni_range = 6
		world.add_child(light)

func _build_player() -> void:
	player = Node3D.new()
	player.name = "Wanderer"
	player.position = START
	player.scale = Vector3.ONE*1.2
	world.add_child(player)
	player_rig = load("res://scripts/wanderer_rig.gd").new()
	player_rig.name = "Rig"
	player.add_child(player_rig)
	player_rig.build(self)
	lantern = player_rig.lantern

func _cache_pose_pairs(source: Node, copy: Node) -> void:
	for i in source.get_child_count():
		var original := source.get_child(i)
		var reflected := copy.get_child(i)
		if original is Node3D:
			pose_pairs.append([original,reflected])
		_cache_pose_pairs(original,reflected)

func _sync_reflection_pose() -> void:
	reflected_player.transform = player.transform
	for pair in pose_pairs:
		pair[1].transform = pair[0].transform

func _build_reflections() -> void:
	var reflection := SubViewport.new()
	reflection.name = "ReflectionViewport"
	reflection.size = VIEW_SIZE / 2
	reflection.own_world_3d = true
	reflection.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(reflection)
	var root := Node3D.new()
	reflection.add_child(root)
	_setup_environment(root)
	var mirror := Node3D.new()
	mirror.scale.y = -1
	root.add_child(mirror)
	mirror.add_child(scenery.duplicate())
	reflected_player = player.duplicate(Node.DUPLICATE_GROUPS)
	mirror.add_child(reflected_player)
	_cache_pose_pairs(player,reflected_player)
	reflection_camera = Camera3D.new()
	reflection_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	reflection_camera.far = 150
	root.add_child(reflection_camera)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(120):
		var a := float(i)/120.0*TAU
		var b := float(i+1)/120.0*TAU
		for p in [Vector3(3,0.015,3),Vector3(3+cos(a)*6.0,0.015,3+sin(a)*3.7),Vector3(3+cos(b)*6.0,0.015,3+sin(b)*3.7)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	water_material.set_shader_parameter("glyphs",glyph_texture)
	glyph_materials.append(water_material)
	water_material.set_shader_parameter("reflection_map",reflection.get_texture())
	_mesh(world,st.commit(),Vector3.ZERO,water_material)

func _label(parent: Control, text_value: String, pos: Vector2, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _build_interface() -> void:
	var ui := Control.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.02,0.035,0.045,0.90)
	panel.size = Vector2(1440,94)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	_label(ui,"B L A C K W A T E R",Vector2(38,21),24,Color("d3d7c3"))
	_label(ui,"LA RADURA SOMMERSA   /   STUDIO VISIVO 02",Vector2(40,58),11,Color("81978b"))
	_label(ui,"N O T T E   I",Vector2(1130,27),14,Color("a4b7ad"))
	_label(ui,"FORESTA DI VESPRO",Vector2(1130,53),11,Color("657e75"))
	var line := ColorRect.new()
	line.position = Vector2(38,92)
	line.size = Vector2(1364,1)
	line.color = Color("35493f")
	ui.add_child(line)
	var bottom := ColorRect.new()
	bottom.position = Vector2(0,825)
	bottom.size = Vector2(1440,75)
	bottom.color = Color(0.02,0.035,0.045,0.92)
	ui.add_child(bottom)
	_label(ui,"IL VIANDANTE",Vector2(38,838),12,Color("c9cbbb"))
	_label(ui,"Una luce tra le rovine.",Vector2(38,858),12,Color("81978b"))
	info = _label(ui,"WASD  muovi     SHIFT  corri     ROTELLA  zoom     Q/E  ruota",Vector2(375,840),12,Color("b1bcae"))
	_label(ui,"C  personaggio    F  3D / ASCII    +/-  glifi    1/2/3  erba    H  UI    R  reset",Vector2(375,861),11,Color("718b80"))
	status = _label(ui,"ASCII / 6 PX",Vector2(1225,841),12,Color("b1cdb8"))
	_label(ui,"PROTOTIPO LOCALE",Vector2(1225,862),10,Color("718b80"))
	player_label = _label(ui,"Viandante",Vector2.ZERO,11,Color("c4cbbd"))
	player_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	player_label.add_theme_constant_override("shadow_offset_x",1)
	player_label.add_theme_constant_override("shadow_offset_y",1)

func _update_camera() -> void:
	var target := player.position+Vector3(0,1.0,0) if inspect_character else Vector3(0,1.5,-1.8)
	var offset := Vector3(12,20,29).rotated(Vector3.UP,orbit)
	camera.position = target+offset
	camera.look_at(target)
	camera.size = 6.5 if inspect_character else zoom
	if is_instance_valid(reflection_camera):
		reflection_camera.transform = camera.transform
		reflection_camera.size = camera.size

func _process(delta: float) -> void:
	elapsed += delta
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var displacement := _move_player(input,delta,running)
	player_rig.advance(delta,displacement,running)
	walking = displacement.length_squared()>0.000001
	_sync_reflection_pose()
	player_label.position = camera.unproject_position(player.position+Vector3(0,2.0,0))-Vector2(25,0)
	lantern.light_energy = 2.8+sin(elapsed*7.2)*0.17+sin(elapsed*13.7)*0.1
	water_material.set_shader_parameter("actor",Vector2(player.position.x,player.position.z))
	for i in motes.size():
		motes[i].position.y += sin(elapsed*0.9+float(i))*delta*0.09
		motes[i].visible = sin(elapsed*0.7+float(i)*1.2)>-0.45
	var turn := float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	if turn != 0:
		orbit += turn*delta*0.4
	if turn != 0 or inspect_character:
		_update_camera()
	var mode := "ASCII" if ascii_enabled else "3D"
	status.text = "%s / %d FPS" % [mode,Engine.get_frames_per_second()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(16,zoom-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(38,zoom+1)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				inspect_character = not inspect_character
				_update_camera()
			KEY_1, KEY_2, KEY_3:
				_set_grass_density(event.physical_keycode-KEY_1+1)
			KEY_F:
				_set_ascii(not ascii_enabled)
			KEY_H:
				show_interface = not show_interface
				get_node("Interface").visible = show_interface
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_set_glyph_scale(minf(1.8,glyph_scale+0.1))
			KEY_MINUS, KEY_KP_SUBTRACT:
				_set_glyph_scale(maxf(0.7,glyph_scale-0.1))
			KEY_R:
				player.position = START
				move_velocity = Vector3.ZERO
				player.rotation.y = 0.0
				player_rig.reset_pose()
				orbit = 0
				zoom = 20.5
				_set_glyph_scale(1.0)
				_set_grass_density(2)
				_update_camera()



func _set_ascii(value: bool) -> void:
	ascii_enabled = value
	ascii_material.set_shader_parameter("enabled",value)
	for mat in glyph_materials:
		mat.set_shader_parameter("ascii_enabled",value)

func _set_glyph_scale(value: float) -> void:
	glyph_scale = value
	for mat in glyph_materials:
		mat.set_shader_parameter("glyph_scale",value)

func _set_grass_density(level: int) -> void:
	density_level = clampi(level,1,3)
	grass_instances.visible_instance_count = int(grass_instances.instance_count * [0.40,0.75,1.0][density_level-1])


func _move_player(input: Vector2, delta: float, running: bool) -> Vector3:
	var direction := Vector3.ZERO
	if input.length_squared()>0:
		input = input.normalized()
		var right := camera.global_basis.x
		var forward := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
		direction = (right*input.x+forward*input.y).normalized()
	var speed := 4.3 if running else 2.2
	move_velocity = move_velocity.move_toward(direction*speed,delta*(14.0 if direction==Vector3.ZERO else 10.0))
	var before := player.position
	var candidate := before+move_velocity*delta
	candidate.x = clampf(candidate.x,-10,11)
	candidate.z = clampf(candidate.z,-10,10)
	var blocked := false
	for obstacle in blockers:
		if Vector2(candidate.x,candidate.z).distance_to(Vector2(obstacle.x,obstacle.y))<obstacle.z+0.25:
			blocked = true
			break
	if not blocked:
		player.position = candidate
	else:
		move_velocity = Vector3.ZERO
	var displacement := player.position-before
	displacement.y = 0
	if displacement.length_squared()>0.000001:
		player.rotation.y = lerp_angle(player.rotation.y,atan2(displacement.x,displacement.z),1.0-exp(-delta*15.0))
	var floor_height := -0.27 if _pond(Vector2(player.position.x,player.position.z),-0.1) else -0.13
	player.position.y = move_toward(player.position.y,floor_height,delta*1.3)
	return displacement
