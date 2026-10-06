class_name BWKit
extends RefCounted

# Shared chrome for the menu screens: the palette, the ornate banner button, the
# notched frame, and a procedural glyph set. Everything here draws itself, so the
# screens need no image assets beyond the class portraits.

const INK = Color("e8ded0")
const MUTED = Color("97897e")
const DIM = Color("6b5f59")
const BLOOD = Color("a41e26")
const EMBER = Color("d9434a")
const GOLD = Color("d7ae64")
const IRON = Color("463634")
const VOID = Color("090607")
const PANEL = Color(0.055, 0.042, 0.044, 0.93)

static var _title: Font

# The display face is read straight out of the .ttf rather than through the font
# importer: the imported cache for this file reports correct metrics but rasterises
# every glyph as a solid block, so every heading came out as a row of rectangles.
static func title_font() -> Font:
	if _title == null:
		var direct = FontFile.new()
		if FileAccess.file_exists("res://assets/art/title.ttf") and direct.load_dynamic_font("res://assets/art/title.ttf")==OK:
			_title=direct
		else:
			# Exports remap the TTF into an imported FontFile. Reconstruct the
			# uncached face from its bytes; the raw editor path is not in the PCK.
			var packed=load("res://assets/art/title.ttf") as FontFile
			if packed!=null:direct.data=packed.data;_title=direct
			else:_title=ThemeDB.fallback_font
	return _title

static func body_font() -> Font:
	var font = load("res://assets/fonts/spectral.ttf")
	return font if font is Font else ThemeDB.fallback_font

# Letterspacing is most of the mockups' voice, so headings and banner labels are
# drawn glyph by glyph instead of through draw_string.
static func tracked_width(font: Font, text: String, size: int, tracking: float) -> float:
	var total = 0.0
	for i in text.length():
		total += font.get_char_size(text.unicode_at(i), size).x + tracking
	return maxf(0.0, total - tracking)

