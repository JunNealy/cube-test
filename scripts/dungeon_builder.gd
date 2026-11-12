extends Node3D

# Procedurally constructs a 3D dungeon maze with stone walls, floor, and flickering torches

const CELL_SIZE: float = 3.0
const WALL_HEIGHT: float = 2.8

# 1 = Wall, 0 = Corridor
const MAZE_GRID = [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
	[1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
	[1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1],
	[1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1],
	[1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1],
	[1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1],
	[1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
	[1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
]

var wall_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var torch_mat: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_build_floor()
	_build_walls()

func _create_materials() -> void:
	# Wall Material: Slate dungeon stone
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.28, 0.29, 0.33)
	wall_mat.roughness = 0.85
	wall_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	
	# Trim / Cornice Material
	trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.18, 0.19, 0.22)
	trim_mat.roughness = 0.7
	
	# Floor Material: Dark flagstone
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.17, 0.19)
	floor_mat.roughness = 0.75
	
	# Torch Flame Material
	torch_mat = StandardMaterial3D.new()
	torch_mat.albedo_color = Color(1.0, 0.65, 0.2)
	torch_mat.emission_enabled = true
	torch_mat.emission = Color(1.0, 0.6, 0.1)

func _build_floor() -> void:
	var rows = MAZE_GRID.size()
	var cols = MAZE_GRID[0].size()
	var total_w = cols * CELL_SIZE
	var total_h = rows * CELL_SIZE
	
	var floor_body = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	var box_col = BoxShape3D.new()
	box_col.size = Vector3(total_w + 10.0, 1.0, total_h + 10.0)
	col_shape.shape = box_col
	col_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col_shape)
	
	var mesh_inst = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(total_w + 10.0, total_h + 10.0)
	mesh_inst.mesh = plane_mesh
	mesh_inst.material_override = floor_mat
	floor_body.add_child(mesh_inst)
	
	add_child(floor_body)

func _build_walls() -> void:
	var rows = MAZE_GRID.size()
	var cols = MAZE_GRID[0].size()
	var offset_x = (cols * CELL_SIZE) * 0.5 - (CELL_SIZE * 0.5)
	var offset_z = (rows * CELL_SIZE) * 0.5 - (CELL_SIZE * 0.5)
	
	for r in range(rows):
		for c in range(cols):
			var val = MAZE_GRID[r][c]
			var world_x = (c * CELL_SIZE) - offset_x
			var world_z = (r * CELL_SIZE) - offset_z
			
			if val == 1:
				_create_wall_block(Vector3(world_x, WALL_HEIGHT * 0.5, world_z))
			else:
				# Chance to spawn a torch on adjacent walls
				if (r + c) % 4 == 0:
					_maybe_spawn_torch(r, c, world_x, world_z)

func _create_wall_block(pos: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var col = CollisionShape3D.new()
	var box_col = BoxShape3D.new()
	box_col.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	col.shape = box_col
	body.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = wall_mat
	body.add_child(mesh_inst)
	
	# Top trim cornice
	var trim_inst = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(CELL_SIZE + 0.1, 0.25, CELL_SIZE + 0.1)
	trim_inst.mesh = trim_mesh
	trim_inst.material_override = trim_mat
	trim_inst.position.y = (WALL_HEIGHT * 0.5) + 0.12
	body.add_child(trim_inst)
	
	add_child(body)

func _maybe_spawn_torch(r: int, c: int, x: float, z: float) -> void:
	# Check cardinal neighbors for a wall to mount torch on
	var torch_pos = Vector3(x, 1.6, z)
	var light_pos = torch_pos
	
	var torch_node = Node3D.new()
	torch_node.position = light_pos
	
	# Small bracket mesh
	var bracket = MeshInstance3D.new()
	var b_mesh = CylinderMesh.new()
	b_mesh.top_radius = 0.06
	b_mesh.bottom_radius = 0.04
	b_mesh.height = 0.4
	bracket.mesh = b_mesh
	bracket.material_override = trim_mat
	torch_node.add_child(bracket)
	
	# Flame mesh
	var flame = MeshInstance3D.new()
	var f_mesh = SphereMesh.new()
	f_mesh.radius = 0.12
	f_mesh.height = 0.25
	flame.mesh = f_mesh
	flame.material_override = torch_mat
	flame.position.y = 0.25
	torch_node.add_child(flame)
	
	# OmniLight3D
	var light = OmniLight3D.new()
	light.set_script(load("res://scripts/torch.gd"))
	light.light_color = Color(1.0, 0.65, 0.25)
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.omni_attenuation = 1.2
	light.position.y = 0.35
	torch_node.add_child(light)
	
	add_child(torch_node)
