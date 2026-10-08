class_name BWUI
extends RefCounted

# The screen components. Palette and painting live in BWKit because GDScript inner
# classes cannot reach their outer class's static functions.

const INK = BWKit.INK
const MUTED = BWKit.MUTED
const DIM = BWKit.DIM
const BLOOD = BWKit.BLOOD
const EMBER = BWKit.EMBER
const GOLD = BWKit.GOLD
const IRON = BWKit.IRON
const VOID = BWKit.VOID
const PANEL = BWKit.PANEL

# ------------------------------------------------------------------- components

# The pointed banner the mockups use for every committing action.
class Banner extends Control:
	signal pressed

	var text = ""
	var accent = BWKit.EMBER
	var font_size = 17
	var tracking = 3.0
	var ornaments = true
	var hovered = false
	var held = false
	var muted = false

	func _init(label: String = "", minimum: Vector2 = Vector2(210, 46)):
		text = label
		custom_minimum_size = minimum
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; held = false; queue_redraw())

	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			held = event.pressed
			queue_redraw()
			if not event.pressed and hovered:
				pressed.emit()
		elif event.is_action_pressed("ui_accept"):
			pressed.emit()

	func _shape() -> PackedVector2Array:
		var h = size.y
		var w = size.x
		var notch = h * 0.5
		return PackedVector2Array([Vector2(0, h * 0.5), Vector2(notch, 0), Vector2(w - notch, 0),
			Vector2(w, h * 0.5), Vector2(w - notch, h), Vector2(notch, h)])

	func _draw():
		var shape = _shape()
		var lit = hovered or has_focus()
		var base = Color(0.10, 0.045, 0.05, 0.92) if not muted else Color(0.07, 0.055, 0.055, 0.85)
		if held:
			base = Color(0.20, 0.06, 0.07, 0.95)
		elif lit and not muted:
			base = Color(0.17, 0.05, 0.06, 0.95)
		draw_colored_polygon(shape, base)
		var edge = accent if lit else Color(accent, 0.55)
		if muted:
			edge = Color(BWKit.IRON, 0.9) if not lit else Color(BWKit.GOLD, 0.7)
		var outline = shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, edge, 1.0, true)
		# A second keyline hugging the lower half reads as the bevel in the mockups.
		draw_polyline(PackedVector2Array([Vector2(size.y * 0.5 + 3, size.y - 3), Vector2(size.x - size.y * 0.5 - 3, size.y - 3)]), Color(edge, edge.a * 0.5), 1.0, true)
		if ornaments:
			for x in [-1.0, size.x + 1.0]:
				BWKit.paint_diamond(self, Vector2(x, size.y * 0.5), 5.0, Color(edge, 0.8))
		var font = BWKit.title_font()
		var width = BWKit.tracked_width(font, text, font_size, tracking)
		var baseline = size.y * 0.5 + font.get_ascent(font_size) * 0.5 - 1.0
		var ink = BWKit.INK if not muted else BWKit.DIM
		BWKit.draw_tracked(self, font, text, Vector2((size.x - width) * 0.5, baseline), font_size, ink if not lit else Color.WHITE, tracking)

# A glyph in its own framed square, used by the menu tiles and the detail panels.
class Emblem extends Control:
	var glyph_name = "rune"
	var accent = BWKit.EMBER
	var stroke = 2.0
	var framed = true
	var inset = 0.24

	func _init(name: String = "rune", box: float = 56.0, color: Color = BWKit.EMBER):
		glyph_name = name
		accent = color
		custom_minimum_size = Vector2(box, box)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var rect = Rect2(Vector2.ZERO, size)
		if framed:
			var radius = minf(size.x, size.y) * 0.5
			draw_circle(size * 0.5, radius - 1.0, Color(0.09, 0.05, 0.055, 0.95), true)
			draw_circle(size * 0.5, radius - 1.0, Color(accent, 0.75), false, 1.5, true)
			draw_circle(size * 0.5, radius - 5.0, Color(accent, 0.22), false, 1.0, true)
		var pad = minf(size.x, size.y) * inset
		BWKit.draw_glyph(self, glyph_name, rect.grow(-pad), accent, stroke)

