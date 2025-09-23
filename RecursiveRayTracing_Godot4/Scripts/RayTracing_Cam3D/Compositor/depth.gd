class_name depth extends CompositorEffect

var rd : RenderingDevice
var shader : RID
var pipeline : RID

var data : Resource

var push_constant : PackedByteArray

var cam_uniform := RDUniform.new()

func _init() -> void:
	enabled = false
	RenderingServer.call_on_render_thread(initialize_compute_shader)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and shader.is_valid():
		rd.free_rid(shader)

func _render_callback(_effect_callback_type: int, render_data: RenderData) -> void:
	if not enabled: return 
	
	if !data:
		data = load("uid://btfdeyfy3a5y0")
	
	if not rd: return
	
	var scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	if not scene_buffers: return
	
	var scene_data : RenderSceneDataRD = render_data.get_render_scene_data()
	if not scene_data: return
	
	var size : Vector2i = scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return
	
	var x_group : int = int(ceil(size.x / 16.0))
	var y_group : int = int(ceil(size.y / 16.0))
	
	var inv_proj_mat : =scene_data.get_cam_projection().inverse()
	
	push_constant = PackedFloat32Array([size.x, size.y, inv_proj_mat[2].w, inv_proj_mat[3].w, data.Distance]).to_byte_array()
	push_constant.resize(32)
	
	var screen_tex : RID = scene_buffers.get_color_layer(0)
	var image_uniform : RDUniform = RDUniform.new()
	image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image_uniform.binding = 0
	image_uniform.add_id(screen_tex)
	
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE

	var sampler := rd.sampler_create(sampler_state)
	
	var depth_tex : RID = scene_buffers.get_depth_layer(0)
	var depth_uniform := RDUniform.new()
	depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth_uniform.binding = 1
	depth_uniform.add_id(sampler)
	depth_uniform.add_id(depth_tex)
	
	var bindings = [
		image_uniform,
		depth_uniform,
	]
	
	var uniform_set = rd.uniform_set_create(bindings, shader, 0)
	
	# Executa shader
	var compute_list : int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	rd.compute_list_dispatch(compute_list, x_group, y_group, 1)
	rd.compute_list_end()
	
func initialize_compute_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd: return
	
	#Carregar Compute Shader criado
	var glsl_file : RDShaderFile = load("uid://c0eow6ndqy5ci")
	shader = rd.shader_create_from_spirv(glsl_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
