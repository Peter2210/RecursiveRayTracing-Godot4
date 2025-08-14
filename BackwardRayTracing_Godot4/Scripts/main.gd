extends Node

@export var sample_interval := 0.1  # seconds

@export var output_file := "C:/Users/pmell/Faculdade/UNIOESTE/ProjetoTCC/BackwardRayTracing_Godot4/performance_output/performance_data.csv"

var _time_passed := 0.0
var _timer := 0.0
var _csv_lines := []
var _autosave_interval := 5.0
var _autosave_timer := 0.0


func _ready():
	# CSV Header
	_csv_lines.append("Time;FPS;ProcessTime;PhysicsTime;Memory(GiB);DrawCalls")

func _process(delta):
	_time_passed += delta
	_timer += delta
	_autosave_timer += delta

	if _timer >= sample_interval:
		_timer = 0.0
		_collect_sample()

	if _autosave_timer >= _autosave_interval:
		_autosave_timer = 0.0
		_save_csv()


func _collect_sample():
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	var memory_gb = memory_bytes / (1024.0 * 1024.0 * 1024.0)
	var time = "%.2f" % _time_passed
	
	var line = "%s;%d;%.6f;%.6f;%.3f;%d" % [
		time, fps, process_time, physics_time, memory_gb, draw_calls
	]
	_csv_lines.append(line)

func _save_csv():
	var file = FileAccess.open(output_file, FileAccess.WRITE)
	for line in _csv_lines:
		file.store_line(line)
	file.close()