# A framed surface other controls sit inside. Drawn rather than styleboxed so the
# corner ticks line up with the panel edge at any size.
class Frame extends Control:
	var fill = BWKit.PANEL
	var border = Color(BWKit.IRON, 0.95)
	var tick = 12.0

	func _init():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		BWKit.paint_frame(self, Rect2(Vector2.ZERO, size), fill, border, tick)

# The rule with a centred diamond that separates the mockups' headings.
class Rule extends Control:
	var accent = BWKit.BLOOD

	func _init(height: float = 18.0):
		custom_minimum_size = Vector2(0, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var y = size.y * 0.5
		var gap = 16.0
		draw_line(Vector2(0, y), Vector2(size.x * 0.5 - gap, y), Color(accent, 0.0), 1.0)
		for span in [[0.0, size.x * 0.5 - gap], [size.x * 0.5 + gap, size.x]]:
			var from = Vector2(span[0], y)
			var to = Vector2(span[1], y)
			draw_line(from, to, Color(accent, 0.55), 1.0, true)
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, y), 5.0, Color(BWKit.EMBER, 0.95))
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, y), 9.0, Color(accent, 0.6), false, 1.0)

# The currency readouts pinned to the top right of the skill tree.
class Chip extends Control:
	var glyph_name = "drop"
	var text = ""
	var accent = BWKit.EMBER

	func _init(name: String, label: String, color: Color = BWKit.EMBER):
		glyph_name = name
		text = label
		accent = color
		custom_minimum_size = Vector2(150, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		BWKit.paint_frame(self, Rect2(Vector2.ZERO, size), Color(0.07, 0.05, 0.052, 0.9), Color(BWKit.IRON, 0.9), 6.0)
		BWKit.draw_glyph(self, glyph_name, Rect2(9, size.y * 0.5 - 8, 16, 16), accent, 1.5)
		var font = BWKit.body_font()
		draw_string(font, Vector2(34, size.y * 0.5 + font.get_ascent(13) * 0.5 - 2), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 13, BWKit.INK)

# A labelled meter. The mockups read stats as bars, never as numbers alone.
class Meter extends Control:
	var label = ""
	var glyph_name = "sword"
	var ratio = 0.5
	var accent = BWKit.EMBER
	var pips = 10

	func _init(text: String, name: String, value: float, color: Color = BWKit.EMBER):
		label = text
		glyph_name = name
		ratio = clampf(value, 0.0, 1.0)
		accent = color
		custom_minimum_size = Vector2(0, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var font = BWKit.body_font()
		BWKit.draw_glyph(self, glyph_name, Rect2(0, size.y * 0.5 - 7, 14, 14), Color(BWKit.MUTED, 0.9), 1.3)
		BWKit.draw_tracked(self, font, label, Vector2(22, size.y * 0.5 + font.get_ascent(11) * 0.5 - 1), 11, BWKit.MUTED, 1.2)
		var track = Rect2(128, size.y * 0.5 - 4, maxf(40.0, size.x - 128), 8)
		var step = track.size.x / float(pips)
		var lit = int(round(ratio * pips))
		for i in pips:
			var cell = Rect2(track.position + Vector2(step * i + 1, 0), Vector2(step - 2, track.size.y))
			draw_rect(cell, Color(accent, 0.92) if i < lit else Color(0.14, 0.10, 0.10, 0.9), true)

# One node of the radial skill tree.
class SkillNode extends Control:
	signal chosen

	var glyph_name = "rune"
	var level = 0
	var state = "locked" # locked | ready | owned | maxed
	var selected = false
	var caption = ""
	var hovered = false
	var pulse = 0.0

	func _init(name: String, box: float = 56.0):
		glyph_name = name
		custom_minimum_size = Vector2(box, box + 18.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; queue_redraw())

	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			chosen.emit()

	func _accent() -> Color:
		match state:
			"locked": return Color(BWKit.IRON, 0.85)
			"ready": return BWKit.EMBER
			"maxed": return BWKit.GOLD
			_: return BWKit.BLOOD

	func _draw():
		var box = minf(size.x, size.y - 18.0)
		var center = Vector2(size.x * 0.5, box * 0.5)
		var radius = box * 0.5 - 2.0
		var accent = _accent()
		if selected or hovered:
			draw_circle(center, radius + 5.0, Color(accent, 0.18), true)
		var core = Color(0.055, 0.035, 0.04, 0.96)
		if state == "owned" or state == "maxed":
			core = Color(0.15, 0.045, 0.05, 0.96)
		draw_circle(center, radius, core, true)
		draw_circle(center, radius, accent, false, 2.0 if (selected or state != "locked") else 1.0, true)
		draw_circle(center, radius - 4.0, Color(accent, 0.25), false, 1.0, true)
		var ink = accent if state != "locked" else Color(BWKit.DIM, 0.8)
		BWKit.draw_glyph(self, glyph_name, Rect2(center - Vector2(radius, radius) * 0.55, Vector2(radius, radius) * 1.1), ink, 1.6)
		# Rank pips ride the bottom arc so the node reads at a glance.
		for i in 3:
			var angle = deg_to_rad(66.0 + 24.0 * i)
			var dot = center + Vector2(cos(angle), sin(angle)) * (radius + 5.0)
			draw_circle(dot, 2.4, Color(BWKit.GOLD, 0.95) if i < level else Color(BWKit.IRON, 0.9), true)
		if not caption.is_empty():
			var font = BWKit.body_font()
			var width = BWKit.tracked_width(font, caption, 10, 1.0)
			BWKit.draw_tracked(self, font, caption, Vector2((size.x - width) * 0.5, size.y - 3.0), 10,
				BWKit.INK if state != "locked" else BWKit.DIM, 1.0)

# The wires between tree nodes, painted under the node layer.
class Wires extends Control:
	var links: Array = [] # [[Vector2 from, Vector2 to, bool live]]

	func _init():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		for link in links:
			var from = Vector2(link[0])
			var to = Vector2(link[1])
			var live = bool(link[2])
			var color = Color(BWKit.EMBER, 0.85) if live else Color(BWKit.BLOOD, 0.28)
			draw_line(from, to, color, 1.6 if live else 1.0, true)
			BWKit.paint_diamond(self, from.lerp(to, 0.5), 3.5 if live else 2.5, color)

# The origin orb anchoring the tree.
class Orb extends Control:
	var caption = "BLOODWAKE\nORIGIN"
	var phase = 0.0

	func _init(box: float = 128.0):
		custom_minimum_size = Vector2(box, box)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta):
		phase += delta
		queue_redraw()

	func _draw():
		var center = size * 0.5
		var radius = minf(size.x, size.y) * 0.5 - 4.0
		var beat = 0.5 + 0.5 * sin(phase * 1.6)
		draw_circle(center, radius + 4.0, Color(BWKit.BLOOD, 0.10 + 0.08 * beat), true)
		draw_circle(center, radius, Color(0.06, 0.02, 0.025, 0.98), true)
		draw_circle(center, radius * 0.82, Color(0.42 + 0.12 * beat, 0.03, 0.05, 0.95), true)
		draw_circle(center, radius * 0.55, Color(0.62 + 0.18 * beat, 0.06, 0.08, 0.9), true)
		draw_circle(center, radius, Color(BWKit.EMBER, 0.75), false, 2.0, true)
		draw_circle(center, radius + 7.0, Color(BWKit.BLOOD, 0.35), false, 1.0, true)
		var font = BWKit.title_font()
		var lines = caption.split("\n")
		for i in lines.size():
			var width = BWKit.tracked_width(font, lines[i], 15, 2.0)
			BWKit.draw_tracked(self, font, lines[i], Vector2((size.x - width) * 0.5, center.y - 2.0 + 18.0 * i), 15, BWKit.INK, 2.0)

# The screen title: tracked caps between two hairlines with a diamond over them.
class Heading extends Control:
	var text = ""
	var font_size = 44
	var tracking = 7.0
	var rules = true
	var align_left = false

	func _init(label: String, size: int = 44):
		text = label
		font_size = size
		custom_minimum_size = Vector2(0, size + 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var font = BWKit.title_font()
		var width = BWKit.tracked_width(font, text, font_size, tracking)
		var baseline = font.get_ascent(font_size) + 4.0
		var left = 0.0 if align_left else (size.x - width) * 0.5
		BWKit.draw_tracked(self, font, text, Vector2(left, baseline), font_size, BWKit.INK, tracking)
		if not rules:
			return
		var y = baseline + 20.0
		var half = width * 0.5
		for span in [[size.x * 0.5 - half - 90.0, size.x * 0.5 - 18.0], [size.x * 0.5 + 18.0, size.x * 0.5 + half + 90.0]]:
			draw_line(Vector2(span[0], y), Vector2(span[1], y), Color(BWKit.BLOOD, 0.55), 1.0, true)
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, y), 5.0, BWKit.EMBER)
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, y), 9.0, Color(BWKit.BLOOD, 0.7), false, 1.0)

