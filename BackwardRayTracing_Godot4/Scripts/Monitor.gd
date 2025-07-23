extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#var monitor_value = Callable(self, "get_monitor_value")
	#Performance.add_custom_monitor("Raytracing", monitor_value)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	#save_to_file("Teste")
	pass
	
	
func save_to_file(content):
	var file = FileAccess.open("res://save_game.dat", FileAccess.WRITE)
	file.store_string(content)
	print(content)

func get_monitor_value():
	pass