static func draw_tracked(canvas: CanvasItem, font: Font, text: String, origin: Vector2, size: int, color: Color, tracking: float):
	var x = origin.x
	for i in text.length():
		var code = text.unicode_at(i)
		canvas.draw_string(font, Vector2(x, origin.y), String.chr(code), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_char_size(code, size).x + tracking

# ---------------------------------------------------------------- glyph library

static func _ring(center: Vector2, radius: float, steps: int = 28) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in steps + 1:
		var angle = TAU * i / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _arc(center: Vector2, radius: float, from_deg: float, to_deg: float, steps: int = 18) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in steps + 1:
		var angle = deg_to_rad(lerpf(from_deg, to_deg, i / float(steps)))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _star(center: Vector2, outer: float, inner: float, arms: int, offset_deg: float = -90.0) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in arms * 2:
		var angle = deg_to_rad(offset_deg + 180.0 * i / float(arms))
		points.append(center + Vector2(cos(angle), sin(angle)) * (outer if i % 2 == 0 else inner))
	return points

static func _rays(center: Vector2, inner: float, outer: float, count: int, offset_deg: float = 0.0) -> Array:
	var strokes = []
	for i in count:
		var dir = Vector2.RIGHT.rotated(deg_to_rad(offset_deg + 360.0 * i / float(count)))
		strokes.append(["poly", PackedVector2Array([center + dir * inner, center + dir * outer]), false, false])
	return strokes

# A glyph is an array of strokes. A stroke is one of
#   ["poly", points, closed, filled]
#   ["ring", center, radius, filled]
# with all coordinates inside the 0..1 unit box, y pointing down.
static func glyph(name: String) -> Array:
	var c = Vector2(0.5, 0.5)
	match name:
		"sword":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.60, 0.20), Vector2(0.60, 0.62), Vector2(0.40, 0.62), Vector2(0.40, 0.20)]), true, true],
				["poly", PackedVector2Array([Vector2(0.22, 0.62), Vector2(0.78, 0.62), Vector2(0.78, 0.70), Vector2(0.22, 0.70)]), true, true],
				["poly", PackedVector2Array([Vector2(0.5, 0.70), Vector2(0.5, 0.90)]), false, false],
				["ring", Vector2(0.5, 0.93), 0.06, true]]
		"crosshair":
			return [["poly", _ring(c, 0.26), true, false]] + _rays(c, 0.30, 0.46, 4) + [["ring", c, 0.06, true]]
		"slashes":
			return [["poly", PackedVector2Array([Vector2(0.14, 0.78), Vector2(0.52, 0.12)]), false, false],
				["poly", PackedVector2Array([Vector2(0.34, 0.86), Vector2(0.72, 0.20)]), false, false],
				["poly", PackedVector2Array([Vector2(0.54, 0.90), Vector2(0.90, 0.30)]), false, false]]
		"axe":
			return [["poly", PackedVector2Array([Vector2(0.14, 0.26), Vector2(0.5, 0.58), Vector2(0.86, 0.26)]), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.50), Vector2(0.5, 0.82), Vector2(0.86, 0.50)]), false, false]]
		"arrow":
			return [["poly", PackedVector2Array([Vector2(0.14, 0.86), Vector2(0.78, 0.22)]), false, false],
				["poly", PackedVector2Array([Vector2(0.90, 0.10), Vector2(0.56, 0.18), Vector2(0.82, 0.44)]), true, true],
				["poly", PackedVector2Array([Vector2(0.14, 0.86), Vector2(0.14, 0.62)]), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.86), Vector2(0.38, 0.86)]), false, false]]
		"heart":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.90), Vector2(0.12, 0.48), Vector2(0.12, 0.28), Vector2(0.28, 0.14),
				Vector2(0.5, 0.30), Vector2(0.72, 0.14), Vector2(0.88, 0.28), Vector2(0.88, 0.48)]), true, true]]
		"shield":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.88, 0.22), Vector2(0.82, 0.62), Vector2(0.5, 0.94), Vector2(0.18, 0.62), Vector2(0.12, 0.22)]), true, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.22), Vector2(0.70, 0.31), Vector2(0.66, 0.58), Vector2(0.5, 0.78), Vector2(0.34, 0.58), Vector2(0.30, 0.31)]), true, true]]
		"shield_crack":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.88, 0.22), Vector2(0.82, 0.62), Vector2(0.5, 0.94), Vector2(0.18, 0.62), Vector2(0.12, 0.22)]), true, false],
				["poly", PackedVector2Array([Vector2(0.44, 0.18), Vector2(0.60, 0.42), Vector2(0.40, 0.56), Vector2(0.58, 0.84)]), false, false]]
		"plus":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.10), Vector2(0.5, 0.90)]), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.50), Vector2(0.86, 0.50)]), false, false],
				["poly", _ring(c, 0.34), true, false]]
		"drop":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.80, 0.44), Vector2(0.80, 0.64), Vector2(0.5, 0.94), Vector2(0.20, 0.64), Vector2(0.20, 0.44)]), true, true]]
		"boot":
			return [["poly", PackedVector2Array([Vector2(0.30, 0.10), Vector2(0.56, 0.10), Vector2(0.58, 0.54), Vector2(0.88, 0.70), Vector2(0.88, 0.88), Vector2(0.24, 0.88), Vector2(0.24, 0.30)]), true, true]]
		"wing":
			return [["poly", _arc(Vector2(0.5, 0.92), 0.70, -168.0, -100.0), false, false],
				["poly", _arc(Vector2(0.5, 0.92), 0.52, -166.0, -96.0), false, false],
				["poly", _arc(Vector2(0.5, 0.92), 0.34, -162.0, -90.0), false, false]]
		"magnet":
			return [["poly", _arc(c, 0.36, 180.0, 360.0, 22), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.50), Vector2(0.14, 0.86)]), false, false],
				["poly", PackedVector2Array([Vector2(0.86, 0.50), Vector2(0.86, 0.86)]), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.86), Vector2(0.32, 0.86)]), false, false],
				["poly", PackedVector2Array([Vector2(0.68, 0.86), Vector2(0.86, 0.86)]), false, false]]
		"eye":
			return [["poly", _arc(Vector2(0.5, 0.86), 0.56, -145.0, -35.0), false, false],
				["poly", _arc(Vector2(0.5, 0.14), 0.56, 35.0, 145.0), false, false],
				["ring", c, 0.16, true]]
		"coin":
			return [["poly", _ring(c, 0.38), true, false], ["poly", _ring(c, 0.24), true, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.16), Vector2(0.5, 0.84)]), false, false]]
		"burst":
			return _rays(c, 0.18, 0.46, 8) + [["poly", _ring(c, 0.14), true, true]]
		"fan":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.92), Vector2(0.10, 0.28)]), false, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.92), Vector2(0.30, 0.12)]), false, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.92), Vector2(0.5, 0.06)]), false, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.92), Vector2(0.70, 0.12)]), false, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.92), Vector2(0.90, 0.28)]), false, false]]
		"snowflake":
			var strokes = _rays(c, 0.0, 0.44, 6, -90.0)
			for i in 6:
				var dir = Vector2.RIGHT.rotated(deg_to_rad(-90.0 + 60.0 * i))
				var root = c + dir * 0.28
				strokes.append(["poly", PackedVector2Array([root, root + dir.rotated(deg_to_rad(40)) * 0.16]), false, false])
				strokes.append(["poly", PackedVector2Array([root, root + dir.rotated(deg_to_rad(-40)) * 0.16]), false, false])
			return strokes
		"dagger":
			return [["poly", PackedVector2Array([Vector2(0.78, 0.08), Vector2(0.56, 0.58), Vector2(0.42, 0.50)]), true, true],
				["poly", PackedVector2Array([Vector2(0.62, 0.44), Vector2(0.30, 0.74)]), false, false],
				["poly", PackedVector2Array([Vector2(0.24, 0.56), Vector2(0.50, 0.86)]), false, false],
				["poly", PackedVector2Array([Vector2(0.30, 0.74), Vector2(0.14, 0.92)]), false, false]]
		"impact":
			return [["poly", PackedVector2Array([Vector2(0.20, 0.14), Vector2(0.5, 0.48), Vector2(0.80, 0.14)]), false, false],
				["poly", PackedVector2Array([Vector2(0.14, 0.72), Vector2(0.86, 0.72)]), false, false],
				["poly", PackedVector2Array([Vector2(0.26, 0.90), Vector2(0.36, 0.74)]), false, false],
				["poly", PackedVector2Array([Vector2(0.74, 0.90), Vector2(0.64, 0.74)]), false, false]]
		"zigzag":
			return [["poly", PackedVector2Array([Vector2(0.08, 0.30), Vector2(0.40, 0.62), Vector2(0.26, 0.76), Vector2(0.72, 0.28), Vector2(0.58, 0.44), Vector2(0.92, 0.72)]), false, false]]
		"flame":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.78, 0.38), Vector2(0.82, 0.66), Vector2(0.5, 0.94), Vector2(0.18, 0.66), Vector2(0.28, 0.40), Vector2(0.40, 0.52)]), true, true]]
		"comet":
			return [["ring", Vector2(0.70, 0.30), 0.20, true],
				["poly", PackedVector2Array([Vector2(0.50, 0.46), Vector2(0.10, 0.86)]), false, false],
				["poly", PackedVector2Array([Vector2(0.62, 0.54), Vector2(0.30, 0.90)]), false, false],
				["poly", PackedVector2Array([Vector2(0.40, 0.34), Vector2(0.08, 0.60)]), false, false]]
		"spiral":
			var points = PackedVector2Array()
			for i in 46:
				var t = i / 45.0
				points.append(c + Vector2.RIGHT.rotated(t * TAU * 1.6 - PI / 2.0) * lerpf(0.06, 0.44, t))
			return [["poly", points, false, false]]
		"volley":
			var strokes = []
			for i in 3:
				var offset = Vector2(0.0, -0.28 + 0.28 * i)
				strokes.append(["poly", PackedVector2Array([Vector2(0.10, 0.62) + offset, Vector2(0.74, 0.62) + offset]), false, false])
				strokes.append(["poly", PackedVector2Array([Vector2(0.90, 0.62) + offset, Vector2(0.66, 0.52) + offset, Vector2(0.66, 0.72) + offset]), true, true])
			return strokes
		"rune":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.04), Vector2(0.92, 0.50), Vector2(0.5, 0.96), Vector2(0.08, 0.50)]), true, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.24), Vector2(0.5, 0.76)]), false, false],
				["poly", PackedVector2Array([Vector2(0.30, 0.42), Vector2(0.70, 0.58)]), false, false]]
		"helm":
			return [["poly", PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.84, 0.26), Vector2(0.84, 0.66), Vector2(0.64, 0.94), Vector2(0.36, 0.94), Vector2(0.16, 0.66), Vector2(0.16, 0.26)]), true, false],
				["poly", PackedVector2Array([Vector2(0.26, 0.44), Vector2(0.44, 0.44), Vector2(0.44, 0.60), Vector2(0.26, 0.60)]), true, true],
				["poly", PackedVector2Array([Vector2(0.56, 0.44), Vector2(0.74, 0.44), Vector2(0.74, 0.60), Vector2(0.56, 0.60)]), true, true],
				["poly", PackedVector2Array([Vector2(0.5, 0.30), Vector2(0.5, 0.90)]), false, false]]
		"tree":
			var strokes = [["poly", PackedVector2Array([Vector2(0.5, 0.94), Vector2(0.5, 0.46)]), false, false],
				["poly", _arc(Vector2(0.5, 0.42), 0.36, 200.0, 340.0), false, false]]
			for spec in [[-1, 0.30], [1, 0.30], [-1, 0.56], [1, 0.56]]:
				var side = float(spec[0])
				var y = float(spec[1])
				strokes.append(["poly", PackedVector2Array([Vector2(0.5, y + 0.16), Vector2(0.5 + side * 0.28, y)]), false, false])
			return strokes
		"anvil":
			return [["poly", PackedVector2Array([Vector2(0.08, 0.34), Vector2(0.78, 0.34), Vector2(0.92, 0.46), Vector2(0.70, 0.52), Vector2(0.62, 0.66), Vector2(0.38, 0.66), Vector2(0.30, 0.52), Vector2(0.08, 0.46)]), true, true],
				["poly", PackedVector2Array([Vector2(0.26, 0.66), Vector2(0.24, 0.90), Vector2(0.76, 0.90), Vector2(0.74, 0.66)]), true, false]]
		"gate":
			var strokes = [["poly", _arc(Vector2(0.5, 0.46), 0.38, 180.0, 360.0), false, false],
				["poly", PackedVector2Array([Vector2(0.12, 0.46), Vector2(0.12, 0.94), Vector2(0.88, 0.94), Vector2(0.88, 0.46)]), false, false]]
			for x in [0.30, 0.5, 0.70]:
				strokes.append(["poly", PackedVector2Array([Vector2(x, 0.14 + absf(x - 0.5) * 0.5), Vector2(x, 0.94)]), false, false])
			strokes.append(["poly", PackedVector2Array([Vector2(0.12, 0.62), Vector2(0.88, 0.62)]), false, false])
			return strokes
		"cog":
			var strokes = [["poly", _star(c, 0.46, 0.32, 8), true, true], ["poly", _ring(c, 0.16), true, false]]
			return strokes
		_:
			return [["poly", PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.94, 0.5), Vector2(0.5, 0.94), Vector2(0.06, 0.5)]), true, false],
				["poly", PackedVector2Array([Vector2(0.5, 0.28), Vector2(0.72, 0.5), Vector2(0.5, 0.72), Vector2(0.28, 0.5)]), true, true]]

