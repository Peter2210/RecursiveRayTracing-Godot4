extends Node3D

@onready var tree : Window = get_tree().root
var directional_light_3d : DirectionalLight3D

var rd = RenderingServer.get_rendering_device()
var comp : Resource = preload("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

var esferas : Array[Dictionary]
var spheres_number : float = 0

var malhas : Array[Dictionary]
var mesh_number : float = 0

var triangulos : Array[Dictionary]

func _ready():
	set_up_shader()
	comp.ready = true
	ResourceSaver.save(comp, "res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")
	
func _process(_delta: float) -> void:
	pass

func set_up_shader():
	## Criar textura de acumulação
	make_AccumulationTexture()
	
	## Procurar esferas da cena e criar buffer de dados
	find_Spheres(tree)
	make_SphereBuffer()
	
	## Procurar malhas (!esfera) e criar buffer de dados
	find_Triangles(tree)
	
	make_TriangleBuffer()
	make_MeshBuffer()
	## Criação de um buffer obtendo dados do céu (opcional)
	enviroment_param()

func enviroment_param():
	directional_light_3d = tree.get_node("main/DirectionalLight3D")
	var LightDirection : Vector3 = directional_light_3d.global_transform.basis.z.normalized()
	comp.SunLightDirection = [LightDirection.x, LightDirection.y, LightDirection.z, 1.0] 

func find_Triangles(node : Node) -> Array[Dictionary]:
	if node is MeshInstance3D and node.mesh is not SphereMesh:
		var glt : Transform3D = node.global_transform
		var mesh : Mesh = node.get_mesh()
		
		## Obter dados dos triangulos da mesh ( triangulos, normais )
		for s in mesh.get_surface_count():
			var mesh_array : Array = mesh.surface_get_arrays(s)
			var local_normals : PackedVector3Array = mesh_array[Mesh.ARRAY_NORMAL]
			var local_vertex : PackedVector3Array = mesh_array[Mesh.ARRAY_VERTEX]
			var indices : PackedInt32Array = mesh_array[Mesh.ARRAY_INDEX]
			
			var triangles_number = indices.size() / 3.0
			
			## Obter dados da bounding box ( caixa delimitadora )
			var global_aabb = glt * mesh.get_aabb()
			var aabb_c : Vector3 = global_aabb.position
			var aabb_s :Vector3 = global_aabb.position + global_aabb.size
			
			## Obter dados do material da mesh
			var material : Material = mesh.surface_get_material(0)
			var color : Color = material.get("albedo_color")
			var emission_color : Color = material.get("emission")
			var roughness = material.get("roughness")
			var emission_strenght : float = material.get("emission_energy_multiplier")
			
			malhas.append({
				"tri_index": triangulos.size(),
				"tri_number": triangles_number,
				"aabb_center": [aabb_c.x, aabb_c.y, aabb_c.z],
				"aabb_size": [aabb_s.x, aabb_s.y, aabb_s.z],
				"material": [color.r, color.g, color.b, color.a],
				"emission_color": emission_color,
				"roughness": roughness,
				"emission_strenght": emission_strenght
			})
			
			## Transformação das vértices para cena global
			for i in range(0, indices.size(), 3):
				var i0 : int = indices[i]
				var i1 : int = indices[i + 1]
				var i2 : int = indices[i + 2]
				
				var posA = glt * local_vertex[i0]
				var posB = glt * local_vertex[i1]
				var posC = glt * local_vertex[i2]
				
				var normA = (glt.basis * local_normals[i0]) 
				var normB = (glt.basis * local_normals[i1])
				var normC = (glt.basis * local_normals[i2])
				
				triangulos.append({
					"node": node,
					"posA": [posA.x, posA.y, posA.z],
					"posB": [posC.x, posC.y, posC.z],
					"posC": [posB.x, posB.y, posB.z],
					"normA": [normA.x, normA.y, normA.z],
					"normB": [normC.x, normC.y, normC.z],
					"normC": [normB.x, normB.y, normB.z],
				})
			
	for child in node.get_children():
		find_Triangles(child)
	return triangulos

func make_MeshBuffer():
	var mesh_array := PackedFloat32Array()
	for malha in malhas:
		mesh_array.append_array([
			malha["tri_index"],
			malha["tri_number"], 0.0, 0.0,
			malha["aabb_center"][0], malha["aabb_center"][1], malha["aabb_center"][2],1.0,
			malha["aabb_size"][0], malha["aabb_size"][1], malha["aabb_size"][2],1.0,
			malha["material"][0], malha["material"][1], malha["material"][2],malha["material"][3],
			malha["emission_color"][0], malha["emission_color"][1], malha["emission_color"][2],1.0,
			malha["roughness"],
			malha["emission_strenght"], 0.0, 0.0
		])
	var mesh_data : PackedByteArray = mesh_array.to_byte_array()
	var mesh_buffer : RID = rd.storage_buffer_create(mesh_data.size(), mesh_data)
	comp.mesh_buffer = mesh_buffer
	comp.mesh_number = malhas.size()

func make_TriangleBuffer():
	var triangle_array := PackedFloat32Array()
	for triangulo in triangulos:
		triangle_array.append_array([
			triangulo["posA"][0], triangulo["posA"][1], triangulo["posA"][2],1.0,
			triangulo["posB"][0], triangulo["posB"][1], triangulo["posB"][2],1.0,
			triangulo["posC"][0], triangulo["posC"][1], triangulo["posC"][2],1.0,
			triangulo["normA"][0], triangulo["normA"][1], triangulo["normA"][2],1.0,
			triangulo["normB"][0], triangulo["normB"][1], triangulo["normB"][2],1.0,
			triangulo["normC"][0], triangulo["normC"][1], triangulo["normC"][2],1.0,
		])
	var triangle_data : PackedByteArray = triangle_array.to_byte_array()
	var triangle_buffer : RID = rd.storage_buffer_create(triangle_data.size(), triangle_data)
	comp.triangle_buffer = triangle_buffer

func find_Spheres(node: Node) -> Array[Dictionary]:
	if node is MeshInstance3D and node.mesh is SphereMesh:
		var material : Material = node.get_active_material(0)
		var radius = node.get("scale").x * 0.5
		var color : Color = material.get("albedo_color")
		var emission_color = material.get("emission")
		var roughness = material.get("roughness")
		var emission_strenght = material.get("emission_energy_multiplier")
		esferas.append({
			"node": node,
			"position": [node.global_position.x, node.global_position.y, node.global_position.z],
			"radius": radius, 
			"color": [color.r, color.g, color.b, color.a],
			"emission_color": emission_color,
			"roughness": roughness,
			"emission_strenght": emission_strenght
			})
		spheres_number += 1
	for child in node.get_children():
		find_Spheres(child)
	return esferas

func make_SphereBuffer():
	var sphere_array := PackedFloat32Array()
	if spheres_number == 0:
		sphere_array.append_array([
				0.0, 0.0, 0.0, 1.0,
				0.0, 0.0, 0.0, 0.0,
				0.0, 0.0, 0.0, 0.0,
				0.0, 0.0, 0.0, 1.0,
				0.0,
				0.0, 0.0, 0.0
			])
	else:
		for esfera in esferas:
			sphere_array.append_array([
				esfera["position"][0], esfera["position"][1], esfera["position"][2], 1.0,
				esfera["radius"], 0.0, 0.0, 0.0,
				esfera["color"][0], esfera["color"][1], esfera["color"][2], esfera["color"][3],
				esfera["emission_color"][0], esfera["emission_color"][1], esfera["emission_color"][2], 1.0,
				esfera["roughness"],
				esfera["emission_strenght"], 0.0, 0.0
			])
	var sphere_data : PackedByteArray = sphere_array.to_byte_array()
	var spheres_buffer : RID = rd.storage_buffer_create(sphere_data.size(), sphere_data)
	comp.spheres_buffer = spheres_buffer
	comp.spheres_number = spheres_number

func make_AccumulationTexture():
	var format := RDTextureFormat.new()
	format.width = get_viewport().get_texture().get_width()
	format.height = get_viewport().get_texture().get_height()
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	var a_view := RDTextureView.new()

	var accumulation_texture : RID = rd.texture_create(format, a_view)
	comp.accu_tex = accumulation_texture
