class_name ColorRectScripted tool extends Control
# port author: Xrayez
# license: MIT
# source: https://github.com/godotengine/godot/blob/388ebfb498/scene/gui/color_rect.cpp

export(Color) var color = Color(1, 1, 1) setget set_color

func set_color(p_color: Color):
	color = p_color
	update()

func _draw():
	draw_rect(Rect2(Vector2(), rect_size), color)
