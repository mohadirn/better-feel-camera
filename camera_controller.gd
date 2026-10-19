extends Camera2D
class_name CameraController

#region Follow
@export_group("Follow")
@export var deadzone_size: float = 150.0
@export var follow_speed: float = 2.0
@export var snap_threshold: float = 30.0

var _target: Node2D
var _anchor_pos: Vector2
var _is_anchor_on_move: bool
var _is_anchoring_x: bool
#endregion

#region Look
@export_group("Look")
@export var look_ahead_distance: float = 300.0
@export var look_ahead_speed: float = 0.5
@export var look_vertical_distance: float = 300.0
@export var look_vertical_speed: float = 3.0

var _look_offset: Vector2
#endregion

#region Trauma Shake
@export_group("Trauma Shake")
@export var max_offset: Vector2 = Vector2(100.0, 70.0)
@export var max_roll_degrees: float = 15.0
@export var decay_rate: float = 3.5

var _shake_offset: Vector2 = Vector2.ZERO
var _noise := FastNoiseLite.new()
var _noise_y: float
var _trauma: float
#endregion

#region Debug
@export_group("Debug")
@export var show_debug_anchor: bool
@export var debug_anchor_color: Color = Color(1.0, 0.2, 0.2, 0.9)
@export var debug_deadzone_color: Color = Color(0.2, 0.8, 1.0, 0.3)
@export var debug_look_target_color: Color = Color.YELLOW
#endregion

func _ready() -> void:
	Global.camera = self
	
	#Follow
	if not _target and "player" in Global:
		_target = Global.player
	
	if _target:
		_anchor_pos = _target.global_position
		global_position = _anchor_pos
	
	#Shake Noise
	randomize()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	_update_anchor(delta)
	_follow()
	_update_look_offsets(delta)
	_apply_shake(delta)
	
	offset = _look_offset + _shake_offset
	
	queue_redraw()

func _update_anchor(delta: float) -> void:
	var target_pos := _target.global_position
	var distance := _anchor_pos.distance_to(target_pos)
	
	if distance > deadzone_size:
		_is_anchor_on_move = true
	elif distance <= snap_threshold:
		_is_anchor_on_move = false
	
	if _is_anchor_on_move:
		var weight := clampf(follow_speed * delta, 0.0, 1.0)
		_anchor_pos = _anchor_pos.lerp(target_pos, weight)
		_is_anchoring_x = absf(target_pos.x - _anchor_pos.x) > snap_threshold
	else:
		_is_anchoring_x = false

func _follow() -> void:
	global_position = _anchor_pos

func _update_look_offsets(delta: float) -> void:
	var target_look_x: float = 0.0
	
	if _is_anchoring_x and \
		_target is CharacterBody2D and \
		absf(_target.velocity.x) > 10.0:
		target_look_x = signf(_target.velocity.x) * look_ahead_distance
	
	var look_x_weight := clampf(look_ahead_speed * delta, 0.0, 1.0)
	_look_offset.x = lerp(_look_offset.x, target_look_x, look_x_weight)

	var axis := Input.get_axis("down", "up")
	var target_look_y: float = 0.0
	
	if axis != 0.0:
		target_look_y = -look_vertical_distance if axis > 0.0 else look_vertical_distance * 0.5
		
	var look_y_weight := clampf(look_vertical_speed * delta, 0.0, 1.0)
	_look_offset.y = lerp(_look_offset.y, target_look_y, look_y_weight)

func _apply_shake(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - decay_rate * delta)
		_noise_y += delta * 60.0
		
		var shake_power := _trauma * _trauma
		var shake_x := max_offset.x * shake_power * _noise.get_noise_2d(0.0, _noise_y)
		var shake_y := max_offset.y * shake_power * _noise.get_noise_2d(100.0, _noise_y)
		
		_shake_offset = Vector2(shake_x, shake_y)
		rotation = deg_to_rad(max_roll_degrees * shake_power * _noise.get_noise_2d(200.0, _noise_y))
	else:
		_shake_offset = Vector2.ZERO
		rotation = 0.0

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func set_target(new_target: Node2D) -> void:
	if new_target is not CharacterBody2D:
		return
		
	_target = new_target

func _draw() -> void:
	if not show_debug_anchor or not is_inside_tree():
		return
	var local_anchor: Vector2 = to_local(_anchor_pos)
	draw_arc(local_anchor, deadzone_size, 0.0, TAU, 64, debug_deadzone_color, 2.0)
	draw_circle(local_anchor, 6.0, debug_anchor_color)
	var cross_size: float = 12.0
	draw_line(local_anchor + Vector2(-cross_size, 0.0), local_anchor + Vector2(cross_size, 0.0), Color.WHITE, 2.0)
	draw_line(local_anchor + Vector2(0.0, -cross_size), local_anchor + Vector2(0.0, cross_size), Color.WHITE, 2.0)
	if is_instance_valid(_target):
		var local_target: Vector2 = to_local(_target.global_position)
		draw_dashed_line(local_anchor, local_target, Color(1.0, 1.0, 0.0, 0.6), 1.5, 6.0)
	var look_target_global := _anchor_pos + _look_offset.rotated(global_rotation)
	var local_look_target := to_local(look_target_global)
	draw_line(local_anchor, local_look_target, debug_look_target_color, 2.0)
	draw_circle(local_look_target, 7.0, debug_look_target_color)
