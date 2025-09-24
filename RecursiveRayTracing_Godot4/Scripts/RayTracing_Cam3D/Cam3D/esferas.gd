extends Node

var esferas : Array[Dictionary]
var spheres_number : int = 0

func set_SphereBuffer(tree : Window, data : Resource, rd : RenderingDevice):
	find_Spheres(tree)
	make_SphereBuffer(data, rd)

func find_Spheres(node: Node) -> Array[Dictionary]:
	if node is MeshInstance3D and node.mesh is SphereMesh:
		var material : Material = node.get_active_material(0)
		var radius = node.get("scale").x * 0.5
		var color  = material.get("shader_parameter/albedo")
		var emission_color = material.get("shader_parameter/EmissionColour")
		var specular_color = material.get("shader_parameter/SpecularColour")
		var roughness = material.get("shader_parameter/Smoothness")
		var emission_strenght : float = material.get("shader_parameter/EmissionStrength")
		var spec_probab = material.get("shader_parameter/specular")
		var flag : int = material.get("shader_parameter/flag")
		
		esferas.append({
			"node": node,
			"position": [node.global_position.x, node.global_position.y, node.global_position.z],
			"radius": radius, 
			"color": [color.r, color.g, color.b, color.a],
			"emission_color": emission_color,
			"especular_color": specular_color,
			"roughness": roughness,
			"emission_strenght": emission_strenght,
			"spec_probab": spec_probab,
			"flag": flag
			})
		spheres_number += 1
	for child in node.get_children():
		find_Spheres(child)
	return esferas

func make_SphereBuffer(data : Resource, rd : RenderingDevice):
	var sphere_data : PackedByteArray
	if spheres_number == 0:
		emptyBuffer(sphere_data)
	else:
		for esfera in esferas:
			sphere_data.append_array(
				PackedFloat32Array([
					esfera["position"][0], esfera["position"][1], esfera["position"][2], esfera["radius"],
					esfera["color"][0], esfera["color"][1], esfera["color"][2], esfera["color"][3],
					esfera["emission_color"][0], esfera["emission_color"][1], esfera["emission_color"][2], 1.0,
					esfera["especular_color"][0], esfera["especular_color"][1], esfera["especular_color"][2], esfera["especular_color"][3],
					esfera["roughness"], esfera["emission_strenght"], esfera["spec_probab"]
					]).to_byte_array())
			sphere_data.append_array(PackedInt32Array([esfera["flag"]]).to_byte_array())

	var spheres_buffer : RID = rd.storage_buffer_create(sphere_data.size(), sphere_data)
	data.spheres_buffer = spheres_buffer
	data.spheres_number = spheres_number

func emptyBuffer(sphere_data : PackedByteArray):
	sphere_data.append_array(PackedFloat32Array([
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0
		]).to_byte_array())
	sphere_data.append_array(PackedInt32Array([1]).to_byte_array())
