class_name RemoteTransform2DScripted tool extends Node2D

# port author: Xrayez
# license: MIT
# godot version: 2297186cd
# diffs: 
#     - no Transform2D.set_rotation/scale in GDScript yet, so those are replaced
#       with a more low-level Transform2D API.

export var remote_path := NodePath()
var cache = 0

export var use_global_coordinates := true
export var update_position := true setget set_update_position
export var update_scale := true setget set_update_scale
export var update_rotation := true setget set_update_rotation


func _init():
	set_notify_transform(true)


func _update_cache():
	cache = 0
	if has_node(remote_path):
		var node = get_node(remote_path)
		if not node or self == node or node.is_a_parent_of(self) or is_a_parent_of(node):
			return
		cache = node.get_instance_id()


func _update_remote():
	if not is_inside_tree():
		return
	if not cache:
		return

	var node = instance_from_id(cache)
	if not node:
		return

	if not node.is_inside_tree():
		return

	if use_global_coordinates:
		if update_position and update_rotation and update_scale:
			node.global_transform = global_transform
		else:
			var n_trans = node.global_transform
			var our_trans = global_transform
			var n_scale = node.scale

			if not update_position:
				our_trans = Transform2D(our_trans.x, our_trans.y, n_trans.origin)
			if not update_rotation:
				our_trans = Transform2D(n_trans.x, n_trans.y, our_trans.origin)

			node.global_transform = our_trans

			if update_scale:
				node.scale = global_scale
			else:
				node.scale = n_scale
	else:
		if update_position and update_rotation and update_scale:
			node.transform = transform
		else:
			var n_trans = node.transform
			var our_trans = transform
			var n_scale = node.scale

			if not update_position:
				our_trans = Transform2D(our_trans.x, our_trans.y, n_trans.origin)
			if not update_rotation:
				our_trans = Transform2D(n_trans.x, n_trans.y, our_trans.origin)

			node.transform = our_trans

			if update_scale:
				node.scale = scale
			else:
				node.scale = n_scale


func _notification(p_what):
	match p_what:
		NOTIFICATION_ENTER_TREE:
			_update_cache()

		NOTIFICATION_TRANSFORM_CHANGED:
			if not is_inside_tree():
				return
			if cache:
				_update_remote()


func set_remote_path(p_remote_path):
	remote_path = p_remote_path

	if is_inside_tree():
		_update_cache()
		_update_remote()

	update_configuration_warning()


func set_use_global_coordinates(p_enable):
	use_global_coordinates = p_enable
	_update_remote()


func set_update_position(p_update):
	update_position = p_update
	_update_remote()


func set_update_rotation(p_update):
	update_rotation = p_update
	_update_remote()


func set_update_scale(p_update):
	update_scale = p_update
	_update_remote()


func force_update_cache():
	_update_cache()


func _get_configuration_warning():
	if not has_node(remote_path) or not (get_node(remote_path) as Node2D):
		return tr("Path property must point to a valid Node2D node to work.")
	return String()
