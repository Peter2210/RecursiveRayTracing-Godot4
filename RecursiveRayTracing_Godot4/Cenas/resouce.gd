extends Node3D

func _ready() -> void:
	## Criar custom resource
	var temp = load("res://Scripts/RayTracing_Cam3D/Recursos/scene2comp.gd")
	var comp = temp.new()
	
	## Cria uma instância da resource customizada
	#var comp = SceneData.new()
	
	# Caminho onde salvar o recurso
	var path = "res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres"
	
	# Salva o recurso no disco
	var err = ResourceSaver.save(comp, path)
	if err != OK:
		push_error("Falha ao salvar o resource: %s" % err)
	else:
		print("Resource salvo com sucesso em: %s" % path)