const SKILL_GLYPHS = {
	"might": "sword", "precision": "crosshair", "fury": "slashes", "execution": "axe", "reach": "arrow",
	"vigor": "heart", "plate": "shield", "renewal": "plus", "drain": "drop", "last_stand": "shield_crack",
	"stride": "boot", "reflex": "wing", "magnet": "magnet", "insight": "eye", "scavenger": "coin"
}

const ABILITY_GLYPHS = {
	"ember_dash": "flame", "war_cry": "burst", "fan_shot": "fan", "frost_nova": "snowflake", "shadow_strike": "dagger",
	"arcane_meteor": "comet", "void_leap": "spiral", "sunder_leap": "impact", "whirl": "slashes",
	"phantom_volley": "volley", "ricochet_round": "zigzag", "powder_charge": "flame", "mark_of_ruin": "rune"
}

static func draw_glyph(canvas: CanvasItem, name: String, box: Rect2, color: Color, width: float = 2.0):
	for stroke in glyph(name):
		if stroke[0] == "ring":
			var center = box.position + Vector2(stroke[1]) * box.size
			var radius = float(stroke[2]) * minf(box.size.x, box.size.y)
			canvas.draw_circle(center, radius, color, bool(stroke[3]), -1.0 if stroke[3] else width, true)
			continue
		var points = PackedVector2Array()
		for point in stroke[1]:
			points.append(box.position + point * box.size)
		if stroke[3] and points.size() > 2:
			canvas.draw_colored_polygon(points, color)
		elif stroke[2]:
			points.append(points[0])
			canvas.draw_polyline(points, color, width, true)
		else:
			canvas.draw_polyline(points, color, width, true)

