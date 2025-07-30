class_name acumular extends CompositorEffect

## Definição do Shader
var rd : RenderingDevice
var shader : RID
var pipeline : RID

## Acesso aos Recursos
var comp := load("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

## Dados dos Recursos
var accu_tex : RID = comp.accu_tex

## Buffers a serem criados
var push_constant : PackedByteArray

## Uniformes a serem feitos
var accumulation_image_uniform := RDUniform.new()

## Dados Auxiliares
var frame : int = 0

func _init() -> void:
	comp._reset_state()
	RenderingServer.call_on_render_thread(initialize_compute_shader)

## Método executado a todo sinal de notificação recebido
func _notification(what: int) -> void:
	# Notificação quanto objeto estiver prestes a ser deletado
	if what == NOTIFICATION_PREDELETE and shader.is_valid():
		#Liberar recursos usados na memória (evitar memory leaks)
		#Pipeline é liberdo junto com shader
		rd.free_rid(shader)

## Definer dados para GPU a cada frame
func _render_callback(_effect_callback_type: int, render_data: RenderData) -> void:
	if not rd: return
	
	elif comp.ready:
		##Acesso aos buffers do Renderizador
		var scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
		if not scene_buffers: return
		
		#Obter as dimensões do buffer (resolução tela XY)
		var size : Vector2i = scene_buffers.get_internal_size()
		if size.x == 0 or size.y == 0: return
		
		var x_group : int = int(ceil(size.x / 16.0))
		var y_group : int = int(ceil(size.y / 16.0))

		##Criação do Buffer
		if frame == 0.0:
			# Uniforme da Textura de Acumulação
			accumulation_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			accumulation_image_uniform.binding = 1
			accumulation_image_uniform.add_id(accu_tex)
			
		#Buffer de Numeros Constantes
		push_constant = PackedFloat32Array([size.x, size.y]).to_byte_array()
		push_constant.append_array(PackedInt32Array([frame]).to_byte_array())
		push_constant.resize(16)
		
		# Execução de Compute shader em View ( Camera3D = 1 | CameraVR = 2 )
		# Uniforme da Textura da Tela
		var screen_tex : RID = scene_buffers.get_color_layer(0)
		var image_uniform : RDUniform = RDUniform.new()
		image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		image_uniform.binding = 0
		image_uniform.add_id(screen_tex)
		
		# Conecta Uniformes / Buffers criados ao Shader
		var bindings = [
			image_uniform,
			accumulation_image_uniform,
		]
		var uniform_set = rd.uniform_set_create(bindings, shader, 0)
		
		# Executa shader
		var compute_list : int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
		rd.compute_list_dispatch(compute_list, x_group, y_group, 1)
		rd.compute_list_end()
	else:
		comp = load("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")
	frame+=1

#Inicializa Shader
func initialize_compute_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd: return
	
	#Carregar Compute Shader criado
	var glsl_file : RDShaderFile = load("res://Scripts/RayTracing_Cam3D/Compositor/accumulate.glsl")
	shader = rd.shader_create_from_spirv(glsl_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
