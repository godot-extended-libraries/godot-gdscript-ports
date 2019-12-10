class_name LabelScripted tool extends Control
#
# port author: Xrayez
# license: MIT
# source: https://github.com/godotengine/godot/blob/2b824b4e4/scene/gui/label.cpp
# notes:
#     - font color is black by default without access to Godot's theme (?),
#       color property is provided to manually override this;
#     - CharType (absent in GDScript) is replaced by ord() and char() conversions;
# todo:
#     - the way string length is calculated seems to be different from C++ version,
#       which might be related to cowdata size over string length differences
#       (grep for "diff" comments here to see actual workarounds).
#
enum Align {
	ALIGN_LEFT,
	ALIGN_CENTER,
	ALIGN_RIGHT,
	ALIGN_FILL
};
enum VAlign {
	ALIGN_FILL,
	VALIGN_CENTER,
	VALIGN_BOTTOM,
	VALIGN_FILL
};
export(String, MULTILINE) var text := String() setget set_text
export(Color) var color := Color(1, 1, 1, 1) setget set_color
export(Align) var align = Align.ALIGN_LEFT setget set_align
export(VAlign) var valign = VAlign.ALIGN_FILL setget set_valign
export(bool) var autowrap = false setget set_autowrap
export(bool) var clip = false setget set_clip_text
export(bool) var uppercase = false setget set_uppercase
export(int) var visible_chars = -1 setget set_visible_characters
export(float) var percent_visible = 1.0 setget set_percent_visible
export(int) var lines_skipped = 0 setget set_lines_skipped
export(int) var max_lines_visible = -1 setget set_max_lines_visible

var line_count = 0 setget , get_line_count
var total_char_cache = 0
var word_cache = null
var word_cache_dirty = true
var xl_text = ""
var minsize = Vector2()


class WordCache extends Object:
	enum {
		CHAR_NEWLINE = -1,
		CHAR_WRAPLINE = -2
	};
	var char_pos = 0 # if -1, then newline
	var word_len = 0
	var pixel_width = 0
	var space_count = 0
	var next: WordCache = null


func _init():
	set_v_size_flags(0)
	set_mouse_filter(MOUSE_FILTER_IGNORE)
	set_v_size_flags(SIZE_SHRINK_CENTER)


func set_autowrap(p_autowrap):
	autowrap = p_autowrap
	word_cache_dirty = true
	update()


func set_uppercase(p_uppercase):
	uppercase = p_uppercase
	word_cache_dirty = true
	update()


func get_line_height():
	return get_font("font").get_height()


