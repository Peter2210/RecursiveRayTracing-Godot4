extends Node

var esferas : Array[Dictionary]
var spheres_number : int = 0

func set_SphereBuffer(tree : Window, comp : Resource, rd : RenderingDevice):
	find_Spheres(tree)
	make_SphereBuffer(comp, rd)

func find_Spheres(node: Node) -> Array[Dictionary]:
	if node is MeshInstance3D and node.mesh is SphereMesh:
		var material : Material = node.get_active_material(0)
		var radius = node.get("scale").x * 0.5
		var color : Color = material.get("albedo_color")
		var emission_color = material.get("emission")
		var specular_color = [1.0, 1.0, 1.0, 1.0]
		var roughness = 1-material.get("roughness")
		var emission_strenght = material.get("emission_energy_multiplier")
		var spec_probab = material.get("metallic_specular")
		esferas.append({
			"node": node,
			"position": [node.global_position.x, node.global_position.y, node.global_position.z],
			"radius": radius, 
			"color": [color.r, color.g, color.b, color.a],
			"emission_color": emission_color,
			"especular_color": specular_color,
			"roughness": roughness,
			"emission_strenght": emission_strenght,
			"spec_probab": spec_probab
			})
		spheres_number += 1
	for child in node.get_children():
		find_Spheres(child)
	return esferas

func make_SphereBuffer(comp : Resource, rd : RenderingDevice):
	var sphere_array := PackedFloat32Array()
	if spheres_number == 0:
		sphere_array.append_array([
				1.0, 1.0, 1.0, 1.0,
				1.0, 1.0, 1.0, 1.0,
				1.0, 1.0, 1.0, 1.0,
				1.0, 1.0, 1.0, 1.0,
				1.0, 1.0, 1.0, 1.0,
				1.0,
				1.0, 1.0, 1.0
			])
	else:
		for esfera in esferas:
			sphere_array.append_array([
				esfera["position"][0], esfera["position"][1], esfera["position"][2],
				esfera["radius"],
				esfera["color"][0], esfera["color"][1], esfera["color"][2], esfera["color"][3],
				esfera["emission_color"][0], esfera["emission_color"][1], esfera["emission_color"][2], 1.0,
				esfera["especular_color"][0], esfera["especular_color"][1], esfera["especular_color"][2], esfera["especular_color"][3],
				esfera["roughness"],
				esfera["emission_strenght"],
				esfera["spec_probab"], 0.0
			])
	var sphere_data : PackedByteArray = sphere_array.to_byte_array()
	var spheres_buffer : RID = rd.storage_buffer_create(sphere_data.size(), sphere_data)
	comp.spheres_buffer = spheres_buffer
	comp.spheres_number = spheres_number
