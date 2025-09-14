extends Node

@export var sample_interval := 0.1  # seconds
@export var autosave_interval := 5.0  # seconds
@export var screenshot_interval := 10.0  # seconds
@export var max_duration_minutes := 2.0  # minutes
@export var output_file : String
@export var screenshot_folder : String

var _time_passed := 0.0
var _sample_timer := 0.0
var _autosave_timer := 0.0
var _screenshot_timer := 0.0
var _csv_lines := []
var _max_duration_seconds := 0.0
var _has_stopped := false

func _ready():
	# Calculate max time in seconds
	_max_duration_seconds = max_duration_minutes * 60.0

	# CSV Header matching Unity
	_csv_lines.append("Time;FPS;ProcessTime(ms);PhysicsTime(ms);Memory_Used(MB);DrawCalls;ObjectCount")

	_take_screenshot("screenshot_00.png")


func _process(delta):
	if _has_stopped:
		return

	_time_passed += delta
	_sample_timer += delta
	_autosave_timer += delta
	_screenshot_timer += delta

	if _sample_timer >= sample_interval:
		_sample_timer = 0.0
		_collect_sample()

	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		_save_csv()

	if _screenshot_timer >= screenshot_interval:
		_screenshot_timer = 0.0
		_take_screenshot("screenshot_%.2f.png" % _time_passed)

	# Manual screenshot (press P)
	if Input.is_action_just_pressed("ui_accept"):
		_take_screenshot("manual_screenshot_%.2f.png" % _time_passed)

	# Stop after reaching max time
	if _time_passed >= _max_duration_seconds:
		_stop_profiling()


func _stop_profiling():
	_has_stopped = true
	_save_csv()
	_take_screenshot("screenshot_final.png")
	# Optionally exit game (uncomment if needed)
	# get_tree().quit()


func _collect_sample():
	var time_str = "%.2f" % _time_passed
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)

	var memory_mb = memory_bytes / (1024.0 * 1024.0)

	var line = "%s;%d;%.3f;%.3f;%.2f;%d;%d" % [
		time_str, fps, process_time, physics_time, memory_mb, draw_calls, object_count
	]
	_csv_lines.append(line)


func _save_csv():
	var file = FileAccess.open(output_file, FileAccess.WRITE)
	for line in _csv_lines:
		file.store_line(line)
	file.close()

func _take_screenshot(filename: String):
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var full_path := screenshot_folder.path_join(filename)
	image.save_png(full_path)
