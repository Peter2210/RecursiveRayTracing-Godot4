extends Resource

class_name Scene_Data

#Endereço do Buffer das Esferas e sua quantidade
@export var spheres_buffer: RID
@export var spheres_number: float

#Endereço do Buffer dos Triagulos e sua quantidade
@export var triangle_buffer: RID

#Endereço do Buffer das Mesh
@export var mesh_buffer: RID
@export var mesh_number: float

#Endereço da Texture de Acumulação
@export var accu_tex: RID

# Preparo Executado
@export var ready : bool = false

# Comportamento do raio
@export var MaxBounceCount : float = 3.0
@export var NumRayPerPixel : float = 5.0

# Dados do céu
var GroundColour : Array = [0.350, 0.300, 0.350, 0.000]
var ColourHorizon : Array = [1.000, 1.000, 1.000, 0.000]
var ColourZenith : Array = [0.079, 0.365, 0.726, 0.000]
var SunLightDirection : Array
@export var SunFocus : float = 100.0
@export var SunIntensity : float = 20.0

func _reset_state():
	ready = false
