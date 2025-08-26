extends Node

var malhas : Array[Dictionary]
var mesh_number : int = 0

var triangulos : Array[Dictionary]

func set_MeshesBuffers(tree : Window, comp : Resource, rd : RenderingDevice):
	find_Triangles(tree)
	make_MeshBuffer(comp, rd)
	make_TriangleBuffer(comp, rd)

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
			
			var triangles_number : int = int(indices.size() / 3.0)
			
			## Obter dados da bounding box ( caixa delimitadora )
			var global_aabb = glt * mesh.get_aabb()
			var aabb_c : Vector3 = global_aabb.position
			var aabb_s :Vector3 = global_aabb.position + global_aabb.size
			
			## Obter dados do material da mesh
			var material : Material = mesh.surface_get_material(s)
			var color : Color = material.get("albedo_color")
			var emission_color : Color = material.get("emission")
			var specular_color = [1.0, 1.0, 1.0, 1.0]
			var roughness = 1-material.get("roughness")
			var emission_strenght : float = material.get("emission_energy_multiplier")
			var spec_probab = material.get("metallic_specular")
			
			malhas.append({
				"tri_index": triangulos.size(),
				"tri_number": triangles_number,
				"aabb_center": [aabb_c.x, aabb_c.y, aabb_c.z],
				"aabb_size": [aabb_s.x, aabb_s.y, aabb_s.z],
				"material": [color.r, color.g, color.b, color.a],
				"emission_color": emission_color,
				"especular_color": specular_color,
				"roughness": roughness,
				"emission_strenght": emission_strenght,
				"spec_probab": spec_probab
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

func make_MeshBuffer(comp : Resource, rd : RenderingDevice):
	var mesh_data : PackedByteArray
	for malha in malhas:
		mesh_data.append_array(PackedInt32Array([malha["tri_index"], malha["tri_number"], 0.0, 0.0,]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["aabb_center"][0], malha["aabb_center"][1], malha["aabb_center"][2],0.0]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["aabb_size"][0], malha["aabb_size"][1], malha["aabb_size"][2],0.0]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["material"][0], malha["material"][1], malha["material"][2],malha["material"][3]]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["emission_color"][0], malha["emission_color"][1], malha["emission_color"][2],1.0]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["especular_color"][0], malha["especular_color"][1], malha["especular_color"][2],1.0]).to_byte_array())
		mesh_data.append_array(PackedFloat32Array([malha["roughness"], malha["emission_strenght"], malha["spec_probab"], 0.0]).to_byte_array())
	var mesh_buffer : RID = rd.storage_buffer_create(mesh_data.size(), mesh_data)
	comp.mesh_buffer = mesh_buffer
	comp.mesh_number = malhas.size()

func make_TriangleBuffer(comp : Resource, rd : RenderingDevice):
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
