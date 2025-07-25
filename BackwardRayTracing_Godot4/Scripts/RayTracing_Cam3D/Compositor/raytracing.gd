class_name raytracing extends CompositorEffect

## Definição do Shader
var rd : RenderingDevice
var shader : RID
var pipeline : RID

## Acesso aos Recursos
var comp := load("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

## Dados dos Recursos
var accu_tex : RID = comp.accu_tex
var spheres_buffer : RID = comp.spheres_buffer
var triangle_buffer : RID = comp.triangle_buffer
var mesh_buffer : RID = comp.mesh_buffer

# Buffers a serem criados


## Dados Auxiliares
var frame : float = 0.0
@export var Acumular : bool

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
	
	if comp.ready:
		##Acesso aos buffers do Renderizador
		var scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
		if not scene_buffers: return

		##Acesso as informações da Camera
		var scene_proj : Projection = render_data.get_render_scene_data().get_cam_projection()
		if not scene_proj: return
		
		#Obter as dimensões do buffer (resolução tela XY)
		var size : Vector2i = scene_buffers.get_internal_size()
		if size.x == 0 or size.y == 0: return
		
		var x_group : int = int(ceil(size.x / 8.0))
		var y_group : int = int(ceil(size.y / 8.0))
		
		#Acesso à Origem e Matrix de Transformação da Camera3D
		var origin : Vector3
		var scene_transf : PackedFloat32Array
		var temp_transf : Transform3D = render_data.get_render_scene_data().get_cam_transform()
		origin = temp_transf.origin
		scene_transf = matriz_array(temp_transf)
		
		#Informações de Visualização da Camera3D
		var aspect : float = scene_proj.get_aspect()
		var near : float = scene_proj.get_z_near()
		var fov_y : float = Projection.get_fovy(scene_proj.get_fov(), 1/aspect)
		var altura_plano : float = near * tan(deg_to_rad(fov_y * 0.5)) * 2.0
		var largura_plano : float = altura_plano * aspect
		
		var origem : PackedFloat32Array = PackedFloat32Array([origin.x, origin.y, origin.z, 1.0])
		
		var viewparams : PackedFloat32Array = PackedFloat32Array([largura_plano, altura_plano, near, 1.0])
		
		##Criação dos Buffers
		#Buffer de Numeros Constantes
		var push_constant : PackedByteArray = PackedFloat32Array([size.x, size.y]).to_byte_array()
		push_constant.append_array(PackedFloat32Array([frame]).to_byte_array())
		push_constant.append_array(PackedFloat32Array([comp.MaxBounceCount]).to_byte_array())
		push_constant.append_array(PackedFloat32Array([comp.NumRayPerPixel]).to_byte_array())
		push_constant.append_array(PackedFloat32Array([comp.mesh_number]).to_byte_array())
		push_constant.resize(32)
		
		# Buffer da Textura de Acumulação
		var accumulation_image_uniform := RDUniform.new()
		accumulation_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		accumulation_image_uniform.binding = 1
		accumulation_image_uniform.add_id(accu_tex)
		
		#Buffer da Camera
		var cam_data : PackedByteArray
		cam_data.append_array(scene_transf.to_byte_array())
		cam_data.append_array(origem.to_byte_array())
		cam_data.append_array(viewparams.to_byte_array())
		var cam_buffer : RID = rd.storage_buffer_create(cam_data.size(), cam_data)
		
		var cam_uniform := RDUniform.new()
		cam_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		cam_uniform.binding = 2
		cam_uniform.add_id(cam_buffer)
		
		#Variáveis do mundo
		var world_data : PackedByteArray
		world_data.append_array(PackedFloat32Array([comp.spheres_number]).to_byte_array())
		var world_buffer : RID = rd.storage_buffer_create(world_data.size(), world_data)
		
		var world_uniform := RDUniform.new()
		world_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		world_uniform.binding = 3
		world_uniform.add_id(world_buffer)
		
		# Buffer das Esferas
		var spheres_uniform := RDUniform.new()
		spheres_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		spheres_uniform.binding = 4
		spheres_uniform.add_id(spheres_buffer)
		
		#Buffer dos Triângulos
		var triangle_uniform := RDUniform.new()
		triangle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		triangle_uniform.binding = 5
		triangle_uniform.add_id(triangle_buffer)
		
		#Buffer das Mesh
		var mesh_uniform := RDUniform.new()
		mesh_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		mesh_uniform.binding = 6
		mesh_uniform.add_id(mesh_buffer)
		
		#Buffer do céu (Opcional)
		var sky_data : PackedByteArray
		sky_data.append_array(PackedFloat32Array(comp.GroundColour).to_byte_array())
		sky_data.append_array(PackedFloat32Array(comp.ColourHorizon).to_byte_array())
		sky_data.append_array(PackedFloat32Array(comp.ColourZenith).to_byte_array())
		sky_data.append_array(PackedFloat32Array(comp.SunLightDirection).to_byte_array())
		sky_data.append_array(PackedFloat32Array([comp.SunFocus]).to_byte_array())
		sky_data.append_array(PackedFloat32Array([comp.SunIntensity]).to_byte_array())
		
		var sky_buffer : RID = rd.storage_buffer_create(sky_data.size(), sky_data)
		
		var sky_uniform := RDUniform.new()
		sky_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		sky_uniform.binding = 7
		sky_uniform.add_id(sky_buffer)
		
		# Execução de Compute shader em View ( Camera3D = 1 | CameraVR = 2 )
		# Buffer da Textura da Tela
		var screen_tex : RID = scene_buffers.get_color_layer(0)
		var image_uniform : RDUniform = RDUniform.new()
		image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		image_uniform.binding = 0
		image_uniform.add_id(screen_tex)
		
		# Conecta Buffers criados ao Shader
		var bindings = [
			image_uniform,
			accumulation_image_uniform,
			cam_uniform,
			world_uniform,
			spheres_uniform,
			triangle_uniform,
			mesh_uniform,
			sky_uniform,
		]
		var uniform_set = rd.uniform_set_create(bindings, shader, 0)
		
		var compute_list : int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
		rd.compute_list_dispatch(compute_list, x_group, y_group, 1)
		rd.compute_list_end()
		frame+=1
	else:
		comp = load("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

#Inicializa Shader
func initialize_compute_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd: return
	
	#Carregar Compute Shader criado
	var glsl_file : RDShaderFile = load("res://Scripts/RayTracing_Cam3D/Compositor/raytracer.glsl")
	shader = rd.shader_create_from_spirv(glsl_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)

##Funções Auxiliares
#Transformar Matriz em Lista
func matriz_array(mat : Transform3D) -> PackedFloat32Array:
	var base := mat.basis
	var origin := mat.origin
	return PackedFloat32Array([
		base.x.x, base.x.y, base.x.z, 0.0,
		base.y.x, base.y.y, base.y.z, 0.0,
		base.z.x, base.z.y, base.z.z, 0.0,
		origin.x, origin.y, origin.z, 1.0
	])