# A main-menu entry: a framed glyph plate with its own banner label underneath.
class Tile extends Control:
	signal pressed

	const PLATE = 150.0
	const LABEL = 38.0

	var text = ""
	var glyph_name = "rune"
	var hovered = false
	var held = false

	func _init(label: String, name: String, width: float = 176.0):
		text = label
		glyph_name = name
		custom_minimum_size = Vector2(width, PLATE + 12.0 + LABEL)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; held = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			held = event.pressed
			queue_redraw()
			if not event.pressed and hovered:
				pressed.emit()
		elif event.is_action_pressed("ui_accept"):
			pressed.emit()

	func _draw():
		var lit = hovered or has_focus()
		var accent = BWKit.EMBER if lit else Color(BWKit.IRON, 0.95)
		var plate = Rect2(0, 0, size.x, PLATE)
		if lit:
			draw_rect(plate.grow(5.0), Color(BWKit.BLOOD, 0.14), true)
		BWKit.paint_frame(self, plate, Color(0.065, 0.052, 0.054, 0.92) if not held else Color(0.13, 0.05, 0.055, 0.95), accent, 14.0)
		var box = minf(size.x, PLATE) * 0.46
		BWKit.draw_glyph(self, glyph_name, Rect2(plate.get_center() - Vector2(box, box) * 0.5, Vector2(box, box)),
			BWKit.INK if lit else Color(BWKit.MUTED, 0.95), 2.2)
		var bar = Rect2(0, PLATE + 12.0, size.x, LABEL)
		var notch = bar.size.y * 0.45
		var shape = PackedVector2Array([Vector2(bar.position.x, bar.get_center().y), Vector2(bar.position.x + notch, bar.position.y),
			Vector2(bar.end.x - notch, bar.position.y), Vector2(bar.end.x, bar.get_center().y),
			Vector2(bar.end.x - notch, bar.end.y), Vector2(bar.position.x + notch, bar.end.y)])
		draw_colored_polygon(shape, Color(0.17, 0.05, 0.06, 0.95) if lit else Color(0.09, 0.045, 0.05, 0.9))
		var outline = shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, accent if lit else Color(BWKit.BLOOD, 0.5), 1.0, true)
		var font = BWKit.title_font()
		var width = BWKit.tracked_width(font, text, 15, 2.5)
		BWKit.draw_tracked(self, font, text, Vector2((size.x - width) * 0.5, bar.get_center().y + font.get_ascent(15) * 0.5 - 1.0),
			15, Color.WHITE if lit else BWKit.INK, 2.5)