func _notification(p_what: int):
	if p_what == NOTIFICATION_TRANSLATION_CHANGED:
		var new_text = tr(text)
		if new_text == xl_text:
			return # nothing new
		xl_text = new_text

		regenerate_word_cache()
		update()

	if p_what == NOTIFICATION_DRAW:
		if clip:
			VisualServer.canvas_item_set_clip(get_canvas_item(), true)

		if word_cache_dirty:
			regenerate_word_cache()

		var ci = get_canvas_item()
		var size = get_size()
		var style = get_stylebox("normal")
		var font = get_font("font")
		var font_color = get_color("font_color") if color.a <= 0.0 else color
		var font_color_shadow = get_color("font_color_shadow")
		var use_outline = get_constant("shadow_as_outline")
		var shadow_ofs = Vector2(get_constant("shadow_offset_x"), get_constant("shadow_offset_y"))
		var line_spacing = get_constant("line_spacing")
		var font_outline_modulate = get_color("font_outline_modulate")

		style.draw(ci, Rect2(Vector2(0, 0), get_size()))

		VisualServer.canvas_item_set_distance_field_mode(get_canvas_item(), is_instance_valid(font) and font.is_distance_field_hint())

		var font_h = font.get_height() + line_spacing

		var lines_visible = (size.y + line_spacing) / font_h

		# ceiling to ensure autowrapping does not cut text
		var space_w = ceil(font.get_char_size(ord(' ')).x)
		var chars_total = 0

		var vbegin = 0
		var vsep = 0

		if lines_visible > line_count:
			lines_visible = line_count

		if max_lines_visible >= 0 and lines_visible > max_lines_visible:
			lines_visible = max_lines_visible

		if lines_visible > 0:
			match(valign):
				VAlign.ALIGN_FILL:
					pass
				VAlign.VALIGN_CENTER:
					vbegin = (size.y - (lines_visible * font_h - line_spacing)) / 2
					vsep = 0
				VAlign.VALIGN_BOTTOM:
					vbegin = size.y - (lines_visible * font_h - line_spacing)
					vsep = 0
				VAlign.VALIGN_FILL:
					vbegin = 0
					if lines_visible > 1:
						vsep = (size.y - (lines_visible * font_h - line_spacing)) / (lines_visible - 1)
					else:
						vsep = 0

		var wc = word_cache
		if not wc:
			return

		var line = 0
		var line_to = lines_skipped + (lines_visible if lines_visible > 0 else 1)
		var drawer = FontDrawer.new(font, font_outline_modulate)
		while wc:
			# handle lines not meant to be drawn quickly
			if line >= line_to:
				break
			if line < lines_skipped:
				while wc and wc.char_pos >= 0:
					wc = wc.next
				if wc:
					wc = wc.next
				line += 1
				continue

			# handle lines normally
			if wc.char_pos < 0:
				# empty line
				wc = wc.next
				line += 1
				continue

			var from = wc
			var to = wc

			var taken = 0
			var spaces = 0
			while to and to.char_pos >= 0:
				taken += to.pixel_width
				if to != from and to.space_count:
					spaces += to.space_count
				to = to.next

			var can_fill = to and to.char_pos == WordCache.CHAR_WRAPLINE
			var x_ofs = 0.0

			match(align):
				Align.ALIGN_FILL:
					x_ofs = style.get_offset().x
				Align.ALIGN_LEFT:
					x_ofs = style.get_offset().x
				Align.ALIGN_CENTER:
					x_ofs = int(size.x - (taken + spaces * space_w)) / 2
				Align.ALIGN_RIGHT:
					x_ofs = int(size.x - style.get_margin(MARGIN_RIGHT) - (taken + spaces * space_w))

			var y_ofs = style.get_offset().y
			y_ofs += (line - lines_skipped) * font_h + font.get_ascent()
			y_ofs += vbegin + line * vsep

			while from != to:
				# draw a word
				var pos = from.char_pos
				if from.char_pos < 0:
					assert(false) # bug
					return

				if from.space_count:
					# spacing
					x_ofs += space_w * from.space_count
					if can_fill and align == Align.ALIGN_FILL and spaces:
						x_ofs += int((size.x - (taken + space_w * spaces)) / spaces)

				if font_color_shadow.a > 0:
					var chars_total_shadow = chars_total #save chars drawn
					var x_ofs_shadow = x_ofs

					for i in from.word_len:
						if visible_chars < 0 || chars_total_shadow < visible_chars:
							var c = ord(xl_text[i + pos])
							var n = ord(xl_text[i + pos + 1]) if i < from.word_len - 1 else 0 # diff
							if uppercase:
								c = ord(char(c).to_upper())
								n = ord(char(n).to_upper()) if i < from.word_len - 1 else 0 # diff

							var move = drawer.draw_char(ci, Vector2(x_ofs_shadow, y_ofs) + shadow_ofs, c, n, font_color_shadow)
							if use_outline:
								drawer.draw_char(ci, Vector2(x_ofs_shadow, y_ofs) + Vector2(-shadow_ofs.x, shadow_ofs.y), c, n, font_color_shadow)
								drawer.draw_char(ci, Vector2(x_ofs_shadow, y_ofs) + Vector2(shadow_ofs.x, -shadow_ofs.y), c, n, font_color_shadow)
								drawer.draw_char(ci, Vector2(x_ofs_shadow, y_ofs) + Vector2(-shadow_ofs.x, -shadow_ofs.y), c, n, font_color_shadow)

							x_ofs_shadow += move
							chars_total_shadow += 1

				for i in from.word_len:
					if visible_chars < 0 || chars_total < visible_chars:
						var c = ord(xl_text[i + pos])
						var n = ord(xl_text[i + pos + 1]) if i < from.word_len - 1 else 0 # diff
						if uppercase:
							c = ord(char(c).to_upper())
							n = ord(char(n).to_upper()) if i < from.word_len - 1 else 0 # diff
						x_ofs += drawer.draw_char(ci, Vector2(x_ofs, y_ofs), c, n, font_color)
						chars_total += 1
				from = from.next

			wc = to.next if to else 0
			line += 1

	if p_what == NOTIFICATION_THEME_CHANGED:
		word_cache_dirty = true
		update()

	if p_what == NOTIFICATION_RESIZED:
		word_cache_dirty = true


