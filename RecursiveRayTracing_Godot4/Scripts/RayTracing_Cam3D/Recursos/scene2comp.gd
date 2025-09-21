extends Resource

class_name SceneData

@export_category("Identifiers")
#Endereço do Buffer das Esferas e sua quantidade
@export var spheres_buffer: RID
@export var spheres_number: int

#Endereço do Buffer dos Triagulos e sua quantidade
@export var triangle_buffer: RID

#Endereço do Buffer das Mesh
@export var mesh_buffer: RID
@export var mesh_number: int

#Endereço da Texture de Acumulação
@export var accu_tex: RID

@export_category("Main Configuration")
@export var rayTracingEnabled : bool
@export var accumulate : bool
@export var useSky : bool
@export var SunFocus : float
@export var SunIntensity : float
@export var sunColor : Color

@export var MaxBounceCount : int
@export var NumRayPerPixel : int

@export var DefocusStrength : float
@export var DivergeStrength : float
@export var FocusDistance : float

# Dados do céu
var GroundColour : Array = [0.350, 0.300, 0.350, 0.000]
var ColourHorizon : Array = [1.000, 1.000, 1.000, 0.000]
var ColourZenith : Array = [0.079, 0.365, 0.726, 0.000]
var SunLightDirection : Array