# ------------------------------------------------------------------ frame paint

# The notched frame the mockups put around every panel: a hairline border, a
# heavier inner keyline, and a tick cut out of each corner.
static func paint_frame(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, tick: float = 12.0):
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, 1.0)
	canvas.draw_rect(rect.grow(-4.0), Color(border, border.a * 0.4), false, 1.0)
	for corner in [[rect.position, Vector2(1, 1)], [Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
			[rect.end, Vector2(-1, -1)], [Vector2(rect.position.x, rect.end.y), Vector2(1, -1)]]:
		var origin = Vector2(corner[0])
		var step = Vector2(corner[1])
		canvas.draw_polyline(PackedVector2Array([origin + Vector2(step.x * tick, 0), origin, origin + Vector2(0, step.y * tick)]), border, 2.0, true)

static func paint_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color, filled: bool = true, width: float = 1.0):
	var points = PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if filled:
		canvas.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, color, width, true)

static func reward_glyph(id: String) -> String:
	var marks={"sharpened":"sword","rapid_fire_stat":"slashes","vitality":"heart","predator":"crosshair","vampirism":"drop","swift":"boot","platinum_armor":"shield","swift_boots":"boot","hunters_scope":"crosshair","vampiric_amulet":"drop","lucky_charm":"coin","guardian_angel":"wing","bellbreaker_sigil":"impact","wardens_mantle":"shield","nightglass_lens":"crosshair","greatsword":"sword","storm_blade":"zigzag","shockwave":"impact","thunderquake":"impact","armor_piercer":"arrow","spellfire":"flame","hemorrhage":"drop"}
	if marks.has(id):return marks[id]
	if id.contains("rifle"):return "crosshair"
	if id.contains("orb"):return "snowflake"
	if id.contains("dagger"):return "dagger"
	if id.contains("sword"):return "sword"
	if id.contains("thunder"):return "zigzag"
	return "rune"
