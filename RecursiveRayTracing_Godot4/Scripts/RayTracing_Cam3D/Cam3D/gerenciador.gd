extends Node

@onready var tree : Window = get_tree().root

var rd : RenderingDevice = RenderingServer.get_rendering_device()
var data : Resource = load("uid://btfdeyfy3a5y0")

@onready var esferas: Node = $Esferas
@onready var triangulos: Node = $Triangulos
@onready var ambiente: Node = $Ambiente

func initialize_ray_tracing(accumulate, useSky, sunFocus, sunIntensity, sunColor, max_bounce, rays_per_pixel, defocus, diverge, focus):
	data.accumulate = accumulate
	data.useSky = useSky
	data.SunFocus = sunFocus
	data.SunIntensity = sunIntensity
	data.sunColor = sunColor
	data.MaxBounceCount = max_bounce
	data.NumRayPerPixel = rays_per_pixel
	data.DefocusStrength = defocus
	data.DivergeStrength = diverge
	data.FocusDistance = focus
	
	set_up_shader()
	ResourceSaver.save(data, "uid://btfdeyfy3a5y0")

func set_up_shader():
	## Cria textura de acumulação
	set_AccumulationTexture()
	
	## Procurar esferas da cena e cria buffer de dados
	esferas.set_SphereBuffer(tree, data, rd)
	
	## Procurar malhas (!esfera) e cria buffer de dados
	triangulos.set_MeshesBuffers(tree, data, rd)
	
	## Obtenção de dados do ambiente
	ambiente.set_Ambiente(tree, data)

func set_AccumulationTexture():
	var format := RDTextureFormat.new()
	format.width = get_viewport().get_texture().get_width()
	format.height = get_viewport().get_texture().get_height()
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	var a_view := RDTextureView.new()

	var accumulation_texture : RID = rd.texture_create(format, a_view)
	data.accu_tex = accumulation_texture

func initialize_depth_view( distance ):
	data.Distance = distance
	ResourceSaver.save(data, "uid://btfdeyfy3a5y0")
