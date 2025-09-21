extends Node

@onready var tree : Window = get_tree().root

var rd : RenderingDevice = RenderingServer.get_rendering_device()
var comp : Resource = load("res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

@onready var esferas: Node = $Esferas
@onready var triangulos: Node = $Triangulos
@onready var ambiente: Node = $Ambiente

func initialize_from_camera(accumulate, useSky, sunFocus, sunIntensity, sunColor, max_bounce, rays_per_pixel, defocus, diverge, focus):
	comp.accumulate = accumulate
	comp.useSky = useSky
	comp.SunFocus = sunFocus
	comp.SunIntensity = sunIntensity
	comp.sunColor = sunColor
	comp.MaxBounceCount = max_bounce
	comp.NumRayPerPixel = rays_per_pixel
	comp.DefocusStrength = defocus
	comp.DivergeStrength = diverge
	comp.FocusDistance = focus
	
	set_up_shader()
	ResourceSaver.save(comp, "res://Scripts/RayTracing_Cam3D/Recursos/ray_data.tres")

func set_up_shader():
	## Cria textura de acumulação
	set_AccumulationTexture()
	
	## Procurar esferas da cena e cria buffer de dados
	esferas.set_SphereBuffer(tree, comp, rd)
	
	## Procurar malhas (!esfera) e cria buffer de dados
	triangulos.set_MeshesBuffers(tree, comp, rd)
	
	## Obtenção de dados do ambiente
	ambiente.set_Ambiente(tree, comp)

func set_AccumulationTexture():
	var format := RDTextureFormat.new()
	format.width = get_viewport().get_texture().get_width()
	format.height = get_viewport().get_texture().get_height()
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	var a_view := RDTextureView.new()

	var accumulation_texture : RID = rd.texture_create(format, a_view)
	comp.accu_tex = accumulation_texture