func get_minimum_size():
	var min_style = get_stylebox("normal").get_minimum_size()

	# don't want to mutable everything
	if word_cache_dirty:
		regenerate_word_cache()

	if autowrap:
		return Vector2(1, 1 if clip else minsize.y) + min_style
	else:
		var ms = minsize
		if clip:
			ms.x = 1
		return ms + min_style


func get_longest_line_width():
	var font = get_font("font")
	var max_line_width = 0
	var line_width = 0

	for i in xl_text.length():
		var current = ord(xl_text[i])
		if uppercase:
			current = ord(char(current).to_upper())

		if current < 32:
			if current == ord('\n'):
				if line_width > max_line_width:
					max_line_width = line_width
				line_width = 0
		else:
			# ceiling to ensure autowrapping does not cut text
			var next = ord(xl_text[i + 1]) if i < xl_text.length() - 1 else 0 # diff
			var char_width = ceil(font.get_char_size(current, next).x)
			line_width += char_width

	if line_width > max_line_width:
		max_line_width = line_width

	return max_line_width


func get_line_count():
	if not is_inside_tree():
		return 1
	if word_cache_dirty:
		regenerate_word_cache()

	return line_count


func get_visible_line_count():
	var line_spacing = get_constant("line_spacing")
	var font_h = get_font("font").get_height() + line_spacing
	var lines_visible = (get_size().y - get_stylebox("normal").get_minimum_size().y + line_spacing) / font_h

	if lines_visible > line_count:
		lines_visible = line_count

	if max_lines_visible >= 0 and lines_visible > max_lines_visible:
		lines_visible = max_lines_visible

	return lines_visible


func regenerate_word_cache():
	while word_cache:
		var current = word_cache
		word_cache = current.next
		current.free()

	var width = 0
	if autowrap:
		var style = get_stylebox("normal")
		width = max(get_size().x, get_custom_minimum_size().x) - style.get_minimum_size().x
	else:
		width = get_longest_line_width()

	var font = get_font("font")

	var current_word_size = 0
	var word_pos = 0
	var line_width = 0
	var space_count = 0
	# ceiling to ensure autowrapping does not cut text
	var space_width = ceil(font.get_char_size(ord(' ')).x)
	var line_spacing = get_constant("line_spacing")
	line_count = 1
	total_char_cache = 0

	var last = WordCache.new()

	for i in xl_text.length() + 1:
		var current = ord(xl_text[i]) if i < xl_text.length() else ord(' ') # always a space at the end, so the algo works
		if uppercase:
			current = ord(char(current).to_upper())
		# ranges taken from http:#www.unicodemap.org/
		# if your language is not well supported, consider helping improve:
		# the unicode support in Godot.
		var separatable = (current >= 0x2E08 and current <= 0xFAFF) || (current >= 0xFE30 and current <= 0xFE4F)
		#current>=33 and (current < 65||current >90) and (current<97||current>122) and (current<48||current>57)
		var insert_newline = false
		var char_width = 0

		if current < 33:
			if current_word_size > 0:
				var wc = WordCache.new()
				if word_cache:
					last.next = wc
				else:
					word_cache = wc

				last = wc

				wc.pixel_width = current_word_size
				wc.char_pos = word_pos
				wc.word_len = i - word_pos
				wc.space_count = space_count
				current_word_size = 0
				space_count = 0

			if current == ord('\n'):
				insert_newline = true
			elif current != ord(' '):
				total_char_cache += 1

			if i < xl_text.length() and xl_text[i] == ' ':
				if line_width > 0 || last == null || last.char_pos != WordCache.CHAR_WRAPLINE:
					space_count += 1
					line_width += space_width
				else:
					space_count = 0
		else:
			# latin characters
			if current_word_size == 0:
				word_pos = i

			# ceiling to ensure autowrapping does not cut text
			var next = ord(xl_text[i + 1]) if i < xl_text.length() - 1 else 0
			char_width = ceil(font.get_char_size(current, next).x)
			current_word_size += char_width
			line_width += char_width
			total_char_cache += 1

			# allow autowrap to cut words when they exceed line width
			if autowrap and (current_word_size > width):
				separatable = true

		if (autowrap and (line_width >= width) and ((last and last.char_pos >= 0) || separatable)) || insert_newline:
			if separatable:
				if current_word_size > 0:
					var wc = WordCache.new()
					if word_cache:
						last.next = wc
					else:
						word_cache = wc

					last = wc

					wc.pixel_width = current_word_size - char_width
					wc.char_pos = word_pos
					wc.word_len = i - word_pos
					wc.space_count = space_count
					current_word_size = char_width
					word_pos = i

			var wc = WordCache.new()
			if word_cache:
				last.next = wc
			else:
				word_cache = wc

			last = wc

			wc.pixel_width = 0
			wc.char_pos = WordCache.CHAR_NEWLINE if insert_newline else WordCache.CHAR_WRAPLINE

			line_width = current_word_size
			line_count += 1
			space_count = 0

	if not autowrap:
		minsize.x = width

	if max_lines_visible > 0 and line_count > max_lines_visible:
		minsize.y = (font.get_height() * max_lines_visible) + (line_spacing * (max_lines_visible - 1))
	else:
		minsize.y = (font.get_height() * line_count) + (line_spacing * (line_count - 1))

	if not autowrap || not clip:
		# helps speed up some labels that may change a lot, as no resizing is requested. Do not change.
		minimum_size_changed()

	word_cache_dirty = false