# One portrait in the class row: the baked plate, a mark, and the name on a scrim.
class ClassCard extends Control:
	signal chosen

	var plate: Texture2D
	var text = ""
	var glyph_name = "rune"
	var selected = false
	var hovered = false
	var crop_top = 0.0

	func _init(label: String, texture: Texture2D, mark: String, box: Vector2 = Vector2(196, 262)):
		text = label
		plate = texture
		glyph_name = mark
		# Portraits are dense painted key art shown far below source resolution.
		# Mipmapped anisotropic sampling preserves the brushwork when the whole UI
		# is scaled again for smaller windows.
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		custom_minimum_size = box
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; queue_redraw())

	func _gui_input(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			chosen.emit()
		elif event.is_action_pressed("ui_accept"):
			chosen.emit()

	func _draw():
		var rect = Rect2(Vector2.ZERO, size)
		var lit = selected or hovered or has_focus()
		if selected:
			draw_rect(rect.grow(6.0), Color(BWKit.BLOOD, 0.20), true)
			draw_rect(rect.grow(3.0), Color(BWKit.EMBER, 0.35), false, 1.0)
		draw_rect(rect, Color(0.05, 0.04, 0.042, 0.95), true)
		if plate != null:
			# The plate is taller than the card, so it is cropped from the head down
			# rather than squashed.
			var source = Vector2(plate.get_width(), plate.get_height())
			var keep = Vector2(source.x, source.x * size.y / size.x)
			var top = clampf(crop_top, 0.0, 1.0) * maxf(0.0, source.y - keep.y)
			draw_texture_rect_region(plate, rect, Rect2(Vector2(0, top), keep))
		# A scrim under the name so the type never fights the armour behind it.
		for i in 9:
			var t = i / 8.0
			draw_rect(Rect2(0, size.y - 78.0 + t * 78.0, size.x, 78.0 / 8.0 + 1.0), Color(0.04, 0.02, 0.025, 0.14 + 0.72 * t), true)
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, size.y - 52.0), 15.0, Color(0.09, 0.045, 0.05, 0.95))
		BWKit.paint_diamond(self, Vector2(size.x * 0.5, size.y - 52.0), 15.0, BWKit.EMBER if lit else Color(BWKit.IRON, 0.95), false, 1.0)
		BWKit.draw_glyph(self, glyph_name, Rect2(size.x * 0.5 - 8.0, size.y - 60.0, 16.0, 16.0), BWKit.EMBER if lit else BWKit.MUTED, 1.3)
		var font = BWKit.title_font()
		var width = BWKit.tracked_width(font, text, 16, 3.0)
		BWKit.draw_tracked(self, font, text, Vector2((size.x - width) * 0.5, size.y - 16.0), 16, Color.WHITE if lit else BWKit.INK, 3.0)
		var border = BWKit.EMBER if selected else (Color(BWKit.BLOOD, 0.8) if lit else Color(BWKit.IRON, 0.95))
		BWKit.paint_frame(self, rect, Color(0, 0, 0, 0), border, 14.0)

# The keyboard badge over each ability in the class screen.
class KeyCap extends Control:
	var text = "Q"

	func _init(label: String):
		text = label
		var font = BWKit.body_font()
		custom_minimum_size = Vector2(maxf(26.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0), 20.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.10, 0.085, 0.088, 0.95), true)
		draw_rect(rect, Color(BWKit.MUTED, 0.65), false, 1.0)
		var font = BWKit.body_font()
		var width = BWKit.tracked_width(font, text, 12, 1.4)
		BWKit.draw_tracked(self, font, text, Vector2((size.x - width) * 0.5, size.y * 0.5 + font.get_ascent(12) * 0.5 - 2.0), 12, BWKit.INK, 1.4)
