extends Camera3D

@onready var gerenciador: Node = $Gerenciador

@export_category("Main Configuration")
@export_enum("None", "RayTracing", "Depth") var Visual : int

@export_group("Ray Tracing")
@export var MaxBounceCount : int = 3
@export var NumRayPerPixel : int = 3
@export var accumulate : bool = false
@export var useSky : bool = false

@export_subgroup("Environment")
@export var sunFocus : float = 500
@export var sunIntensity : float = 10
@export var sunColor : Color = Color.WHITE

@export_subgroup("Blur")
@export var DefocusStrength : float = 0.0
@export var DivergeStrength : float = 0.0
@export var FocusDistance : float = 1.0

@export_subgroup("References")
@export_file var RayTracingCompositor : String = "uid://bgwewl00egrjx"
@export_file var RayTracingShader : String = "uid://b512hio4r8md2"

@export_group("Depth")
@export var distance : float = 50.0

@export_subgroup("References")
@export_file var DepthCompositor : String = "uid://bs0fxr8flgjeq"
@export_file var DepthShader : String = "uid://c0eow6ndqy5ci"

@export_category("Camera Moviment")
@export var mouse_sensitivity : float = 1.0
@export var move_speed : float = 0.1

func _input(event):
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("RMB"):
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			rotate_object_local(Vector3(1.0, 0.0, 0.0), deg_to_rad(event.relative.y * mouse_sensitivity))

func _ready() -> void:
	match Visual:
		1:
			gerenciador.initialize_ray_tracing(
				accumulate,
				useSky,
				sunFocus,
				sunIntensity,
				sunColor,
				MaxBounceCount,
				NumRayPerPixel,
				DefocusStrength,
				DivergeStrength,
				FocusDistance
			)
			compositor.compositor_effects.front().enabled = true
		2:
			gerenciador.initialize_depth_view( distance )
			compositor.compositor_effects[1].enabled = true
			
func _process(_delta):
	if Input.is_action_pressed("RMB"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_move()

func _move():
	var input_vector := Vector3.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector.y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	
	var displacement := Vector3.ZERO
	displacement = global_transform.basis.z * move_speed * input_vector.z
	global_transform.origin += displacement
	
	displacement = global_transform.basis.x * move_speed * input_vector.x
	global_transform.origin += displacement
	
	displacement = global_transform.basis.y * move_speed * input_vector.y
	global_transform.origin -= displacement
