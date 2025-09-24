extends Node

var directional_light_3d : DirectionalLight3D

func set_Ambiente(tree : Window, data : Resource):
	directional_light_3d = tree.get_node("main/DirectionalLight3D")
	var LightDirection : Vector3 = directional_light_3d.global_transform.basis.z.normalized()
	data.SunLightDirection = [LightDirection.x, LightDirection.y, LightDirection.z]