func set_align(p_align):
	align = p_align
	update()


func set_valign(p_align):
	valign = p_align
	update()


func set_text(p_string):
	if text == p_string:
		return
	text = p_string
	xl_text = tr(p_string)
	word_cache_dirty = true
	if percent_visible < 1:
		visible_chars = get_total_character_count() * percent_visible
	update()


func set_color(p_color):
	color = p_color
	update()


func set_clip_text(p_clip: bool):
	clip = p_clip
	update()
	minimum_size_changed()


func set_visible_characters(p_amount: int):
	visible_chars = p_amount
	if get_total_character_count() > 0:
		percent_visible = float(p_amount) / float(total_char_cache)

#	_change_notify("percent_visible")
	update()


func set_percent_visible(p_percent: float):
	if p_percent < 0 || p_percent >= 1:
		visible_chars = -1
		percent_visible = 1
	else:
		visible_chars = get_total_character_count() * p_percent
		percent_visible = p_percent

#	_change_notify("visible_chars")
	update()


func set_lines_skipped(p_lines: int):
	lines_skipped = p_lines
	update()


func set_max_lines_visible(p_lines: int):
	max_lines_visible = p_lines
	update()


func get_total_character_count():
	if word_cache_dirty:
		regenerate_word_cache()

	return total_char_cache

# Porting note: FontDrawer class dependency ported from scene/resources/font.h
# Helper class to that draws outlines immediately and draws characters in its destructor.
class FontDrawer:
	var font: Font
	var outline_color: Color
	var has_outline: bool

	class PendingDraw:
		var canvas_item: RID
		var pos := Vector2()
		var chr := 0
		var next := 0
		var modulate := Color.white

		func _init(p_canvas_item: RID, p_pos: Vector2, p_chr: int, p_next: int, p_modulate: Color):
			canvas_item = p_canvas_item
			pos = p_pos
			chr = p_chr
			next = p_next
			modulate = p_modulate

	var pending_draws = []

	func _init(p_font, p_outline_color):
		font = p_font
		outline_color = p_outline_color
		has_outline = p_font.has_outline()

	func draw_char(p_canvas_item: RID, p_pos: Vector2, p_char: int, p_next: int = 0, p_modulate = Color(1, 1, 1)):
		if has_outline:
			var draw = PendingDraw.new(p_canvas_item, p_pos, p_char, p_next, p_modulate)
			pending_draws.push_back(draw)
		return font.draw_char(p_canvas_item, p_pos, p_char, p_next, outline_color if has_outline else p_modulate, has_outline)

	func _notification(p_what):
		if p_what == NOTIFICATION_PREDELETE:
			for draw in pending_draws:
				var _move = font.draw_char(draw.canvas_item, draw.pos, draw.chr, draw.next, draw.modulate, false)
