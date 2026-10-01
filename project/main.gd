extends Control

class BoardDisplay extends Control:
	signal tower_selected(point: Vector2i)
	signal zoom_changed(percent: int)
	var board_data: Dictionary = {}
	var board_path: Array[Vector2i] = []
	var board_water: Array[Vector2i] = []
	var tower_ranges: Dictionary = {}
	var board_number := 0
	var nuke_flash := false
	var shared_board := false
	var selected_tower := Vector2i(-1, -1)
	var zoom_scale := 1.0
	var fit_side := 240.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and is_equal_approx(zoom_scale, 1.0):
			fit_side = maxf(240.0, minf(size.x - 32.0, size.y - 64.0))

	func _draw() -> void:
		if board_data.is_empty():
			return
		var side := minf(size.x - 32.0, size.y - 64.0)
		if zoom_scale < 1.0:
			side *= zoom_scale
		if side <= 20.0:
			return
		var cell := side / 10.0
		var origin := Vector2((size.x - side) / 2.0, 42.0)
		var player_name: String = board_data.get("name", "Player")
		var accent := Color("#68d8e8") if board_number == 0 else Color("#df78ed")
		var font := ThemeDB.fallback_font
		var header := "CO-OP // SHARED ARENA" if shared_board else "P%d // %s" % [board_number + 1, player_name]
		draw_string(font, Vector2((size.x - font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x) / 2.0, 25), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, accent)
		for y in range(10):
			for x in range(10):
				var point := Vector2i(x, y)
				var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
				var is_path := point in board_path
				var is_water := point in board_water
				draw_rect(rect, Color("#263b53") if is_path else Color("#12364b") if is_water else Color("#0c1828"), true)
				draw_rect(rect, Color("#31445a"), false, 1.0)
				var glyph := "·" if is_path else "≈" if is_water else ""
				var ink := Color("#ffc75e") if is_path else Color("#48aeca")
				if point == board_path.front():
					glyph = "▶"
				elif point == board_path.back():
					glyph = "◎"
				for tower in board_data.get("towers", []):
					if int(tower.x) == x and int(tower.y) == y:
						glyph = {"dart":"D", "tack":"T", "sniper":"S", "bomb":"B", "farm":"$", "medic":"+", "sub":"U"}.get(tower.kind, "?")
						ink = {"dart":Color("#61d9e8"), "tack":Color("#ef78da"), "sniper":Color("#7b9eff"), "bomb":Color("#ff7878"), "farm":Color("#75e6a9"), "medic":Color("#75e6a9"), "sub":Color("#70c9ff")}.get(tower.kind, Color.WHITE)
				for spike in board_data.get("spikes", []):
					if spike.point == point:
						glyph = "^"
						ink = Color("#ffc75e")
				for balloon in board_data.get("balloons", []):
					if balloon.health > 0 and board_path[mini(balloon.path, board_path.size() - 1)] == point:
						glyph = "M" if balloon.kind == "moab" else balloon.kind.left(1).to_upper()
						ink = {"red":Color("#ff7777"), "blue":Color("#70baff"), "green":Color("#75e6a9"), "yellow":Color("#ffc75e"), "moab":Color("#df78ed")}.get(balloon.kind, Color.WHITE)
				if nuke_flash:
					glyph = "X" if (x + y) % 2 == 0 else "*"
					ink = Color("#ff7777") if y % 2 == 0 else Color("#ffc75e")
				for tower in board_data.get("towers", []):
					if Vector2i(int(tower.x), int(tower.y)) == point and int(tower.get("shot_timer", 0)) > 0:
						var target: Vector2i = tower.get("shot_target", point)
						var target_pos := origin + (Vector2(target) + Vector2(0.5, 0.5)) * cell
						var tower_pos := rect.position + Vector2(cell, cell) * 0.5
						draw_line(tower_pos, target_pos, Color("#ffe08a", 0.9), 2.0, true)
						draw_circle(target_pos, cell * 0.11, Color("#fff2bd", 0.9))
						break
				if glyph != "":
					var font_size := maxi(10, int(cell * 0.45))
					var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
					draw_string(font, rect.position + Vector2((cell - text_size.x) / 2.0, (cell + font_size * 0.65) / 2.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		for x in range(10):
			var column_label := str(x)
			var label_width := font.get_string_size(column_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var label_x := origin.x + x * cell + (cell - label_width) / 2.0
			draw_string(font, Vector2(label_x, origin.y + side + 17), column_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8aa0bd"))
		for y in range(10):
			draw_string(font, Vector2(origin.x - 18, origin.y + y * cell + cell * 0.68), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8aa0bd"))
		if selected_tower.x >= 0:
			var radius_tiles: float = float(tower_ranges.get(selected_tower, 0.0))
			if radius_tiles > 0.0:
				draw_arc(origin + (Vector2(selected_tower) + Vector2(0.5, 0.5)) * cell, radius_tiles * cell, 0.0, TAU, 64, Color("#ffc75e", 0.9), 2.0, true)
		var footer := "Incoming %d  |  Active %d  •  Click a tower to view attack radius" % [board_data.get("incoming", []).size(), board_data.get("balloons", []).size()]
		draw_string(font, Vector2((size.x - font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) / 2.0, origin.y + side + 40), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8aa0bd"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom(zoom_scale + (0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1))
			accept_event()
			return
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		var side := minf(size.x - 32.0, size.y - 64.0)
		if zoom_scale < 1.0:
			side *= zoom_scale
		var cell := side / 10.0
		var origin := Vector2((size.x - side) / 2.0, 42.0)
		var tile := Vector2i(floori((event.position.x - origin.x) / cell), floori((event.position.y - origin.y) / cell))
		selected_tower = tile if tower_ranges.has(tile) and tile != selected_tower else Vector2i(-1, -1)
		tower_selected.emit(selected_tower)
		queue_redraw()

	func set_zoom(value: float) -> void:
		zoom_scale = clampf(value, 0.75, 2.0)
		if zoom_scale > 1.0:
			custom_minimum_size = Vector2(fit_side * zoom_scale + 32.0, fit_side * zoom_scale + 64.0)
		else:
			custom_minimum_size = Vector2(240.0, 240.0)
		zoom_changed.emit(roundi(zoom_scale * 100.0))
		queue_redraw()

	func zoom_percent() -> int:
		return roundi(zoom_scale * 100.0)

	func show_board(data: Dictionary, cells: Array[Vector2i], water: Array[Vector2i], ranges: Dictionary, player_index: int, flash: bool, shared: bool) -> void:
		board_data = data
		board_path = cells
		board_water = water
		tower_ranges = ranges
		board_number = player_index
		nuke_flash = flash
		shared_board = shared
		queue_redraw()


const BOARD_SIZE := 10
const MAX_COMMANDERS := 3
const COMMANDER_VOICE_CATEGORIES := {
	"build": {"tower_built": "build/tower_built.ogg"},
	"streak": {"activated": "streak/activated.ogg"},
	"match_result": {"victory": "match_result/victory.ogg", "defeat": "match_result/defeat.ogg"},
}
const START_CASH := 400
const ROUND_INCOME := 50
const WATER_TILES: Array[Vector2i] = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]
const PATH: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2),
	Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 7),
	Vector2i(8, 7), Vector2i(7, 7), Vector2i(6, 7), Vector2i(5, 7), Vector2i(4, 7),
	Vector2i(3, 7), Vector2i(2, 7), Vector2i(1, 7), Vector2i(0, 7),
]
const TOWERS := {
	"dart": {"cost": 100, "range": 3.0, "damage": 2, "rate": 1, "hp": 30, "pierce": 1},
	"tack": {"cost": 180, "range": 2.0, "damage": 2, "rate": 2, "hp": 28, "pierce": 3},
	"sniper": {"cost": 300, "range": 99.0, "damage": 12, "rate": 3, "hp": 26, "pierce": 1},
	"bomb": {"cost": 260, "range": 3.0, "damage": 5, "rate": 3, "hp": 38, "pierce": 1, "splash": 1.6},
	"farm": {"cost": 200, "range": 0.0, "damage": 0, "rate": 1, "hp": 22, "income": 60},
	"medic": {"cost": 280, "range": 3.0, "damage": 0, "rate": 2, "hp": 32, "heal": 2},
	"sub": {"cost": 320, "range": 4.0, "damage": 8, "rate": 2, "hp": 36, "pierce": 1},
}
const BALLOONS := {
	"red": {"hp": 1, "speed": 1, "cost": 1, "reward": 1.25, "bite": 4, "unlock": 1},
	"blue": {"hp": 2, "speed": 1, "cost": 2, "reward": 2.5, "bite": 6, "unlock": 1},
	"green": {"hp": 3, "speed": 1, "cost": 10, "reward": 12.5, "bite": 8, "unlock": 1},
	"yellow": {"hp": 4, "speed": 2, "cost": 18, "reward": 22.5, "bite": 10, "unlock": 1},
	"moab": {"hp": 40, "speed": 1, "cost": 150, "reward": 187.5, "bite": 22, "unlock": 8},
}
const STREAKS := {
	"supply": {"pops": 3, "cost": 250},
	"repair": {"pops": 6, "cost": 600},
	"nuke": {"pops": 10, "cost": 3000},
}
const GDSCRIPT_COURSE := [
	{"title":"Your first command", "lesson":"Godot stores a game as a Scene made from Nodes. This screen is built from UI Nodes; the board is a custom Control Node. The planner runs a GDScript plan that calls methods such as build(), and records those game actions for the round.", "example":"build(\"dart\", 4, 3)", "challenge":"Build one Dart tower on an open tile.", "hint":"Coordinates are column first, then row. Try a tile above or below the road.", "goal":"build"},
	{"title":"Variables and notebook aliases", "lesson":"A GDScript variable names a value and starts with var. The notebook also supports a short alias line: dart = \"dart\". That line is a notebook reference (not a GDScript declaration); the planner substitutes the saved value when it sees bare dart in build(dart, ...).", "example":"build(dart, 4, 3)", "challenge":"Save the dart alias in your notebook, then build using build(dart, 4, 3).", "hint":"In Notebook, keep dart = \"dart\" on its own line. In the planner, write build(dart, column, row) without quotes around the alias.", "goal":"alias"},
	{"title":"Typed values and coordinates", "lesson":"GDScript can calculate values before using them. Add a type after the variable name to catch mistakes early; int means a whole number and String means text.", "example":"var lane: int = 2 + 2\nbuild(\"dart\", lane, 3)", "challenge":"Calculate a coordinate in a variable and use it in a build action.", "hint":"Start with var lane: int = 2 + 2, then pass lane where build() expects the x coordinate.", "goal":"variable"},
	{"title":"Conditions", "lesson":"An if statement runs indented code only when its condition is true. The planner exposes money, lives, round_number, and streak_count.", "example":"if money >= 100:\n    build(\"dart\", 4, 3)", "challenge":"Use an if check before building a tower.", "hint":"Write if money >= 100: and indent the build() call by four spaces.", "goal":"condition"},
	{"title":"Loops", "lesson":"A for loop repeats an indented block. range(3) gives 0, 1, and 2. Keep each placement on a different open tile.", "example":"for x in range(3):\n    build(\"dart\", x, 1)", "challenge":"Use a loop to place at least two towers.", "hint":"Use range(2) for two x values. Indent build() so it stays inside the loop.", "goal":"loop"},
	{"title":"Arrays", "lesson":"An Array stores an ordered list. Loop through the list to reuse one action for each value.", "example":"var lanes = [1, 3, 5]\nfor x in lanes:\n    build(\"dart\", x, 1)", "challenge":"Create an array of coordinates and loop over it to place at least two towers.", "hint":"Put two or more x coordinates between square brackets, then use for x in lanes:.", "goal":"array"},
	{"title":"Dictionaries", "lesson":"A Dictionary maps keys to values. Use square brackets to read a value by key, then use it in an action.", "example":"var plan = {\"kind\": \"dart\", \"x\": 4}\nbuild(plan[\"kind\"], plan[\"x\"], 3)", "challenge":"Create a dictionary and use its stored tower name and coordinate in a build.", "hint":"Use quoted keys like plan[\"kind\"] and plan[\"x\"]. A missing quote or bracket is a common parser error.", "goal":"dictionary"},
	{"title":"Godot scenes, Nodes, and methods", "lesson":"A Scene is a reusable Node tree. Nodes own behavior and children; this game uses Control Nodes for its interface and a Timer Node for battle ticks. The planner API is a RefCounted script that records build(), send(), and upgrade() method calls. In your notebook, write a real no-argument method such as func opening(): followed by an indented build(...). Save it as opening, then call opening() from the planner.", "example":"opening()", "challenge":"Save a GDScript method named opening in the notebook, then call opening() in the planner.", "hint":"Write func opening(): on the first line and indent build() on the next. Save it as a function, then run opening() in the planner.", "goal":"notebook"},
	{"title":"Read game state", "lesson":"Plans can react to the current match state. Use lives, money, round_number, and streak_count to choose actions.", "example":"if lives < 50:\n    build(\"medic\", 4, 4)\nif round_number >= 3:\n    upgrade(4, 4)", "challenge":"Use a game-state value in a condition and queue a valid action.", "hint":"Try if lives < 100: then place a Medic on an empty non-road tile.", "goal":"state"},
	{"title":"Capstone: compose a strategy", "lesson":"Combine typed values, conditions, arrays or loops, and methods. Godot also uses signals to let Nodes react to events, Resources to hold reusable data, and Scenes to package Nodes. This training planner runs safe GDScript against the game-action API; editing project Scenes and Node scripts happens in the Godot editor.", "example":"var kind = \"dart\"\nif money >= 200:\n    for x in range(2):\n        build(kind, x, 1)", "challenge":"Write one plan combining a variable, an if condition, and a loop that queues at least two actions.", "hint":"First declare a tower name. Put the for loop inside an if block, then indent build() inside the loop.", "goal":"capstone"},
]

var players: Array[Dictionary] = []
var plans: Array = [[], []]
var round_number := 1
var planning_player := 0
var game_started := false
var in_battle := false
var tick_number := 0
var network_role := "offline"
var peer_ready := false
var remote_peer_id := 0
var network_disconnected := false
var ready_flags := [false, false]
var join_name_field: LineEdit
var join_ip_field: LineEdit
var host_name_field: LineEdit
var local_name_fields: Array[LineEdit] = []
var network_status_label: Label
const PLAYTEST_VERSION := "20"
const DEFAULT_MUSIC_VOLUME := 4.0

var shell: VBoxContainer
var board_row: HBoxContainer
var board_views: Array[BoardDisplay] = []
var status_view: RichTextLabel
var log_view: RichTextLabel
var log_window: Window
var log_window_view: RichTextLabel
var event_window_view: RichTextLabel
var log_history := ""
var event_history: Array[String] = []
var event_serial := 0
var last_event_serial := 0
var pending_event_broadcast: Array[Dictionary] = []
var help_window: Window
var notebook_window: Window
var notebook_picker: OptionButton
var notebook_name_field: LineEdit
var notebook_note_picker: OptionButton
var notebook_note_name: LineEdit
var notebook_editor: TextEdit
var notebook_save_status: Label
var notebook_autosave_timer: Timer
var code_editor: TextEdit
var player_label: Label
var round_label: Label
var session_timer_label: Label
var timer: Timer
var music_player: AudioStreamPlayer
var menu_music: AudioStreamMP3
var battle_music: AudioStreamMP3
var commander_voice_players: Array[AudioStreamPlayer] = []
var music_volume := DEFAULT_MUSIC_VOLUME
var rematch_button: Button
var match_elapsed := 0.0
var timer_second := -1
var solo_mode := false
var learning_mode := false
var completed_lessons := 0
var course_window: Window
var course_title_label: Label
var course_body_label: Label
var course_challenge_label: Label
var course_hint_label: Label
var course_example_editor: TextEdit
var course_progress_label: Label
var course_prev_button: Button
var course_next_button: Button
var course_view_index := 0
var course_status_label: Label
var match_mode := "duel"
var match_mode_option: OptionButton


func _ready() -> void:
	theme = _make_theme()
	get_window().title = "Terminus-Battles — GDScript Strategy Game"
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		music_volume = clampf(float(settings.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 100.0)
	var course_progress := ConfigFile.new()
	if course_progress.load("user://learning_progress.cfg") == OK:
		completed_lessons = clampi(int(course_progress.get_value("course", "completed", 0)), 0, GDSCRIPT_COURSE.size())
	var menu_music_path := "res://music/BTD_Warzone_2100_Inspired.mp3"
	var battle_music_path := "res://music/Martin_Severn_-_Warzone_2100_-_1._Nuclear_Silence_(mp3.pm).mp3"
	menu_music = load(menu_music_path) as AudioStreamMP3 if ResourceLoader.exists(menu_music_path) else null
	battle_music = load(battle_music_path) as AudioStreamMP3 if ResourceLoader.exists(battle_music_path) else null
	if menu_music != null:
		menu_music.loop = true
	if battle_music != null:
		battle_music.loop = true
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	_set_music_track(false)
	_apply_music_volume()
	for commander_index in range(MAX_COMMANDERS):
		var voice_player := AudioStreamPlayer.new()
		voice_player.name = "CommanderVoice%d" % (commander_index + 1)
		music_player.add_child(voice_player)
		commander_voice_players.append(voice_player)
	_build_menu()


func _set_music_track(in_match: bool) -> void:
	if not is_instance_valid(music_player):
		return
	var next_track: AudioStreamMP3 = battle_music if in_match else menu_music
	if next_track == null:
		next_track = menu_music if in_match else battle_music
	if next_track != null and music_player.stream != next_track:
		music_player.stream = next_track
		music_player.play()


func _trigger_commander_voice(player_index: int, category: String, event_name: String) -> void:
	if player_index < 0 or player_index >= MAX_COMMANDERS:
		return
	_play_commander_voice(player_index, category, event_name)
	if network_role == "host" and peer_ready:
		rpc("receive_commander_voice", player_index, category, event_name)


@rpc("authority", "call_remote", "reliable")
func receive_commander_voice(player_index: int, category: String, event_name: String) -> void:
	_play_commander_voice(player_index, category, event_name)


func _play_commander_voice(player_index: int, category: String, event_name: String) -> void:
	if player_index < 0 or player_index >= commander_voice_players.size():
		return
	var category_events: Dictionary = COMMANDER_VOICE_CATEGORIES.get(category, {})
	var relative_path: String = category_events.get(event_name, "")
	if relative_path.is_empty():
		return
	var voice_path := "res://voice/commander_%d/%s" % [player_index + 1, relative_path]
	if not ResourceLoader.exists(voice_path):
		return
	var voice_clip := load(voice_path) as AudioStream
	if voice_clip == null:
		return
	var voice_player: AudioStreamPlayer = commander_voice_players[player_index]
	voice_player.stream = voice_clip
	voice_player.play()


func _apply_music_volume() -> void:
	if is_instance_valid(music_player):
		music_player.volume_db = linear_to_db(music_volume / 100.0) if music_volume > 0.0 else -80.0


func _set_music_volume(value: float, value_label: Label) -> void:
	music_volume = clampf(value, 0.0, 100.0)
	value_label.text = "%d%%" % roundi(music_volume)
	_apply_music_volume()
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	settings.set_value("audio", "music_volume", music_volume)
	settings.save("user://settings.cfg")


func _show_settings() -> void:
	var window := Window.new()
	window.title = "Terminus-Battles — Settings"
	window.size = Vector2i(440, 190)
	window.transient = true
	window.exclusive = false
	add_child(window)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("margin_left", 18)
	layout.add_theme_constant_override("margin_right", 18)
	layout.add_theme_constant_override("margin_top", 16)
	layout.add_theme_constant_override("margin_bottom", 16)
	window.add_child(layout)
	var heading := Label.new()
	heading.text = "SOUNDTRACK VOLUME"
	heading.add_theme_color_override("font_color", Color("#69e3ab"))
	layout.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = music_volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d%%" % roundi(music_volume)
	value_label.custom_minimum_size.x = 48
	row.add_child(value_label)
	slider.value_changed.connect(_set_music_volume.bind(value_label))
	layout.add_child(_button("CLOSE", window.queue_free))
	window.close_requested.connect(window.queue_free)
	window.popup_centered()


func _process(delta: float) -> void:
	if not game_started or network_role == "client":
		return
	match_elapsed += delta
	var current_second := floori(match_elapsed)
	if current_second != timer_second:
		timer_second = current_second
		_update_session_timer()
		if network_role == "host":
			_send_state()


func _update_session_timer() -> void:
	if not is_instance_valid(session_timer_label):
		return
	var total := floori(match_elapsed)
	session_timer_label.text = "SESSION %02d:%02d" % [int(total / 60), total % 60]


func _make_theme() -> Theme:
	var result := Theme.new()
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
	result.default_font = mono
	result.default_font_size = 16
	result.set_color("font_color", "Label", Color("#d9e7ff"))
	result.set_color("font_color", "Button", Color("#b8f4d0"))
	result.set_color("font_color", "font", Color("#d9e7ff"))
	return result


func _root_container() -> VBoxContainer:
	var background := ColorRect.new()
	background.color = Color("#07101c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)
	return shell


func _heading(title: String, subtitle: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color("#69e3ab"))
	label.add_theme_font_size_override("font_size", 28)
	shell.add_child(label)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_color_override("font_color", Color("#8aa0bd"))
	shell.add_child(sub)
	var separator := HSeparator.new()
	shell.add_child(separator)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	return button


func _host_match() -> void:
	if network_role == "host":
		return _menu_notice("Room is open. Leave this game running while your friend joins.")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(24680, 1)
	if error != OK:
		return _menu_notice("Could not host on UDP port 24680 (error %d)." % error)
	multiplayer.multiplayer_peer = peer
	network_role = "host"
	network_disconnected = false
	_menu_notice("ROOM OPEN — leave this screen running. Send your public IP to your friend; they enter it under JOIN A FRIEND. If they are outside your home network, UDP port 24680 may need router forwarding.")


func _join_match() -> void:
	var address := join_ip_field.text.strip_edges()
	if address.is_empty():
		join_ip_field.grab_focus()
		return _menu_notice("Type the HOST'S PUBLIC IP in the box under JOIN A FRIEND, then click JOIN HOST.")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, 24680)
	if error != OK:
		return _menu_notice("Could not connect (error %d)." % error)
	multiplayer.multiplayer_peer = peer
	network_role = "client"
	network_disconnected = false
	_menu_notice("Connecting to %s on port 24680… Keep this window open." % address)


func _menu_notice(message: String) -> void:
	if is_instance_valid(network_status_label):
		network_status_label.text = message


func _peer_connected(_id: int) -> void:
	if network_role == "host":
		_menu_notice("Friend connected. Starting the match…")
		if is_instance_valid(log_view):
			_log("Network: friend connected; checking playtest version.")


func _peer_disconnected(peer_id: int) -> void:
	if network_role == "host":
		peer_ready = false
		remote_peer_id = 0
		network_disconnected = true
		if is_instance_valid(timer):
			timer.stop()
		_log("[color=#ff7777]NETWORK: %s (peer %d) disconnected during round %d. Battle paused; board state is preserved. They can rejoin the host to sync and resume.[/color]" % [players[1].name if players.size() > 1 else "Friend", peer_id, round_number])
		_refresh()
	elif network_role == "client":
		network_disconnected = true
		_log("[color=#ff7777]NETWORK: host connection lost. This board is paused at round %d. Rejoin the host to sync.[/color]" % round_number)
		_refresh()


func _connected_to_server() -> void:
	if network_role == "client":
		var name := join_name_field.text.strip_edges()
		if name.is_empty():
			name = "Player 2"
		rpc_id(1, "request_join", name, PLAYTEST_VERSION)


func _connection_failed() -> void:
	network_role = "offline"
	network_disconnected = false
	multiplayer.multiplayer_peer = null
	_build_menu()
	_menu_notice("Connection failed. Check the IP, host status, firewall, and UDP port 24680.")


@rpc("any_peer", "call_remote", "reliable")
func request_join(player_name: String, version: String) -> void:
	if network_role != "host" or version != PLAYTEST_VERSION:
		rpc_id(multiplayer.get_remote_sender_id(), "join_rejected", "Version mismatch. Both players need the same playtest ZIP.")
		return
	peer_ready = true
	remote_peer_id = multiplayer.get_remote_sender_id()
	var safe_name := player_name.replace("[", "").replace("]", "").strip_edges().left(18)
	if game_started and network_disconnected and players.size() == 2:
		network_disconnected = false
		players[1].name = safe_name if safe_name != "" else players[1].name
		_log("[color=#69e3ab]NETWORK: %s reconnected. Host state sent; resuming round %d.[/color]" % [players[1].name, round_number])
		if in_battle and is_instance_valid(timer):
			timer.start()
		_send_state()
		_refresh()
		return
	players = [_make_player(_clean_name(host_name_field.text, "Host")), _make_player(safe_name if safe_name != "" else "Player 2")]
	network_role = "host"
	network_disconnected = false
	_start_match()
	_log("Online %s connected: %s and %s." % ["co-op survival" if match_mode == "coop" else "duel", players[0].name, players[1].name])
	_send_state()


@rpc("authority", "call_remote", "reliable")
func join_rejected(reason: String) -> void:
	network_role = "offline"
	network_disconnected = false
	multiplayer.multiplayer_peer = null
	_build_menu()
	_menu_notice(reason)


@rpc("any_peer", "call_remote", "reliable")
func submit_plan(actions: Array) -> void:
	if network_role != "host" or multiplayer.get_remote_sender_id() != remote_peer_id:
		return
	var sender := multiplayer.get_remote_sender_id()
	if actions.size() > 50:
		rpc_id(sender, "plan_rejected", "Your plan has more than 50 actions. Shorten it, then press READY again.")
		return
	if ready_flags[1]:
		rpc_id(sender, "plan_rejected", "The host already has your READY plan for this round.")
		return
	for action_index in range(actions.size()):
		var action = actions[action_index]
		if not action is Dictionary or not _valid_action(action):
			rpc_id(sender, "plan_rejected", "The host rejected action %d. Check the action name, arguments, and coordinates, then submit again." % (action_index + 1))
			return
	plans[1] = actions.duplicate(true)
	if match_mode == "coop" and actions.any(func(item): return item.get("op") == "send"):
		plans[1].clear()
		rpc_id(sender, "plan_rejected", "Co-op survival uses automatic incoming waves; remove send() from the plan.")
		return
	if _preview_money(1) < -0.001:
		plans[1].clear()
		rpc_id(sender, "plan_rejected", "Queued spending exceeds available cash. Nothing was charged; revise the plan.")
		return
	ready_flags[1] = true
	_log("%s submitted %d action(s) and is READY. Waiting for %s." % [players[1].name, actions.size(), players[0].name if not ready_flags[0] else "both plans"])
	if ready_flags[0] and ready_flags[1]:
		_execute_plans()
	else:
		_send_state()


@rpc("authority", "call_remote", "reliable")
func plan_rejected(reason: String) -> void:
	if network_role != "client":
		return
	plans[1].clear()
	ready_flags[1] = false
	_log("[color=#ff7777]HOST REJECTED PLAN: %s No actions were applied and no cash was spent. Run your plan again after editing it.[/color]" % reason)
	_refresh()


@rpc("authority", "call_remote", "reliable")
func receive_state(state: Dictionary) -> void:
	if network_role != "client":
		return
	var previous_round := round_number
	var previous_battle := in_battle
	var previous_ready: Array = ready_flags.duplicate()
	var previously_started := game_started
	var received_round: int = state.get("round", 1)
	var keep_local_plan: bool = game_started and not in_battle and not ready_flags[1] and received_round == round_number
	var local_plan: Array = plans[1].duplicate(true)
	players.clear()
	for player in state.get("players", []):
		players.append(player)
	plans = state.get("plans", [[], []])
	round_number = received_round
	match_mode = state.get("mode", "duel")
	in_battle = state.get("battle", false)
	game_started = state.get("started", true)
	if game_started and not previously_started:
		_set_music_track(true)
	ready_flags = state.get("ready", [false, false])
	if game_started and not previously_started:
		event_history.clear()
		last_event_serial = 0
		if is_instance_valid(event_window_view):
			event_window_view.clear()
	if keep_local_plan and not ready_flags[1] and not in_battle:
		plans[1] = local_plan
	match_elapsed = state.get("elapsed", 0.0)
	planning_player = 0 if not ready_flags[0] else 1 if not ready_flags[1] else -1
	_update_session_timer()
	if not is_instance_valid(code_editor):
		_build_game_ui()
	if game_started and previous_round > 0:
		if round_number != previous_round:
			_log("[color=#69e3ab]SYNC: Host advanced to round %d. Both boards updated.[/color]" % round_number)
		elif not previous_battle and in_battle:
			_log("[color=#69e3ab]SYNC: Both plans locked. Host started resolving round %d.[/color]" % round_number)
		elif previous_ready != ready_flags:
			var ready_names: PackedStringArray = []
			for index in range(2):
				if ready_flags[index]:
					ready_names.append(players[index].name)
			_log("SYNC: Ready status from host — %s ready." % (", ".join(ready_names) if not ready_names.is_empty() else "both players planning"))
	_refresh()


func _send_state() -> void:
	if network_role != "host" or not peer_ready:
		return
	rpc("receive_state", {"players": players.duplicate(true), "plans": plans.duplicate(true),
		"round": round_number, "battle": in_battle, "started": game_started, "ready": ready_flags.duplicate(), "elapsed": match_elapsed, "mode": match_mode})


func _valid_action(action: Dictionary) -> bool:
	match action.get("op", ""):
		"build": return TOWERS.has(action.get("kind", "")) and _valid_xy(action)
		"send": return BALLOONS.has(action.get("kind", "")) and action.get("count", 0) is int and action.count >= 1 and action.count <= 200 and action.get("target", "") is String
		"upgrade", "repair", "spikes": return _valid_xy(action)
		"upgrade_all": return TOWERS.has(action.get("kind", ""))
		"streak": return STREAKS.has(action.get("kind", ""))
	return false


func _valid_xy(action: Dictionary) -> bool:
	return action.get("x", -1) is int and action.get("y", -1) is int and action.x >= 0 and action.x < BOARD_SIZE and action.y >= 0 and action.y < BOARD_SIZE


func _build_menu() -> void:
	game_started = false
	in_battle = false
	solo_mode = false
	learning_mode = false
	_set_music_track(false)
	if is_instance_valid(timer):
		timer.stop()
	for child in get_children():
		if child != music_player:
			child.queue_free()
	log_window = null
	log_window_view = null
	event_window_view = null
	preload("res://menu_ui.gd").build(self)

func _make_player(name: String) -> Dictionary:
	return {"name": name, "lives": 100, "money": float(START_CASH), "income": 0, "towers": [],
		"balloons": [], "incoming": [], "spikes": [], "streak": 0, "alive": true}


func _clean_name(name: String, fallback: String) -> String:
	var safe := name.replace("[", "").replace("]", "").strip_edges().left(18)
	return safe if safe != "" else fallback


func _start_match(preserve_names: bool = false) -> void:
	if network_role != "client" and is_instance_valid(match_mode_option):
		match_mode = "coop" if match_mode_option.selected == 1 else "duel"
	var online_name: String = players[1].name if network_role == "host" and players.size() == 2 else "Player 2"
	var first_name := _clean_name(players[0].name, "Player 1") if preserve_names and players.size() == 2 else _clean_name(host_name_field.text, "Player 1") if network_role == "host" else _clean_name(local_name_fields[0].text, "Player 1")
	var second_name := online_name if network_role == "host" else _clean_name(players[1].name, "Player 2") if preserve_names and players.size() == 2 else _clean_name(local_name_fields[1].text, "Player 2")
	players = [_make_player(first_name), _make_player(second_name)]
	if network_role == "host":
		players[1].name = online_name
	plans = [[], []]
	round_number = 1
	planning_player = 0
	ready_flags = [false, false]
	match_elapsed = 0.0
	timer_second = -1
	game_started = true
	_set_music_track(true)
	in_battle = false
	network_disconnected = false
	event_history.clear()
	event_serial = 0
	last_event_serial = 0
	pending_event_broadcast.clear()
	_build_game_ui()
	_refresh()
	_log("Round %d: write your plan, click RUN PLAN, then READY. Local players pass the keyboard; both plans resolve together." % round_number)
	_event_log("%s match started: %s and %s." % ["Co-op survival" if match_mode == "coop" else "Duel", players[0].name, players[1].name])
	_flush_event_log()
	code_editor.grab_focus()
	if learning_mode:
		course_view_index = completed_lessons
		call_deferred("_show_learning_course")


func _build_game_ui() -> void:
	log_history = ""
	for child in get_children():
		if child != music_player:
			child.queue_free()
	log_window = null
	log_window_view = null
	event_window_view = null
	_root_container()
	theme = preload("res://menu_ui.gd").make_theme(_make_theme())
	shell.add_theme_constant_override("separation", 12)
	_heading("TERMINUS-BATTLES  /  CODE DUEL", ("CO-OP SURVIVAL" if match_mode == "coop" else "1v1 DUEL") + "  •  CLASSIC MAP  •  Real GDScript  •  Click a tower for attack radius  •  ENTER runs + READY  •  F1 for help")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	player_label = Label.new()
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(player_label)
	round_label = Label.new()
	round_label.add_theme_color_override("font_color", Color("#69e3ab"))
	top.add_child(round_label)
	session_timer_label = Label.new()
	session_timer_label.add_theme_color_override("font_color", Color("#ffc75e"))
	top.add_child(session_timer_label)
	shell.add_child(top)
	board_row = HBoxContainer.new()
	board_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_row.add_theme_constant_override("separation", 18)
	shell.add_child(board_row)
	board_views.clear()
	for index in range(2):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_style(Color("#133044") if index == 0 else Color("#3d2250")))
		board_row.add_child(panel)
		var board_layout := VBoxContainer.new()
		board_layout.add_theme_constant_override("separation", 4)
		panel.add_child(board_layout)
		var board := BoardDisplay.new()
		board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.custom_minimum_size = Vector2(240, 240)
		board.size_flags_stretch_ratio = 1.0
		var zoom_controls := HBoxContainer.new()
		zoom_controls.alignment = BoxContainer.ALIGNMENT_END
		zoom_controls.add_theme_constant_override("separation", 5)
		board_layout.add_child(zoom_controls)
		var zoom_out := _button("−", func(): board.set_zoom(board.zoom_scale - 0.1))
		zoom_out.custom_minimum_size = Vector2(40, 30)
		zoom_controls.add_child(zoom_out)
		var zoom_readout := Label.new()
		zoom_readout.text = "100%"
		zoom_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zoom_readout.custom_minimum_size.x = 48
		zoom_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zoom_controls.add_child(zoom_readout)
		var zoom_in := _button("+", func(): board.set_zoom(board.zoom_scale + 0.1))
		zoom_in.custom_minimum_size = Vector2(40, 30)
		zoom_controls.add_child(zoom_in)
		zoom_controls.add_child(_button("FIT", func(): board.set_zoom(1.0)))
		board.zoom_changed.connect(func(percent: int): zoom_readout.text = "%d%%" % percent)
		var board_scroll := ScrollContainer.new()
		board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		board_layout.add_child(board_scroll)
		board_scroll.add_child(board)
		board_views.append(board)
	var lower := HBoxContainer.new()
	lower.custom_minimum_size.y = 252
	lower.add_theme_constant_override("separation", 16)
	shell.add_child(lower)
	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size.x = 345
	status_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color("#244a58")))
	lower.add_child(status_panel)
	status_view = RichTextLabel.new()
	status_view.bbcode_enabled = true
	status_view.custom_minimum_size.x = 310
	status_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_view.scroll_active = true
	status_panel.add_child(status_view)
	var command_panel := PanelContainer.new()
	command_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_panel.add_theme_stylebox_override("panel", _panel_style(Color("#244a58")))
	lower.add_child(command_panel)
	var command_body := VBoxContainer.new()
	command_body.add_theme_constant_override("separation", 8)
	command_panel.add_child(command_body)
	var controls_label := Label.new()
	controls_label.text = "COMMAND DECK"
	controls_label.add_theme_color_override("font_color", Color("#69e3ab"))
	controls_label.add_theme_font_size_override("font_size", 13)
	command_body.add_child(controls_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	command_body.add_child(actions)
	var run_button := _button("▶  RUN PLAN", _run_plan)
	run_button.add_theme_color_override("font_color", Color("#85e6be"))
	actions.add_child(run_button)
	var ready_button := _button("✓  READY", _ready_player)
	ready_button.add_theme_color_override("font_color", Color("#85e6be"))
	actions.add_child(ready_button)
	rematch_button = _button("REMATCH", _rematch)
	rematch_button.disabled = game_started
	actions.add_child(rematch_button)
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 7)
	command_body.add_child(tools_row)
	if learning_mode:
		course_status_label = Label.new()
		course_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		course_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		course_status_label.add_theme_color_override("font_color", Color("#85e6be"))
		tools_row.add_child(course_status_label)
		tools_row.add_child(_button("ACADEMY", _show_learning_course))
	tools_row.add_child(_button("HELP", _show_help))
	tools_row.add_child(_button("NOTEBOOK", _show_notebook))
	tools_row.add_child(_button("LIVE LOG", _show_logs))
	tools_row.add_child(_button("SETTINGS", _show_settings))
	tools_row.add_child(_button("MAIN MENU", _return_to_menu))
	var editor_label := Label.new()
	editor_label.text = "TURN SCRIPT  ·  WRITE GDSCRIPT, THEN RUN + READY"
	editor_label.add_theme_color_override("font_color", Color("#9ab4c7"))
	editor_label.add_theme_font_size_override("font_size", 12)
	command_body.add_child(editor_label)
	code_editor = TextEdit.new()
	code_editor.syntax_highlighter = _gdscript_highlighter()
	code_editor.placeholder_text = "# Real GDScript runs inside func run()\nfor x in range(3):\n    build(\"dart\", x, 1)\nsend(\"red\", 5)"
	code_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_editor.custom_minimum_size.y = 130
	code_editor.add_theme_constant_override("line_spacing", 3)
	command_body.add_child(code_editor)
	var feed_label := Label.new()
	feed_label.text = "BATTLE FEED"
	feed_label.add_theme_color_override("font_color", Color("#9ab4c7"))
	feed_label.add_theme_font_size_override("font_size", 12)
	command_body.add_child(feed_label)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.custom_minimum_size.y = 48
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_body.add_child(log_view)
	timer = Timer.new()
	timer.wait_time = 0.18
	timer.timeout.connect(_battle_tick)
	add_child(timer)
	_refresh()
	shell.modulate.a = 0.0
	shell.create_tween().tween_property(shell, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _panel_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b1727")
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.set_content_margin_all(9)
	return box


func _gdscript_highlighter() -> CodeHighlighter:
	var highlighter := CodeHighlighter.new()
	highlighter.number_color = Color("#ffc75e")
	highlighter.symbol_color = Color("#d4deed")
	highlighter.function_color = Color("#80d9e6")
	highlighter.member_variable_color = Color("#d49aff")
	highlighter.add_color_region("\"", "\"", Color("#a7e8b6"))
	highlighter.add_color_region("'", "'", Color("#a7e8b6"))
	highlighter.add_color_region("#", "", Color("#71859b"), true)
	for keyword in ["var", "const", "func", "if", "elif", "else", "for", "in", "while", "match", "and", "or", "not", "return", "pass", "break", "continue", "extends", "class", "enum", "signal", "await", "as", "is"]:
		highlighter.add_keyword_color(keyword, Color("#d49aff"))
	for keyword in ["true", "false", "null"]:
		highlighter.add_keyword_color(keyword, Color("#ffc75e"))
	for keyword in ["money", "lives", "round_number", "streak_count", "build", "send", "upgrade", "upgrade_all", "repair", "spikes", "streak", "nuke", "range"]:
		highlighter.add_keyword_color(keyword, Color("#80d9e6"))
	return highlighter


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and game_started:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1 and game_started:
		_show_help()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode not in [KEY_ENTER, KEY_KP_ENTER] or event.shift_pressed:
		return
	if not game_started or in_battle or not is_instance_valid(code_editor) or not code_editor.has_focus():
		return
	get_viewport().set_input_as_handled()
	var current_player := 1 if network_role == "client" else 0 if network_role == "host" else planning_player
	if current_player < 0 or ready_flags[current_player]:
		return
	if code_editor.text.strip_edges().is_empty():
		if not plans[current_player].is_empty():
			_ready_player()
		else:
			_log("Write a plan, then press ENTER to run it and READY. Use SHIFT+ENTER for a new line.")
		return
	var previous_action_count: int = plans[current_player].size()
	_run_plan()
	if plans[current_player].size() > previous_action_count:
		_ready_player()


func _run_plan() -> void:
	if not game_started or in_battle or planning_player < 0:
		return
	var local_index := 1 if network_role == "client" else (0 if network_role == "host" else planning_player)
	if ready_flags[local_index]:
		return
	var body := code_editor.text.strip_edges()
	if body.is_empty():
		_log("Write a GDScript plan first. Press HELP for examples.")
		return
	var submitted_body := body
	var expanded := _expand_notebook_calls(body)
	if not expanded.ok:
		_log("[color=#ff7474]%s[/color]" % expanded.error)
		return
	body = expanded.text
	body = _expand_notebook_aliases(body)
	var source := "extends \"res://game_plan_api.gd\"\n"
	for helper_method in expanded.get("methods", PackedStringArray()):
		source += _expand_notebook_aliases(helper_method) + "\n"
	source += "func run():\n"
	var source_lines := body.split("\n")
	for line_index in range(source_lines.size()):
		var line: String = source_lines[line_index]
		var statement := line.strip_edges()
		var is_block_header := statement.begins_with("for ") or statement.begins_with("if ") or statement.begins_with("elif ") or statement.begins_with("while ") or statement.begins_with("match ") or statement == "else" or statement == "else:"
		if is_block_header and not statement.ends_with(":"):
			_log("[color=#ff7474]Line %d: GDScript block headers need a colon. Example: for x in range(1, 10):[/color]" % (line_index + 1))
			return
		var indent := 0
		while indent < line.length() and line[indent] in [" ", "\t"]:
			indent += 1
		var levels := 0
		var spaces := 0
		for character in line.substr(0, indent):
			if character == "\t":
				levels += 1
				spaces = 0
			else:
				spaces += 1
				if spaces == 4:
					levels += 1
					spaces = 0
		source += "\t".repeat(1 + levels) + line.substr(indent) + "\n"
	var script := GDScript.new()
	script.source_code = source
	var compile_error := script.reload()
	if compile_error != OK:
		_log("[color=#ff7474]Plan not queued: GDScript could not compile (error %d). Check colons after for/if/else, parentheses, and indentation. Example: for x in range(1, 10):[/color]" % compile_error)
		return
	var runner = script.new()
	var plan_player := 1 if network_role == "client" else planning_player
	var resource_player := 0 if match_mode == "coop" else plan_player
	var player: Dictionary = players[resource_player]
	runner.money = player.money
	runner.lives = player.lives
	runner.round_number = round_number
	runner.streak_count = player.streak
	runner.run()
	var parsed: Array[Dictionary] = runner.actions
	for action in parsed:
		if not _valid_action(action):
			_log("[color=#ff7474]Invalid game action. Check its name, argument types, and coordinates.[/color]")
			return
	if match_mode == "coop" and parsed.any(func(item): return item.get("op") == "send"):
		_log("Co-op survival uses automatic incoming waves; remove send() from this plan.")
		return
	if parsed.is_empty():
		_log("No actions found. Add one game call per line.")
		return
	var current_player := plan_player
	var combined_plan: Array = plans[current_player].duplicate()
	combined_plan.append_array(parsed)
	var supply_queued: bool = players[resource_player].streak >= 3 and players[resource_player].money >= 250 and combined_plan.any(func(item): return item.get("op") == "streak" and item.get("kind") == "supply")
	for action in combined_plan:
		if action.get("op") == "send" and action.count > 100 and not supply_queued:
			_log("Send over 100 requires streak(\"supply\") in this plan and a 3-pop streak.")
			return
	if plans[current_player].size() + parsed.size() > 50:
		_log("A turn can contain at most 50 actions.")
		return
	var previous_count: int = plans[current_player].size()
	plans[current_player].append_array(parsed)
	var preview := _preview_money(current_player)
	if preview < -0.001:
		plans[current_player].resize(previous_count)
		_log("Plan cancelled: queued spending would exceed available cash. Nothing was charged.")
		_refresh()
		return
	if learning_mode:
		_check_course_challenge(submitted_body, body, parsed)
	_log("Queued %d action(s). Cash preview: $%.2f → $%.2f." % [parsed.size(), players[resource_player].money, preview])
	code_editor.clear()
	_refresh()


func _expand_notebook_aliases(source: String) -> String:
	var aliases: Dictionary = _notebook_aliases()
	if aliases.is_empty():
		return source
	var local_pattern := RegEx.create_from_string("^\\s*(?:var|const)\\s+([A-Za-z_][A-Za-z0-9_]*)|^\\s*for\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+in")
	for line in source.split("\n"):
		var declaration := local_pattern.search(line)
		if declaration != null:
			var local_name := declaration.get_string(1) if declaration.get_string(1) != "" else declaration.get_string(2)
			aliases.erase(local_name)
	var output := PackedStringArray()
	for line in source.split("\n"):
		var expanded := ""
		var index := 0
		var quote := ""
		var escaped := false
		while index < line.length():
			var character := line.substr(index, 1)
			if quote != "":
				expanded += character
				if escaped:
					escaped = false
				elif character == "\\":
					escaped = true
				elif character == quote:
					quote = ""
				index += 1
				continue
			if character in ["\"", "'"]:
				quote = character
				expanded += character
				index += 1
				continue
			if character == "#":
				expanded += line.substr(index)
				break
			if _is_identifier_start(character):
				var end := index + 1
				while end < line.length() and _is_identifier_part(line.substr(end, 1)):
					end += 1
				var word := line.substr(index, end - index)
				expanded += "\"%s\"" % str(aliases[word]).replace("\\", "\\\\").replace("\"", "\\\"") if aliases.has(word) else word
				index = end
				continue
			expanded += character
			index += 1
		output.append(expanded)
	return "\n".join(output)


func _is_identifier_start(character: String) -> bool:
	return character.length() == 1 and (character == "_" or character.to_lower() in "abcdefghijklmnopqrstuvwxyz")


func _is_identifier_part(character: String) -> bool:
	return _is_identifier_start(character) or (character.length() == 1 and character in "0123456789")


func _notebook_aliases() -> Dictionary:
	var aliases := {}
	var directory := DirAccess.open("user://notebooks/notes")
	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and file_name.ends_with(".txt"):
				var file := FileAccess.open("user://notebooks/notes/%s" % file_name, FileAccess.READ)
				if file != null:
					_parse_notebook_aliases(file.get_as_text(), aliases)
					file.close()
			file_name = directory.get_next()
		directory.list_dir_end()
	if is_instance_valid(notebook_editor):
		_parse_notebook_aliases(notebook_editor.text, aliases)
	return aliases


func _parse_notebook_aliases(note: String, aliases: Dictionary) -> void:
	var pattern := RegEx.create_from_string("^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*\"([^\"\\n]*)\"\\s*(?:#.*)?$")
	for line in note.split("\n"):
		var found := pattern.search(line)
		if found != null:
			var name := found.get_string(1)
			if name not in ["var", "const", "func", "if", "elif", "else", "for", "while", "match", "in", "as", "and", "or", "not", "true", "false", "null", "self", "super", "range", "money", "lives", "round_number", "streak_count", "build", "send", "upgrade", "upgrade_all", "repair", "spikes", "streak", "nuke"]:
				aliases[name] = found.get_string(2)


func _is_notebook_alias_definition(line: String) -> bool:
	return RegEx.create_from_string("^\\s*[A-Za-z_][A-Za-z0-9_]*\\s*=\\s*\"[^\"\\n]*\"\\s*(?:#.*)?$").search(line) != null


func _check_course_challenge(submitted: String, expanded: String, actions: Array[Dictionary]) -> void:
	if completed_lessons >= GDSCRIPT_COURSE.size():
		return
	var lesson: Dictionary = GDSCRIPT_COURSE[completed_lessons]
	var passed := false
	match lesson.goal:
		"build": passed = actions.any(func(action): return action.get("op") == "build")
		"alias":
			for name in _notebook_aliases():
				if submitted.contains("build(%s" % name) and actions.any(func(action): return action.get("op") == "build"):
					passed = true
					break
		"variable": passed = "var " in submitted and actions.any(func(action): return action.get("op") == "build")
		"condition": passed = "if " in submitted and not actions.is_empty()
		"loop": passed = "for " in submitted and actions.size() >= 2
		"array": passed = "[" in submitted and "for " in submitted and actions.size() >= 2
		"dictionary": passed = "{" in submitted and "[" in submitted and actions.any(func(action): return action.get("op") == "build")
		"notebook":
			var function_pattern := RegEx.create_from_string("^\\s*([A-Za-z_][A-Za-z0-9_]*)\\(\\)\\s*$")
			for line in submitted.split("\n"):
				var call := function_pattern.search(line)
				if call != null and FileAccess.file_exists("user://notebooks/%s.gd" % call.get_string(1)):
					passed = true
					break
		"state": passed = ["money", "lives", "round_number", "streak_count"].any(func(word): return word in submitted) and not actions.is_empty()
		"capstone": passed = "var " in submitted and "if " in submitted and "for " in submitted and actions.size() >= 2
	if not passed:
		return
	completed_lessons += 1
	course_view_index = completed_lessons
	var progress := ConfigFile.new()
	progress.set_value("course", "completed", completed_lessons)
	progress.save("user://learning_progress.cfg")
	_log("[color=#85e6be]Academy lesson complete: %s (%d/%d). Open ACADEMY for the next lesson.[/color]" % [lesson.title, completed_lessons, GDSCRIPT_COURSE.size()])
	_event_log("Academy lesson completed: %s." % lesson.title)
	_refresh_course_window()
	_refresh()


func _show_learning_course() -> void:
	if is_instance_valid(course_window):
		course_window.popup_centered()
		_refresh_course_window()
		return
	course_window = Window.new()
	course_window.title = "Terminus-Battles — GDScript Academy"
	course_window.size = Vector2i(700, 560)
	course_window.min_size = Vector2i(520, 420)
	course_window.transient = true
	course_window.always_on_top = true
	course_window.close_requested.connect(course_window.queue_free)
	add_child(course_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	course_window.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "GDSCRIPT ACADEMY"
	heading.add_theme_color_override("font_color", Color("#69e3ab"))
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)
	course_progress_label = Label.new()
	layout.add_child(course_progress_label)
	var lesson_scroll := ScrollContainer.new()
	lesson_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lesson_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(lesson_scroll)
	var lesson_content := VBoxContainer.new()
	lesson_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lesson_content.add_theme_constant_override("separation", 8)
	lesson_scroll.add_child(lesson_content)
	course_title_label = Label.new()
	course_title_label.add_theme_font_size_override("font_size", 20)
	course_title_label.add_theme_color_override("font_color", Color("#e0f6ee"))
	lesson_content.add_child(course_title_label)
	course_body_label = Label.new()
	course_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_content.add_child(course_body_label)
	var task_label := Label.new()
	task_label.text = "YOUR CHALLENGE"
	task_label.add_theme_color_override("font_color", Color("#ffc75e"))
	lesson_content.add_child(task_label)
	course_challenge_label = Label.new()
	course_challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_content.add_child(course_challenge_label)
	var hint_label := Label.new()
	hint_label.text = "HINT"
	hint_label.add_theme_color_override("font_color", Color("#80d9e6"))
	lesson_content.add_child(hint_label)
	course_hint_label = Label.new()
	course_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	course_hint_label.add_theme_color_override("font_color", Color("#a8bfcb"))
	lesson_content.add_child(course_hint_label)
	course_example_editor = TextEdit.new()
	course_example_editor.editable = false
	course_example_editor.syntax_highlighter = _gdscript_highlighter()
	course_example_editor.custom_minimum_size.y = 120
	lesson_content.add_child(course_example_editor)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	course_prev_button = _button("PREVIOUS", func():
		course_view_index = maxi(0, course_view_index - 1)
		_refresh_course_window()
	)
	actions.add_child(course_prev_button)
	actions.add_child(_button("INSERT EXAMPLE", _insert_course_example))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	course_next_button = _button("NEXT LESSON", func():
		if course_view_index < completed_lessons:
			course_view_index = mini(course_view_index + 1, completed_lessons)
			_refresh_course_window()
	)
	actions.add_child(course_next_button)
	actions.add_child(_button("CLOSE", course_window.queue_free))
	course_view_index = completed_lessons
	_refresh_course_window()
	course_window.popup_centered(Vector2i(700, 560))


func _refresh_course_window() -> void:
	if is_instance_valid(course_status_label):
		course_status_label.text = "COURSE COMPLETE" if completed_lessons >= GDSCRIPT_COURSE.size() else "LESSON %02d / %02d" % [completed_lessons + 1, GDSCRIPT_COURSE.size()]
	if not is_instance_valid(course_window):
		return
	if completed_lessons >= GDSCRIPT_COURSE.size() and course_view_index >= GDSCRIPT_COURSE.size():
		course_progress_label.text = "All 10 practical lessons completed. Keep experimenting in the planner."
		course_title_label.text = "Academy complete"
		course_body_label.text = "You have practiced GDScript values, conditions, loops, arrays, dictionaries, reusable plans, and game-state logic. The same language powers Godot scripts."
		course_challenge_label.text = "Write a strategy for the next wave."
		course_hint_label.text = "Try adapting a notebook function and protect your weakest lane."
		course_example_editor.text = "Build a strategy of your own, then use RUN PLAN and READY."
		course_prev_button.disabled = course_view_index <= 0
		course_next_button.disabled = true
		return
	course_view_index = clampi(course_view_index, 0, mini(completed_lessons, GDSCRIPT_COURSE.size() - 1))
	var lesson: Dictionary = GDSCRIPT_COURSE[course_view_index]
	course_progress_label.text = "LESSON %02d / %02d   ·   %d completed" % [course_view_index + 1, GDSCRIPT_COURSE.size(), completed_lessons]
	course_title_label.text = lesson.title
	course_body_label.text = lesson.lesson + "\n\nWrite the challenge in the planner and click RUN PLAN. A valid plan completes the lesson."
	course_challenge_label.text = lesson.challenge
	course_hint_label.text = lesson.hint
	course_example_editor.text = lesson.example
	course_prev_button.disabled = course_view_index <= 0
	course_next_button.disabled = course_view_index >= completed_lessons


func _insert_course_example() -> void:
	if not is_instance_valid(code_editor) or course_view_index >= GDSCRIPT_COURSE.size():
		return
	code_editor.text = course_example_editor.text
	if is_instance_valid(course_window):
		course_window.queue_free()
		course_window = null
	code_editor.grab_focus()


func _expand_notebook_calls(body: String, call_stack: Array[String] = []) -> Dictionary:
	if call_stack.size() >= 12:
		return {"ok": false, "error": "Notebook function calls are nested too deeply (limit 12)."}
	var call_pattern := RegEx.create_from_string("^([ \\t]*)([A-Za-z_][A-Za-z0-9_]*)\\(\\)[ \\t]*$")
	var expanded_lines := PackedStringArray()
	var helper_methods := PackedStringArray()
	for line in body.split("\n"):
		var match_result := call_pattern.search(line)
		if match_result == null:
			expanded_lines.append(line)
			continue
		var routine_name := match_result.get_string(2)
		var routine_path := "user://notebooks/%s.gd" % routine_name
		if not FileAccess.file_exists(routine_path):
			expanded_lines.append(line)
			continue
		if routine_name in call_stack:
			return {"ok": false, "error": "Notebook function '%s()' calls itself. Remove the recursive call." % routine_name}
		var file := FileAccess.open(routine_path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "Could not load notebook function '%s()' (error %d)." % [routine_name, FileAccess.get_open_error()]}
		var routine_body := file.get_as_text()
		file.close()
		var helper_method := _extract_notebook_method(routine_name, routine_body)
		if helper_method != "":
			helper_methods.append(helper_method)
			expanded_lines.append(line)
			continue
		var executable_lines := PackedStringArray()
		for routine_line in routine_body.split("\n"):
			if not _is_notebook_alias_definition(routine_line):
				executable_lines.append(routine_line)
		routine_body = "\n".join(executable_lines)
		var next_stack := call_stack.duplicate()
		next_stack.append(routine_name)
		var nested := _expand_notebook_calls(routine_body, next_stack)
		if not nested.ok:
			return nested
		helper_methods.append_array(nested.get("methods", PackedStringArray()))
		var caller_indent: String = match_result.get_string(1)
		for routine_line in nested.text.split("\n"):
			expanded_lines.append(caller_indent + routine_line if not routine_line.is_empty() else "")
	return {"ok": true, "text": "\n".join(expanded_lines), "methods": helper_methods}


func _extract_notebook_method(name: String, source: String) -> String:
	var method_header := RegEx.create_from_string("^func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(\\s*\\)\\s*:$")
	var lines := source.split("\n")
	for start in range(lines.size()):
		var header := method_header.search(lines[start].strip_edges())
		if header == null:
			continue
		if header.get_string(1) != name:
			return ""
		var method_lines := PackedStringArray(["func %s():" % name])
		var body_started := false
		for line_index in range(start + 1, lines.size()):
			var line: String = lines[line_index]
			if line.strip_edges().is_empty():
				if body_started:
					method_lines.append("")
				continue
			var indentation := 0
			while indentation < line.length() and line[indentation] in [" ", "\t"]:
				indentation += 1
			if indentation == 0:
				break
			body_started = true
			var levels := 0
			var spaces := 0
			for character in line.substr(0, indentation):
				if character == "\t":
					levels += 1
					spaces = 0
				else:
					spaces += 1
					if spaces == 4:
						levels += 1
						spaces = 0
			method_lines.append("\t".repeat(levels) + line.substr(indentation))
		return "\n".join(method_lines) if body_started else ""
	return ""


func _preview_money(player_index: int) -> float:
	var resource_player := 0 if match_mode == "coop" else player_index
	var cash: float = players[resource_player].money
	var simulated_towers: Array = players[resource_player].towers.duplicate(true)
	var queued: Array = plans[player_index].duplicate()
	if match_mode == "coop":
		queued = plans[0].duplicate()
		queued.append_array(plans[1])
	for action in queued:
		match action.op:
			"build":
				cash -= TOWERS[action.kind].cost
				simulated_towers.append({"kind": action.kind, "x": action.x, "y": action.y, "level": 1, "hp": TOWERS[action.kind].hp, "max_hp": TOWERS[action.kind].hp})
			"send": cash -= BALLOONS[action.kind].cost * action.count
			"upgrade":
				var tower: Dictionary = {}
				for candidate in simulated_towers:
					if candidate.x == action.x and candidate.y == action.y:
						tower = candidate
						break
				if not tower.is_empty() and tower.level < 3:
					cash -= int(75 * tower.level * (tower.level + 1) / 2)
					tower.level += 1
			"upgrade_all":
				for tower in simulated_towers:
					if tower.kind == action.kind and tower.level < 3:
						var cost: int = int(75 * tower.level * (tower.level + 1) / 2)
						if cash >= cost:
							cash -= cost
							tower.level += 1
			"repair":
					for tower in simulated_towers:
						if tower.x == action.x and tower.y == action.y and tower.hp < tower.max_hp:
							cash -= 40
							tower.hp = mini(tower.max_hp, tower.hp + 12)
							break
			"spikes": cash -= 50
			"streak":
				var item: Dictionary = STREAKS[action.kind]
				if players[resource_player].streak >= item.pops:
					cash += 500 - item.cost if action.kind == "supply" else -item.cost
	return cash


func _ready_player() -> void:
	if not game_started or in_battle:
		return
	if solo_mode and network_role == "offline":
		ready_flags = [true, true]
		_execute_plans()
		return
	if network_role == "client":
		if ready_flags[1]:
			return
		ready_flags[1] = true
		rpc_id(1, "submit_plan", plans[1])
		_log("READY sent. Waiting for %s to finish their plan." % players[0].name)
		_refresh()
		return
	if network_role == "host":
		if ready_flags[0]:
			return
		ready_flags[0] = true
		_log("READY. Waiting for %s." % (players[1].name if not ready_flags[1] else "the other plan"))
		if ready_flags[1]:
			_execute_plans()
		else:
			_refresh()
		return
	if planning_player < 0 or ready_flags[planning_player]:
		return
	var readied_player := planning_player
	ready_flags[readied_player] = true
	var other_player := 1 - readied_player
	if ready_flags[other_player]:
		planning_player = -1
		_log("Both players READY. Their plans resolve together.")
		_execute_plans()
		return
	planning_player = other_player
	_log("%s locked in. Pass the keyboard to %s; both plans resolve together after they READY." % [players[readied_player].name, players[other_player].name])
	_refresh()
	code_editor.grab_focus()


func _execute_plans() -> void:
	if network_role == "host" and not peer_ready:
		_log("[color=#ff7777]Plans not resolved: friend disconnected. Rejoin to continue this round.[/color]")
		return
	_queue_round_waves()
	var nuke_requested := false
	if round_number % 6 == 0:
		var randomizer := RandomNumberGenerator.new()
		randomizer.randomize()
		for index in range(1 if match_mode == "coop" else players.size()):
			var available: Array[String] = []
			for kind in BALLOONS:
				if round_number >= BALLOONS[kind].unlock:
					available.append(kind)
			var kind: String = available[randomizer.randi_range(0, available.size() - 1)]
			var count: int = randomizer.randi_range(3, 6)
			players[index].incoming.append({"kind": kind, "count": count})
			var wave_message := "Surprise wave: %d %s balloons sent to %s." % [count, kind, players[index].name]
			_log(wave_message)
			_event_log(wave_message)
	for index in range(2):
		var supply_owner := 0 if match_mode == "coop" else index
		var supply_available: bool = players[supply_owner].streak >= 3 and players[supply_owner].money >= 250 and plans[index].any(func(item): return item.get("op") == "streak" and item.get("kind") == "supply")
		var send_limit := 200 if supply_available else 100
		for action in plans[index]:
			if action.get("op") == "send" and action.count > send_limit:
				_log("P%d: send limit is %d; queue Supply Cache to send up to 200." % [index + 1, send_limit])
				continue
			var message := _apply_action(0 if match_mode == "coop" else index, action)
			if message.begins_with("Built "):
				_trigger_commander_voice(index, "build", "tower_built")
			elif action.op == "streak" and (message.begins_with("Supply Cache launched") or message.begins_with("Repair Drone restored") or message.begins_with("Nuke launched")):
				_trigger_commander_voice(index, "streak", "activated")
			if action.op == "streak" and action.kind == "nuke" and message.begins_with("Nuke launched"):
				nuke_requested = true
			_log("P%d: %s" % [index + 1, message])
			_event_log("P%d: %s" % [index + 1, message])
		if match_mode == "coop":
			players[1].money = players[0].money
			players[1].lives = players[0].lives
	if nuke_requested:
		for player in players:
			player.towers.clear()
			player.spikes.clear()
			player.incoming.clear()
			player.balloons.clear()
		await get_tree().create_timer(0.25).timeout
		if not game_started:
			return
		_refresh(true)
		await get_tree().create_timer(0.25).timeout
		_refresh(false)
	in_battle = true
	_event_log("Round %d resolution started." % round_number)
	tick_number = 0
	for index in range(2):
		plans[index].clear()
	ready_flags = [false, false]
	timer.start()
	_refresh()
	_flush_event_log()


func _queue_round_waves() -> void:
	var board_count := 1 if match_mode == "coop" else 2
	for index in range(board_count):
		var waves: Array[Dictionary] = [{"kind": "red", "count": 4 + round_number}]
		if round_number >= 3:
			waves.append({"kind": "blue", "count": maxi(1, floori(float(round_number) / 3.0))})
		if round_number >= 5:
			waves.append({"kind": "green", "count": maxi(1, floori(float(round_number) / 5.0))})
		if round_number >= 8:
			waves.append({"kind": "yellow", "count": maxi(1, floori(float(round_number) / 8.0))})
		if round_number >= 12:
			waves.append({"kind": "moab", "count": maxi(1, floori(float(round_number) / 12.0))})
		for wave in waves:
			players[index].incoming.append(wave.duplicate())
		var summary := PackedStringArray()
		for wave in waves:
			summary.append("%d %s" % [wave.count, wave.kind])
		var label: String = "team" if match_mode == "coop" else players[index].name
		var message := "Round %d auto-wave for %s: %s." % [round_number, label, ", ".join(summary)]
		_log(message)
		_event_log(message)


func _apply_action(index: int, action: Dictionary) -> String:
	var player: Dictionary = players[index]
	var other: Dictionary = players[1 - index]
	match action.op:
		"build":
			var point := Vector2i(action.x, action.y)
			if point.x < 0 or point.x >= BOARD_SIZE or point.y < 0 or point.y >= BOARD_SIZE:
				return "Coordinates must be 0–9."
			if point in PATH:
				return "Towers cannot be built on the path."
			if action.kind == "sub" and point not in WATER_TILES:
				return "Submarines must be placed on a water tile (≈)."
			if action.kind != "sub" and point in WATER_TILES:
				return "Only a Submarine can be placed on water tiles (≈)."
			if not _tower_at(index, point.x, point.y).is_empty():
				return "A tower already occupies that cell."
			var data: Dictionary = TOWERS[action.kind]
			if player.money < data.cost:
				return "Need $%d; have $%.2f." % [data.cost, player.money]
			player.money -= data.cost
			var tower := {"kind": action.kind, "x": point.x, "y": point.y, "level": 1,
				"hp": data.hp, "max_hp": data.hp, "cooldown": 0, "shot_timer": 0, "shot_target": point}
			player.towers.append(tower)
			return "Built %s at %s for $%d." % [action.kind, point, data.cost]
		"send":
			if match_mode == "coop":
				return "Co-op survival uses automatic waves; send() is disabled."
			var target_index := 1 - index
			if action.target != "":
				var target := str(action.target).to_lower()
				if target in ["p1", players[0].name.to_lower()]:
					target_index = 0
				elif target in ["p2", players[1].name.to_lower()]:
					target_index = 1
				if target_index == index:
					return "Choose your rival as the target."
			var data: Dictionary = BALLOONS[action.kind]
			var cost: int = data.cost * action.count
			if player.money < cost:
				return "Need $%d to send; have $%.2f." % [cost, player.money]
			player.money -= cost
			players[target_index].incoming.append({"kind": action.kind, "count": action.count})
			player.income += maxi(1, int(action.count / 2))
			return "Sent %d %s balloon(s) to %s." % [action.count, action.kind, players[target_index].name]
		"upgrade":
			var tower := _tower_at(index, action.x, action.y)
			return _upgrade_tower(player, tower)
		"upgrade_all":
			var upgraded := 0
			for tower in player.towers:
				if tower.kind == action.kind:
					var result := _upgrade_tower(player, tower)
					if result.begins_with("Upgraded"):
						upgraded += 1
			return "Upgraded %d %s tower(s) where affordable." % [upgraded, action.kind]
		"repair":
			var tower := _tower_at(index, action.x, action.y)
			if tower.is_empty():
				return "No tower at (%d, %d)." % [action.x, action.y]
			if player.money < 40:
				return "Need $40 to repair."
			var healed: int = mini(12, tower.max_hp - tower.hp)
			if healed <= 0:
				return "That tower is already at full health."
			tower.hp += healed
			player.money -= 40
			return "Repaired tower (+%d HP)." % healed
		"spikes":
			var point := Vector2i(action.x, action.y)
			if point not in PATH or player.money < 50:
				return "Spikes need a path coordinate and $50."
			for spike in player.spikes:
				if spike.point == point:
					return "There are already spikes on that tile."
			player.money -= 50
			var hp := 50 if round_number > 10 else 25
			player.spikes.append({"point": point, "hp": hp, "max_hp": hp})
			return "Placed spikes at %s (%d HP)." % [point, hp]
		"streak":
			var data: Dictionary = STREAKS[action.kind]
			if player.streak < data.pops:
				return "%s needs %d consecutive pops." % [action.kind, data.pops]
			if action.kind == "supply":
				if player.money < data.cost:
					return "Supply Cache costs $%d." % data.cost
				player.money += 500 - data.cost
				player.streak = 0
				return "Supply Cache launched; sent $500."
			if action.kind == "repair":
				if player.money < data.cost:
					return "Repair Drone costs $%d." % data.cost
				player.money -= data.cost
				for tower in player.towers:
					tower.hp = mini(tower.max_hp, tower.hp + 20)
				player.streak = 0
				return "Repair Drone restored up to 20 HP per tower."
			if player.money < data.cost:
				return "Nuke costs $%d." % data.cost
			player.money -= data.cost
			player.streak = 0
			return "Nuke launched; all boards will be wiped."
	return "Unknown action."


func _upgrade_tower(player: Dictionary, tower: Dictionary) -> String:
	if tower.is_empty():
		return "No tower at those coordinates."
	if tower.level >= 3:
		return "Tower is already level 3."
	var cost: int = int(75 * tower.level * (tower.level + 1) / 2)
	if player.money < cost:
		return "Need $%d to upgrade." % cost
	player.money -= cost
	tower.level += 1
	tower.max_hp += 8
	tower.hp = mini(tower.max_hp, tower.hp + 8)
	return "Upgraded %s to level %d." % [tower.kind, tower.level]


func _tower_at(index: int, x: int, y: int) -> Dictionary:
	for tower in players[index].towers:
		if tower.x == x and tower.y == y:
			return tower
	return {}


func _battle_tick() -> void:
	if not in_battle or network_role == "client":
		timer.stop()
		return
	if network_role == "host" and not peer_ready:
		timer.stop()
		return
	tick_number += 1
	for index in range(1 if match_mode == "coop" else 2):
		var player: Dictionary = players[index]
		if not player.incoming.is_empty():
			var wave: Dictionary = player.incoming[0]
			var kind: String = wave.kind
			var health: int = BALLOONS[kind].hp + floori(float(round_number) / 5.0) * 5
			player.balloons.append({"kind": kind, "health": health, "path": 0, "cooldown": 0})
			_event_log("%s received a %s balloon (%d HP)." % [player.name, kind, health])
			wave.count -= 1
			if wave.count <= 0:
				player.incoming.pop_front()
		for tower in player.towers:
			tower.cooldown = maxi(0, tower.cooldown - 1)
			tower.shot_timer = maxi(0, int(tower.get("shot_timer", 0)) - 1)
			if tower.kind == "medic":
				if tick_number % 2 == 0:
					for target in player.towers:
						if target.hp < target.max_hp and _distance(tower, target) <= _tower_range(tower):
							var healed: int = mini(2 + tower.level - 1, target.max_hp - target.hp)
							target.hp = mini(target.max_hp, target.hp + 2 + tower.level - 1)
							_event_log("%s Medic healed %s at (%d,%d) for %d HP." % [player.name, target.kind, target.x, target.y, healed])
							break
				continue
			if tower.kind == "farm" or tower.cooldown > 0:
				continue
			var candidates: Array[Dictionary] = []
			for balloon in player.balloons:
				if balloon.health > 0 and _distance(tower, {"x": PATH[mini(balloon.path, PATH.size() - 1)].x,
					"y": PATH[mini(balloon.path, PATH.size() - 1)].y}) <= _tower_range(tower):
					candidates.append(balloon)
			candidates.sort_custom(func(a, b): return a.path > b.path)
			var hit_count: int = mini(TOWERS[tower.kind].pierce, candidates.size())
			if hit_count > 0:
				var shot_damage: int = int((TOWERS[tower.kind].damage + 2 * (tower.level - 1)) * (1.0 + 0.05 * (round_number - 1)) + 0.5)
				tower.shot_timer = 2
				tower.shot_target = PATH[mini(candidates[0].path, PATH.size() - 1)]
				for target_index in range(hit_count):
					var target: Dictionary = candidates[target_index]
					if tower.kind == "bomb":
						var target_point: Vector2i = PATH[mini(target.path, PATH.size() - 1)]
						for nearby in player.balloons:
							var nearby_point: Vector2i = PATH[mini(nearby.path, PATH.size() - 1)]
							if nearby.health > 0 and _distance({"x": target_point.x, "y": target_point.y}, {"x": nearby_point.x, "y": nearby_point.y}) <= TOWERS.bomb.splash:
								_damage_balloon(player, nearby, shot_damage, tower.kind)
					else:
						_damage_balloon(player, target, shot_damage, tower.kind)
				tower.cooldown = TOWERS[tower.kind].rate
		for balloon in player.balloons:
			if balloon.health <= 0:
				continue
			var old_path: int = balloon.path
			balloon.path += BALLOONS[balloon.kind].speed
			if balloon.path >= PATH.size():
				var leaked_hp: int = maxi(0, balloon.health)
				player.lives -= leaked_hp
				_event_log("%s leaked a %s with %d HP remaining and lost %d lives (now %d)." % [player.name, balloon.kind, leaked_hp, leaked_hp, player.lives])
				player.streak = 0
				balloon.health = 0
				continue
			var spike: Dictionary = _spike_crossed(player, old_path, balloon.path)
			if not spike.is_empty():
				_damage_balloon(player, balloon, 10, "Road spikes")
				var spike_bite: int = BALLOONS[balloon.kind].bite
				if balloon.kind != "moab":
					spike_bite += floori(float(round_number) / 4.0)
				spike.hp -= spike_bite
				_event_log("%s %s crossed spikes: balloon -10 HP, spikes -%d HP (%d left)." % [player.name, balloon.kind, spike_bite, maxi(0, spike.hp)])
				if spike.hp <= 0:
					_event_log("%s road spikes at %s were destroyed." % [player.name, spike.point])
					player.spikes.erase(spike)
			if balloon.health > 0:
				balloon.cooldown = maxi(0, balloon.cooldown - 1)
				if balloon.cooldown == 0:
					var target_tower: Dictionary = _tower_targeted(player, balloon)
					if not target_tower.is_empty():
						var bite: int = BALLOONS[balloon.kind].bite
						if balloon.kind != "moab":
							bite += floori(float(round_number) / 4.0)
						target_tower.hp -= bite
						_event_log("%s %s bit %s tower at (%d,%d) for %d damage (%d/%d HP)." % [player.name, balloon.kind, target_tower.kind, target_tower.x, target_tower.y, bite, maxi(0, target_tower.hp), target_tower.max_hp])
						balloon.cooldown = 3
						if target_tower.hp <= 0:
							_event_log("%s %s tower at (%d,%d) was destroyed." % [player.name, target_tower.kind, target_tower.x, target_tower.y])
							player.towers.erase(target_tower)
		var survivors: Array[Dictionary] = []
		for balloon in player.balloons:
			if balloon.health > 0:
				survivors.append(balloon)
		player.balloons = survivors
	if match_mode == "coop":
		players[1].money = players[0].money
		players[1].lives = players[0].lives
	if _battle_finished():
		timer.stop()
		_end_round()
	else:
		_refresh()
	_flush_event_log()


func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


func _tower_range(tower: Dictionary) -> float:
	return TOWERS[tower.kind].range + 0.5 * (tower.level - 1)


func _damage_balloon(player: Dictionary, balloon: Dictionary, damage: int, source: String = "Tower") -> void:
	var previous_health: int = balloon.health
	balloon.health -= damage
	_event_log("%s %s hit %s balloon for %d damage (%d → %d HP)." % [player.name, source, balloon.kind, damage, previous_health, maxi(0, balloon.health)])
	if balloon.health <= 0:
		var reward: float = BALLOONS[balloon.kind].reward
		player.money += reward
		player.streak += 1
		_event_log("%s popped %s and earned $%.2f (pop streak %d)." % [player.name, balloon.kind, reward, player.streak])


func _spike_crossed(player: Dictionary, old_path: int, new_path: int) -> Dictionary:
	for spike in player.spikes:
		var path_index := PATH.find(spike.point)
		if old_path < path_index and path_index <= new_path:
			return spike
	return {}


func _tower_targeted(player: Dictionary, balloon: Dictionary) -> Dictionary:
	var point: Vector2i = PATH[mini(balloon.path, PATH.size() - 1)]
	var farms: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for tower in player.towers:
		if _distance(tower, {"x": point.x, "y": point.y}) <= 1.5:
			if tower.kind == "farm":
				farms.append(tower)
			else:
				others.append(tower)
	if not farms.is_empty():
		return farms[0]
	return others[0] if not others.is_empty() else {}


func _battle_finished() -> bool:
	for player in players.slice(0, 1 if match_mode == "coop" else 2):
		if not player.incoming.is_empty() or not player.balloons.is_empty():
			return false
	return true


func _end_round() -> void:
	for index in range(1 if match_mode == "coop" else 2):
		var player: Dictionary = players[index]
		var income_paid: int = _round_income(index)
		var money_before: float = player.money
		player.money += income_paid
		_event_log("%s collected $%d round income ($%.2f → $%.2f)." % [player.name, income_paid, money_before, player.money])
		if round_number >= 10:
			for spike in player.spikes:
				if spike.max_hp < 50:
					spike.hp = mini(50, spike.hp + 25)
					spike.max_hp = 50
	if match_mode == "coop":
		players[1].money = players[0].money
		players[1].lives = players[0].lives
	if players[0].lives <= 0 or (match_mode != "coop" and players[1].lives <= 0):
		game_started = false
		var winner: String = "Both players survived together" if match_mode == "coop" else "Draw" if players[0].lives <= 0 and players[1].lives <= 0 else players[0].name if players[0].lives > 0 else players[1].name
		if match_mode == "coop":
			for commander_index in range(mini(players.size(), MAX_COMMANDERS)):
				_trigger_commander_voice(commander_index, "match_result", "defeat")
		else:
			for commander_index in range(mini(players.size(), MAX_COMMANDERS)):
				var result_line := "defeat" if players[commander_index].lives <= 0 else "victory"
				_trigger_commander_voice(commander_index, "match_result", result_line)
		_log("[color=#ffce70]GAME OVER — %s. Press REMATCH or MAIN MENU.[/color]" % ("Co-op team defeated" if match_mode == "coop" else winner))
		_event_log("Game over: %s." % ("Co-op team defeated" if match_mode == "coop" else winner))
		_refresh()
		return
	round_number += 1
	planning_player = 0
	plans = [[], []]
	ready_flags = [false, false]
	in_battle = false
	_log("Round %d complete. Income paid. Both players can plan the next round; plans resolve together after both READY." % (round_number - 1))
	_event_log("Round %d completed." % (round_number - 1))
	if (round_number + 1) % 6 == 0:
		var warning := "Warning: random balloon waves will arrive for both players in round %d." % (round_number + 1)
		_log("[color=#ffc75e]%s[/color]" % warning)
		_event_log(warning)
	_refresh()
	code_editor.grab_focus()


func _round_income(index: int) -> int:
	var player: Dictionary = players[0] if match_mode == "coop" else players[index]
	var total := ROUND_INCOME + int(player.income)
	for tower in player.towers:
		if tower.kind == "farm":
			total += 60 + (tower.level - 1) * 15
	return total


func _refresh(nuke_flash: bool = false) -> void:
	if board_views.is_empty():
		return
	player_label.text = "PLANNING: %s" % ("BATTLE RUNNING" if in_battle else (players[planning_player].name if planning_player >= 0 else "RESOLVING"))
	round_label.text = "ROUND %02d" % round_number
	_update_session_timer()
	for index in range(2):
		var board_index := 0 if match_mode == "coop" else index
		var ranges := {}
		for tower in players[board_index].towers:
			ranges[Vector2i(tower.x, tower.y)] = _tower_range(tower)
		board_views[index].show_board(players[board_index], PATH, WATER_TILES, ranges, index, nuke_flash, match_mode == "coop")
	status_view.text = _status_text()
	if is_instance_valid(rematch_button):
		rematch_button.disabled = game_started or (network_role != "offline" and network_disconnected)
	if learning_mode:
		_refresh_course_window()
	code_editor.editable = game_started and not in_battle and planning_player >= 0
	if network_role == "client":
		code_editor.editable = game_started and not in_battle and not ready_flags[1]
		player_label.text = "ONLINE: %s" % ("CONNECTION LOST — REJOIN HOST" if network_disconnected else "MATCH OVER — MAIN MENU" if not game_started else "BATTLE RUNNING" if in_battle else "READY — WAITING FOR HOST" if ready_flags[1] else "YOUR PLAN (P2)")
	if network_role == "host":
		var host_turn_status := "CONNECTION LOST — BATTLE PAUSED" if network_disconnected else "MATCH OVER — MAIN MENU" if not game_started else "BATTLE RUNNING" if in_battle else "READY — WAITING FOR %s" % players[1].name if ready_flags[0] else "%s READY — WAITING FOR YOU" % players[1].name if ready_flags[1] else "YOUR PLAN (P1)"
		player_label.text = "ONLINE: %s" % host_turn_status
		code_editor.editable = game_started and not in_battle and not ready_flags[0]
		_send_state()


func _board_text(index: int, nuke_flash: bool) -> String:
	var player: Dictionary = players[index]
	var color := "#68d8e8" if index == 0 else "#df78ed"
	var title := "P%d // %s" % [index + 1, player.name]
	var text := "[center][color=%s][b]%s[/b][/color][/center]\n" % [color, title]
	text += "[color=#8aa0bd]   0 1 2 3 4 5 6 7 8 9[/color]\n"
	for y in range(BOARD_SIZE):
		text += "[color=#8aa0bd]%d [/color]" % y
		for x in range(BOARD_SIZE):
			var point := Vector2i(x, y)
			var symbol := "·"
			var ink := "#263b53"
			if point in PATH:
				symbol = "▶" if point == PATH[0] else "◎" if point == PATH[-1] else "·"
				ink = "#ffc75e"
			for tower in player.towers:
				if tower.x == x and tower.y == y:
					symbol = {"dart":"D", "tack":"T", "sniper":"S", "bomb":"B", "farm":"$", "medic":"+", "sub":"U"}[tower.kind]
					ink = {"dart":"#61d9e8", "tack":"#ef78da", "sniper":"#7b9eff", "bomb":"#ff7878", "farm":"#75e6a9", "medic":"#75e6a9", "sub":"#70c9ff"}[tower.kind]
			for spike in player.spikes:
				if spike.point == point:
					symbol = "^"
					ink = "#ffc75e"
			for balloon in player.balloons:
				if balloon.health > 0 and PATH[mini(balloon.path, PATH.size() - 1)] == point:
					symbol = "M" if balloon.kind == "moab" else balloon.kind[0]
					ink = {"red":"#ff7777", "blue":"#70baff", "green":"#75e6a9", "yellow":"#ffc75e", "moab":"#df78ed"}[balloon.kind]
			if nuke_flash:
				symbol = "X" if x % 2 == 0 else "*"
				ink = "#ff7777" if y % 2 == 0 else "#ffc75e"
			text += "[color=%s]%s [/color]" % [ink, symbol]
		text += "\n"
	text += "\n[color=#8aa0bd]Incoming: %d  |  Active: %d[/color]" % [player.incoming.size(), player.balloons.size()]
	return text


func _status_text() -> String:
	var text := "[color=#69e3ab][b]MATCH STATUS[/b][/color]\n"
	if match_mode == "coop":
		var team: Dictionary = players[0]
		text += "\n[color=#69e3ab]CO-OP TEAM[/color]  ♥ %d  Cash $%.2f  +$%d/r\n" % [team.lives, team.money, _round_income(0)]
		text += "Shared towers %d  |  Pop streak %d\n" % [team.towers.size(), team.streak]
		if not plans[0].is_empty() or not plans[1].is_empty():
			text += "[color=#ffc75e]Shared plan cash: $%.2f → $%.2f[/color]\n" % [team.money, _preview_money(0)]
		for tower in team.towers.slice(0, 8):
			var bar := "█".repeat(maxi(0, int(8.0 * tower.hp / tower.max_hp)))
			text += "%s L%d (%d,%d) %s %d/%d HP\n" % [tower.kind[0].to_upper(), tower.level, tower.x, tower.y, bar, tower.hp, tower.max_hp]
		text += "Incoming %d  |  Active %d\n" % [team.incoming.size(), team.balloons.size()]
	else:
		for index in range(players.size()):
			var player: Dictionary = players[index]
			text += "\n[color=%s]%s[/color]  ♥ %d  Cash $%.2f  +$%d/r\n" % ["#68d8e8" if index == 0 else "#df78ed", player.name, player.lives, player.money, _round_income(index)]
			if not plans[index].is_empty():
				text += "[color=#ffc75e]Plan queued: $%.2f → $%.2f after READY[/color]\n" % [player.money, _preview_money(index)]
			text += "Towers %d  |  Pop streak %d\n" % [player.towers.size(), player.streak]
			for tower in player.towers.slice(0, 5):
				var bar := "█".repeat(maxi(0, int(8.0 * tower.hp / tower.max_hp)))
				text += "%s L%d (%d,%d) %s %d/%d HP\n" % [tower.kind[0].to_upper(), tower.level, tower.x, tower.y, bar, tower.hp, tower.max_hp]
			if player.towers.size() > 5:
				text += "… +%d towers\n" % (player.towers.size() - 5)
	text += "\n[color=#8aa0bd]Queued: P1 %d actions | P2 %d actions[/color]" % [plans[0].size(), plans[1].size()]
	return text


func _log(message: String) -> void:
	log_history += message + "\n"
	var lines := log_history.split("\n")
	if lines.size() > 501:
		log_history = "\n".join(lines.slice(lines.size() - 501))
	if is_instance_valid(log_view):
		log_view.append_text(message + "\n")
		log_view.scroll_to_line(log_view.get_line_count())
	if is_instance_valid(log_window_view):
		log_window_view.append_text(message + "\n")
		log_window_view.scroll_to_line(log_window_view.get_line_count())


func _event_log(message: String) -> void:
	var total := floori(match_elapsed)
	var entry := "[R%02d %02d:%02d] %s" % [round_number, int(total / 60), total % 60, message]
	event_serial += 1
	_record_event(entry)
	pending_event_broadcast.append({"serial": event_serial, "entry": entry})


func _flush_event_log() -> void:
	if pending_event_broadcast.is_empty():
		return
	if network_role == "host" and peer_ready:
		rpc("receive_events", pending_event_broadcast.duplicate(true))
	pending_event_broadcast.clear()


func _record_event(entry: String) -> void:
	event_history.append(entry)
	if event_history.size() > 1200:
		event_history.pop_front()
	if is_instance_valid(event_window_view):
		event_window_view.append_text(entry + "\n")
		event_window_view.scroll_to_line(event_window_view.get_line_count())


@rpc("authority", "call_remote", "reliable")
func receive_events(events: Array) -> void:
	if network_role != "client":
		return
	for item in events:
		if not item is Dictionary:
			continue
		var serial: int = item.get("serial", 0)
		if serial <= last_event_serial:
			continue
		last_event_serial = serial
		_record_event(str(item.get("entry", "")))


func _show_logs() -> void:
	if is_instance_valid(log_window):
		log_window.grab_focus()
		return
	log_window = Window.new()
	log_window.title = "Terminus-Battles — Live Match Log"
	log_window.size = Vector2i(820, 520)
	log_window.min_size = Vector2i(560, 360)
	log_window.transient = true
	log_window.always_on_top = true
	log_window.close_requested.connect(func():
		log_window.queue_free()
		log_window = null
		log_window_view = null
		event_window_view = null
	)
	add_child(log_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	log_window.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var match_tab := VBoxContainer.new()
	match_tab.name = "Match Log"
	tabs.add_child(match_tab)
	var heading := Label.new()
	heading.text = "TURN STATUS, PLANS, AND CONNECTIONS"
	heading.add_theme_color_override("font_color", Color("#69e3ab"))
	match_tab.add_child(heading)
	log_window_view = RichTextLabel.new()
	log_window_view.bbcode_enabled = true
	log_window_view.scroll_active = true
	log_window_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_tab.add_child(log_window_view)
	log_window_view.append_text(log_history)
	log_window_view.scroll_to_line(log_window_view.get_line_count())
	var event_tab := VBoxContainer.new()
	event_tab.name = "Battle Events"
	tabs.add_child(event_tab)
	var event_heading := Label.new()
	event_heading.text = "POPS, LEAKS, DAMAGE, WAVES, AND INCOME"
	event_heading.add_theme_color_override("font_color", Color("#ffc75e"))
	event_tab.add_child(event_heading)
	event_window_view = RichTextLabel.new()
	event_window_view.scroll_active = true
	event_window_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_tab.add_child(event_window_view)
	for entry in event_history:
		event_window_view.append_text(entry + "\n")
	event_window_view.scroll_to_line(event_window_view.get_line_count())
	layout.add_child(_button("CLOSE LOG", func():
		log_window.queue_free()
		log_window = null
		log_window_view = null
		event_window_view = null
	))
	log_window.popup_centered(Vector2i(820, 520))


func _show_help() -> void:
	if is_instance_valid(help_window):
		help_window.grab_focus()
		return
	help_window = Window.new()
	help_window.title = "Terminus-Battles — Quick Guide"
	help_window.size = Vector2i(760, 700)
	help_window.min_size = Vector2i(540, 460)
	help_window.transient = true
	help_window.always_on_top = true
	help_window.close_requested.connect(help_window.queue_free)
	add_child(help_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	help_window.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "HOW TO PLAY + GDSCRIPT HINTS"
	heading.add_theme_color_override("font_color", Color("#69e3ab"))
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)
	var guide := RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.text = "[color=#68d8e8][b]YOUR TURN — THE SHORT VERSION[/b][/color]\n1. Write GDScript in the game editor.\n2. Click [b]RUN PLAN[/b] to check and queue the actions. Fix any error it reports.\n3. Click [b]READY[/b] when your plan is finished. Both players lock in their plans; the host then runs the turn on both synchronized boards. In local play, pass the keyboard when prompted.\n\n[color=#68d8e8][b]A FIRST PROGRAM[/b][/color]\n[code]build(\"dart\", 4, 3)\nsend(\"red\", 5)[/code]\nThis builds a Dart tower at column 4, row 3, then queues five red balloons to send to your rival. Coordinates go from 0 to 9. Towers cannot be placed on the road.\n\n[color=#68d8e8][b]USE A LOOP TO REPEAT ACTIONS[/b][/color]\n[code]for x in range(3):\n    build(\"dart\", x, 1)[/code]\n[code]range(3)[/code] gives 0, 1, and 2. The indented line runs once for each value of [code]x[/code]. Four spaces make one indentation level.\n\n[color=#68d8e8][b]USE A VARIABLE AND A CONDITION[/b][/color]\n[code]var row = 1\nif money >= 180:\n    build(\"tack\", 4, row)[/code]\n[code]var[/code] stores a value under a name. [code]if[/code] runs its indented action only when the condition is true. Useful values: [code]money[/code], [code]lives[/code], [code]round_number[/code], and [code]streak_count[/code].\n\n[color=#68d8e8][b]GAME ACTIONS[/b][/color]\n[code]build(\"dart\", x, y)\nsend(\"blue\", 10)\nupgrade(x, y)\nupgrade_all(\"dart\")\nrepair(x, y)\nspikes(x, y)\nstreak(\"supply\")\nnuke()[/code]\nTower names: [code]dart[/code], [code]tack[/code], [code]sniper[/code], [code]bomb[/code], [code]farm[/code], [code]medic[/code]. Balloon names: [code]red[/code], [code]blue[/code], [code]green[/code], [code]yellow[/code], [code]moab[/code].\n\n[color=#68d8e8][b]WHAT THE TOWERS DO[/b][/color]\nDart: basic single target. Tack: hits several nearby balloons. Sniper: long-range single target. Bomb: heavy damage. Farm: earns extra cash each round. Medic: repairs nearby towers.\n\n[color=#68d8e8][b]ONLINE MATCH HINT[/b][/color]\nHost clicks HOST GAME and sends their public IP to the friend. Friend enters that IP and a name, then clicks JOIN HOST. Once connected, both write code, click RUN PLAN, and click READY. If joining fails across houses, the host may need to allow UDP port 24680 through their firewall/router.\n\n[color=#8aa0bd]More rules: balloon HP rises every 5 rounds. Normal sends cap at 100; Supply Cache raises it to 200. Close this guide with the X or button below; it will not add text to the match log.[/color]"
	guide.text += "\n\n[color=#68d8e8][b]THE GOAL, ECONOMY & ROUND FLOW[/b][/color]\nProtect your 100 lives and send balloons down your rival's path. The match ends when a player's lives reach zero. Each player starts with $400, receives $50 at the end of each round, and earns extra round income from Farms and balloon sends. Sending adds max(1, count / 2) income per round. Plans stay queued until both players press READY; then the host resolves both plans and synchronizes the battle animation. In local play, pass the keyboard when asked. The SESSION clock above the boards shows elapsed match time.\n\n[color=#68d8e8][b]COMPLETE TOWER STATS — BASE LEVEL[/b][/color]\n[code]Dart    $100  range 3  damage 2  rate 1 tick  DPS 2.0  HP 30  one target\nTack    $180  range 2  damage 2  rate 2 ticks DPS 1.0  HP 28  up to 3 targets\nSniper  $300  range 99 damage 12 rate 3 ticks DPS 4.0  HP 26  one target\nBomb    $260  range 3  damage 5  rate 3 ticks DPS 1.7  HP 38  splash radius 1.6\nFarm    $200  no attack                         HP 22  earns $60/round\nMedic   $280  range 3  heals 2 every 2 ticks   HP 32\nSub     $320  water-only range 4 damage 8 every 2 ticks  HP 36[/code]\nRange is measured in map-tile distance. DPS here means damage divided by the listed simulation-tick rate; towers' damage then scales +5% per round. Tack can hit up to three balloons in range. Bomb hits balloons near its target. Farms attract balloon attacks.\n\n[color=#68d8e8][b]UPGRADE PRICES & EFFECTS[/b][/color]\nEvery tower type uses the same cumulative upgrade prices: [b]level 1 → 2 costs $75; level 2 → 3 costs $225; both upgrades total $300.[/b] A tower can reach level 3. Each level adds 8 current and maximum HP, +2 damage for attacking towers, and +0.5 range. Farm instead earns +$15 per round for each level. Medic instead heals +1 HP per pulse for each level. Upgrade prices are paid when turns resolve. [code]upgrade(x, y)[/code] upgrades one tower; [code]upgrade_all(\"dart\")[/code] upgrades each affordable Dart once.\n\n[color=#68d8e8][b]RANGE EXAMPLE[/b][/color]\n[code]···#···\n·#####·\n·#####·\n###D###\n·#####·\n·#####·\n···#···[/code]\nD marks a tower with range 3; # marks example cells within 3 tiles. Distance is Euclidean, so an offset of (2, 2) is in range, but (3, 1) is not. Sniper range 99 covers the whole 10×10 board. Upgrades extend range by half a tile each.\n\n[color=#68d8e8][b]BALLOON STATS[/b][/color]\n[code]Red     $1  base HP 1   speed 1  pop reward $1.25 tower bite 4\nBlue    $2  base HP 2   speed 1  pop reward $2.50 tower bite 6\nGreen  $10  base HP 3   speed 1  pop reward $12.50 tower bite 8\nYellow $18  base HP 4   speed 2  pop reward $22.50 tower bite 10\nMOAB  $150  base HP 40  speed 1  pop reward $187.50 tower bite 22  unlock round 8[/code]\nEvery balloon gains +5 HP every 5 rounds (at round 5: Red 6, Blue 7, Green 8, Yellow 9, MOAB 45). When a balloon escapes, its remaining HP is subtracted from its owner's lives; balloon bite damage applies only to towers and spikes. Red/Blue/Green/Yellow tower-bite damage increases by +1 every 4 rounds; MOAB stays at 22. Nearby balloons attack towers within 1.5 tiles every 3 ticks, prioritizing Farms.\n\n[color=#68d8e8][b]TOWER REPAIRS & ROAD SPIKES[/b][/color]\n[code]repair(x, y)[/code] costs $40 and restores up to 12 HP. Medic automatically restores damaged nearby towers (range 3). Destroyed towers disappear. [code]spikes(x, y)[/code] costs $50, must be placed on a road tile, and has 25 HP; after round 10 its HP becomes 50. Spikes deal 10 damage to balloons each time they cross. Balloons also damage spikes while crossing.\n\n[color=#68d8e8][b]SCORESTREAKS[/b][/color]\nConsecutive pops build your streak; any balloon leak resets it. [code]streak(\"supply\")[/code] needs 3 pops and $250, pays $500 (net +$250), and allows up to 200 sends that turn instead of 100. [code]streak(\"repair\")[/code] needs 6 pops, costs $600, and restores up to 20 HP to each of your towers. [code]nuke()[/code] needs 10 pops and $3,000; its animation clears towers, spikes, incoming balloons, and active balloons on both boards. It does not remove lives.\n\n[color=#68d8e8][b]COMMANDS & BEGINNER TIPS[/b][/color]\n[code]build(\"dart\", x, y)  send(\"red\", count)  upgrade(x, y)\nupgrade_all(\"dart\")  repair(x, y)  spikes(x, y)\nstreak(\"supply\")  streak(\"repair\")  nuke()[/code]\nUse x for the column (left to right) and y for the row (top to bottom); valid coordinates are 0–9. The board shows D Dart, T Tack, S Sniper, B Bomb, $ Farm, + Medic, ^ spikes, lowercase first-letter balloon symbols, ▶ entry, ≈ water/Submarine tiles, and ◎ exit. If RUN PLAN reports a syntax error, check colons and four-space indentation. This GDScript plan editor supports variables, loops, if/else, and named notebook functions. Type a saved function call such as opening() on its own line.\n\n[color=#68d8e8][b]LOBBY & CURRENT GODOT BUILD[/b][/color]\nThe lobby lets both players set their names. Online play is direct 1v1: host selects HOST GAME; the friend enters the host's public IP and clicks JOIN HOST. Both need the same ZIP. The host may need to allow UDP port 24680 through their router/firewall. The host synchronizes turns and the session clock; no relay is used. This Godot playtest currently has one Classic map and code mode; the Python build's alternate maps, Casual menus, and 1v1v1 mode are not included here."
	guide.text += "\n\n[color=#68d8e8][b]PYTHON EDITION HANDBOOK REFERENCE[/b][/color]\nThe original Python build also offers features that this Godot test version does not yet implement. Its maps are Classic, Zigzag, Switchback (parallel lanes), Crossfire (center crossings), Spiral (winds inward), and Bridge (tight connectors). Its Casual menu uses B=Build, S=Send, U=Upgrade, A=upgrade all, R=Repair, P=Spikes, V=page through tower status, and D=Done/Ready. Python mode also has save/load, a saved function library recalled with Ctrl+L or the library command, the towers command for status pages, /exit to return to menu, and 1v1v1 multiplayer with P3 naming and targeted sends. Those commands are Python-build instructions; in this Godot build use the visible buttons, the Classic 1v1 lobby, and GDScript actions above."
	guide.text += "\n\n[color=#68d8e8][b]COMMANDER VOICE LINES[/b][/color]\nVoice support has three categories: tower construction, scorestreak activation, and match result (victory/defeat). It has audio slots for three commanders; the current Godot match supports two players, with the third slot reserved for a future 1v1v1 mode. Optional OGG clips go in project/voice/commander_1, commander_2, or commander_3; the voice folder README lists each exact filename. Missing clips stay silent. In online matches, the host synchronizes voice events to the joining player."
	guide.text += "\n\n[color=#68d8e8][b]NEW BATTLE RULES[/b][/color]\nGreen balloons cost $10 and Yellow cost $18 from round 1. Popping a balloon pays its defender exactly 125% of its send price, including cents. Balloon escapes subtract that balloon's remaining HP from its owner's lives. Each 6th round sends a free random wave to both players; the prior round shows the warning. The Classic map's blue ≈ tiles hold the $320 Submarine (U), which fires at range 4 for 8 damage every 2 ticks; only Submarines fit on water. Open LOGS → Battle Events for shared shots, bites, pops, rewards, leaks/lives lost, and wave events. REMATCH appears after a winner is decided."
	guide.text += "\n\n[color=#68d8e8][b]NOTEBOOK FUNCTIONS[/b][/color]\nWrite reusable code in the editor, open NOTEBOOK, enter a name such as [code]opening[/code], and click SAVE FUNCTION. In another plan, type [code]opening()[/code] on its own line; the saved code is inserted there and runs as part of your plan. Functions take no arguments and can call other saved functions. You can also load a saved function into the editor to review or change it. Files stay on this computer, so each player keeps their own notebook."
	guide.text += "\n\n[color=#68d8e8][b]NOTEBOOK NOTES & ALIASES[/b][/color]\nThe notebook now autosaves multiple freeform notes locally. A line such as [code]dart = \"dart\"[/code] defines a planner alias; write [code]build(dart, 4, 3)[/code] and the planner uses the saved string value. Ordinary notes are ignored by the code runner. Select GDScript text in a note to insert it into the planner, or save a complete plan as a reusable snippet and insert its name with parentheses."
	guide.text += "\n\n[color=#68d8e8][b]ROUND WAVES[/b][/color]\nEvery round now brings an automatic survival wave to each player's road. It starts with 4 + the round number Red balloons. Blue balloons join from round 3, Green from round 5, Yellow from round 8, and MOABs from round 12; higher rounds add more of each unlocked type. These waves are separate from balloons sent by your rival. The existing random bonus wave still arrives every 6th round."
	guide.text += "\n\n[color=#68d8e8][b]CO-OP SURVIVAL[/b][/color]\nChoose [b]Co-op Survival[/b] in the lobby before starting locally or hosting online. Both players share one board, one cash balance, one lives pool, and one tower collection. Each player writes and readies a plan; both plans build the same defense, then the team survives the automatic round waves together. Sending balloons is disabled in co-op. For online co-op, the host chooses the mode and the joining player receives it automatically."
	guide.text += "\n\n[color=#68d8e8][b]ROUND INCOME & SPENDING[/b][/color]\nThe status panel's +$/r includes the $50 base, permanent income earned from sends, and every Farm's payout ($60 per round at level 1, plus $15 per upgrade level). The round log reports the actual amount paid. RUN PLAN rejects a new queued plan if its costs would put your cash below $0; no part of a rejected plan is charged. In co-op, both players' queued costs are checked against the same team wallet."
	guide.text += "\n\n[color=#68d8e8][b]THE MAGIC TOUCH — PRACTICAL FIELD TIPS[/b][/color]\nStart with a small plan and read the cash preview before READY. Use [code]for[/code] loops to place matching defenses, and an [code]if[/code] check to avoid unaffordable builds:\n[code]if money >= 100:\n    build(\"dart\", 4, 3)[/code]\nFarms are safest away from the road, while Dart and Tack towers cover nearby bends. Select a tower on the board to see its attack radius. Zoom each board with the [b]+[/b] and [b]−[/b] controls or your mouse wheel; choose [b]FIT[/b] to restore the full-board view. Zooming one board does not change the other."
	var tab_names := ["Getting Started", "Towers", "Upgrades & Range", "Balloons & Waves", "Economy", "Multiplayer"]
	var tab_text: Array[String] = ["", "", "", "", "", ""]
	var section_marker := "\n\n[color=#68d8e8][b]"
	var sections := guide.text.split(section_marker)
	for index in range(sections.size()):
		var section: String = sections[index]
		if index > 0:
			section = "[color=#68d8e8][b]" + section
		var title := section.get_slice("[b]", 1).get_slice("[/b]", 0).to_upper()
		var tab_index := 0
		if "TOWER" in title:
			tab_index = 1
		elif "UPGRADE" in title or "RANGE" in title:
			tab_index = 2
		elif "BALLOON" in title or "BATTLE RULES" in title or "ROUND WAVE" in title:
			tab_index = 3
		elif "ECONOMY" in title or "SCORESTREAK" in title:
			tab_index = 4
		elif "ONLINE" in title or "LOBBY" in title or "NOTEBOOK" in title or "PYTHON EDITION" in title or "CO-OP" in title:
			tab_index = 5
		tab_text[tab_index] += section + "\n\n"
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	for index in range(tab_names.size()):
		var page := RichTextLabel.new()
		page.name = tab_names[index]
		page.bbcode_enabled = true
		page.fit_content = false
		page.scroll_active = true
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.text = tab_text[index]
		tabs.add_child(page)
	var close := _button("CLOSE GUIDE", help_window.queue_free)
	layout.add_child(close)
	help_window.popup_centered(Vector2i(760, 700))


func _show_notebook() -> void:
	if is_instance_valid(notebook_window):
		notebook_window.popup_centered()
		return
	notebook_window = Window.new()
	notebook_window.title = "Terminus-Battles — Notebook"
	notebook_window.size = Vector2i(920, 650)
	notebook_window.min_size = Vector2i(600, 460)
	notebook_window.transient = true
	notebook_window.always_on_top = true
	notebook_window.close_requested.connect(func():
		_save_notebook_note()
		notebook_window.queue_free()
		notebook_window = null
	)
	add_child(notebook_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	notebook_window.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "FIELD NOTEBOOK"
	heading.add_theme_color_override("font_color", Color("#69e3ab"))
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var notes_page := VBoxContainer.new()
	notes_page.name = "Notes & Aliases"
	notes_page.add_theme_constant_override("separation", 8)
	tabs.add_child(notes_page)
	var notes_help := Label.new()
	notes_help.text = "Notes save automatically on this computer. Put reusable string values on their own lines, like dart = \"dart\"; use them in the planner as build(dart, 4, 3)."
	notes_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes_page.add_child(notes_help)
	var note_bar := HBoxContainer.new()
	note_bar.add_theme_constant_override("separation", 7)
	notes_page.add_child(note_bar)
	notebook_note_picker = OptionButton.new()
	notebook_note_picker.custom_minimum_size.x = 180
	notebook_note_picker.item_selected.connect(func(index: int):
		_save_notebook_note()
		_open_notebook_note(notebook_note_picker.get_item_text(index))
	)
	note_bar.add_child(notebook_note_picker)
	notebook_note_name = LineEdit.new()
	notebook_note_name.placeholder_text = "Note name"
	notebook_note_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notebook_note_name.text_changed.connect(func(_text: String): notebook_autosave_timer.start())
	note_bar.add_child(notebook_note_name)
	note_bar.add_child(_button("NEW NOTE", _new_notebook_note))
	note_bar.add_child(_button("SAVE", _save_notebook_note))
	notebook_editor = TextEdit.new()
	notebook_editor.syntax_highlighter = _gdscript_highlighter()
	notebook_editor.placeholder_text = "Write anything here. Example alias:\ndart = \"dart\"\nblue = \"blue\"\n\nOther lines can be ordinary notes; only simple name = \"text\" lines become planner aliases."
	notebook_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_editor.custom_minimum_size.y = 260
	notebook_editor.text_changed.connect(func():
		if is_instance_valid(notebook_save_status):
			notebook_save_status.text = "Saving…"
		if is_instance_valid(notebook_autosave_timer):
			notebook_autosave_timer.start()
	)
	notes_page.add_child(notebook_editor)
	var note_footer := HBoxContainer.new()
	notes_page.add_child(note_footer)
	notebook_save_status = Label.new()
	notebook_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_footer.add_child(notebook_save_status)
	note_footer.add_child(_button("SAVE AS FUNCTION", _save_note_as_function))
	var insert_note := _button("INSERT SELECTION IN PLAN", _insert_notebook_selection)
	insert_note.name = "InsertNotebookSelection"
	note_footer.add_child(insert_note)
	var snippets_page := VBoxContainer.new()
	snippets_page.name = "Reusable Code"
	snippets_page.add_theme_constant_override("separation", 10)
	tabs.add_child(snippets_page)
	var snippets_help := Label.new()
	snippets_help.text = "Save the current plan as a reusable code block. Later type opening() on a line by itself in the planner to insert and run it. Snippets take no arguments; aliases from your notes also work inside them."
	snippets_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snippets_page.add_child(snippets_help)
	var save_row := HBoxContainer.new()
	snippets_page.add_child(save_row)
	notebook_name_field = LineEdit.new()
	notebook_name_field.placeholder_text = "Snippet name, e.g. opening"
	notebook_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(notebook_name_field)
	save_row.add_child(_button("SAVE CURRENT PLAN", _save_notebook))
	var snippet_row := HBoxContainer.new()
	snippets_page.add_child(snippet_row)
	notebook_picker = OptionButton.new()
	notebook_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snippet_row.add_child(notebook_picker)
	snippet_row.add_child(_button("LOAD TO PLAN", _load_notebook))
	snippet_row.add_child(_button("INSERT CALL", _insert_notebook_call))
	var snippet_note := Label.new()
	snippet_note.text = "Reusable snippets are stored separately from freeform notes. Use them to build a personal strategy library."
	snippet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snippets_page.add_child(snippet_note)
	layout.add_child(_button("CLOSE NOTEBOOK", func():
		_save_notebook_note()
		notebook_window.queue_free()
		notebook_window = null
	))
	notebook_autosave_timer = Timer.new()
	notebook_autosave_timer.one_shot = true
	notebook_autosave_timer.wait_time = 0.45
	notebook_autosave_timer.timeout.connect(_save_notebook_note)
	notebook_window.add_child(notebook_autosave_timer)
	_refresh_notebook_notes()
	if notebook_note_picker.item_count == 0:
		notebook_note_name.text = "My Notes"
		notebook_editor.text = "# Planner aliases\ndart = \"dart\"\n\n# Write any other notes below; this page autosaves.\n"
		_save_notebook_note()
	else:
		_open_notebook_note(notebook_note_picker.get_item_text(notebook_note_picker.selected))
	_refresh_notebook_list()
	notebook_window.popup_centered(Vector2i(920, 650))


func _refresh_notebook_notes(select_name: String = "") -> void:
	if not is_instance_valid(notebook_note_picker):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://notebooks/notes"))
	notebook_note_picker.clear()
	var directory := DirAccess.open("user://notebooks/notes")
	if directory == null:
		return
	var names := PackedStringArray()
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".txt"):
			names.append(file_name.trim_suffix(".txt"))
		file_name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	for name in names:
		notebook_note_picker.add_item(name)
		if name == select_name:
			notebook_note_picker.select(notebook_note_picker.item_count - 1)


func _save_notebook_note() -> void:
	if not is_instance_valid(notebook_editor) or not is_instance_valid(notebook_note_name):
		return
	var safe_name := RegEx.create_from_string("[^A-Za-z0-9_-]").sub(notebook_note_name.text.strip_edges(), "_", true).trim_prefix("_").trim_suffix("_")
	if safe_name.is_empty():
		safe_name = "My_Notes"
		notebook_note_name.text = "My Notes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://notebooks/notes"))
	var file := FileAccess.open("user://notebooks/notes/%s.txt" % safe_name, FileAccess.WRITE)
	if file == null:
		if is_instance_valid(notebook_save_status):
			notebook_save_status.text = "Could not save note (error %d)." % FileAccess.get_open_error()
		return
	file.store_string(notebook_editor.text)
	file.close()
	if is_instance_valid(notebook_save_status):
		notebook_save_status.text = "Saved locally · aliases are ready for RUN PLAN"
	_refresh_notebook_notes(safe_name)


func _open_notebook_note(name: String) -> void:
	var safe_name := RegEx.create_from_string("[^A-Za-z0-9_-]").sub(name, "_", true).trim_prefix("_").trim_suffix("_")
	if safe_name.is_empty():
		return
	var file := FileAccess.open("user://notebooks/notes/%s.txt" % safe_name, FileAccess.READ)
	if file == null:
		return
	notebook_note_name.text = name
	notebook_editor.text = file.get_as_text()
	file.close()
	notebook_save_status.text = "Saved locally · aliases are ready for RUN PLAN"


func _new_notebook_note() -> void:
	_save_notebook_note()
	var number := 1
	var candidate := "New_Note"
	while FileAccess.file_exists("user://notebooks/notes/%s.txt" % candidate):
		number += 1
		candidate = "New_Note_%d" % number
	notebook_note_name.text = candidate
	notebook_editor.text = ""
	_save_notebook_note()
	notebook_editor.grab_focus()
	notebook_editor.set_caret_line(0)


func _insert_notebook_selection() -> void:
	if not is_instance_valid(notebook_editor) or not notebook_editor.has_selection():
		notebook_save_status.text = "Select a line of GDScript first, then insert it into the planner."
		return
	var selected := notebook_editor.get_selected_text()
	code_editor.insert_text_at_caret(selected + "\n")
	_save_notebook_note()
	notebook_window.queue_free()
	notebook_window = null
	code_editor.grab_focus()


func _save_note_as_function() -> void:
	_save_notebook_note()
	var name := notebook_note_name.text.strip_edges()
	var safe_name := RegEx.create_from_string("[^A-Za-z0-9_-]").sub(name, "_", true).trim_prefix("_").trim_suffix("_")
	if safe_name.is_empty() or notebook_editor.text.strip_edges().is_empty():
		notebook_save_status.text = "Give this note a name and add reusable GDScript first."
		return
	var file := FileAccess.open("user://notebooks/%s.gd" % safe_name, FileAccess.WRITE)
	if file == null:
		notebook_save_status.text = "Could not create function (error %d)." % FileAccess.get_open_error()
		return
	file.store_string(notebook_editor.text)
	file.close()
	notebook_name_field.text = safe_name
	_refresh_notebook_list(safe_name)
	notebook_save_status.text = "Saved as %s() · call it from a planner line" % safe_name


func _insert_notebook_call() -> void:
	if notebook_picker.item_count == 0:
		return
	var name := notebook_picker.get_item_text(notebook_picker.selected)
	var call_text := ("\n" if not code_editor.text.is_empty() else "") + name + "()\n"
	code_editor.insert_text_at_caret(call_text)
	notebook_window.queue_free()
	notebook_window = null
	code_editor.grab_focus()


func _refresh_notebook_list(select_name: String = "") -> void:
	if not is_instance_valid(notebook_picker):
		return
	notebook_picker.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://notebooks"))
	var directory := DirAccess.open("user://notebooks")
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".gd"):
			notebook_picker.add_item(file_name.trim_suffix(".gd"))
		file_name = directory.get_next()
	directory.list_dir_end()
	for index in range(notebook_picker.item_count):
		if notebook_picker.get_item_text(index) == select_name:
			notebook_picker.select(index)
			break


func _save_notebook() -> void:
	var name := notebook_name_field.text.strip_edges()
	var safe_name := RegEx.create_from_string("[^A-Za-z0-9_-]").sub(name, "_", true).trim_prefix("_").trim_suffix("_")
	if safe_name.is_empty() or code_editor.text.strip_edges().is_empty():
		_log("Name the notebook and write a plan before saving it.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://notebooks"))
	var file := FileAccess.open("user://notebooks/%s.gd" % safe_name, FileAccess.WRITE)
	if file == null:
		_log("Could not save notebook (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(code_editor.text)
	file.close()
	_refresh_notebook_list(safe_name)
	notebook_name_field.text = safe_name
	_log("Saved plan notebook: %s." % safe_name)


func _load_notebook() -> void:
	if notebook_picker.item_count == 0:
		_log("No saved notebooks yet. Name and save a plan first.")
		return
	var name := notebook_picker.get_item_text(notebook_picker.selected)
	var file := FileAccess.open("user://notebooks/%s.gd" % name, FileAccess.READ)
	if file == null:
		_log("Could not load notebook (error %d)." % FileAccess.get_open_error())
		return
	code_editor.text = file.get_as_text()
	file.close()
	_log("Loaded plan notebook: %s. Review it, then click RUN PLAN." % name)
	notebook_window.queue_free()
	notebook_window = null
	code_editor.grab_focus()


func _return_to_menu() -> void:
	if network_role != "offline":
		multiplayer.multiplayer_peer = null
		network_role = "offline"
		peer_ready = false
		network_disconnected = false
	learning_mode = false
	_build_menu()


func _rematch() -> void:
	if game_started:
		return
	if network_role == "client":
		if network_disconnected:
			_log("Reconnect to the host before starting a rematch.")
			return
		rpc_id(1, "request_rematch")
		_log("Rematch requested from host.")
		return
	if network_role == "host" and not peer_ready:
		_log("The other player must reconnect before rematching.")
		return
	_start_match(true)
	_log("Rematch started.")


@rpc("any_peer", "call_remote", "reliable")
func request_rematch() -> void:
	if network_role != "host" or multiplayer.get_remote_sender_id() != remote_peer_id or game_started:
		return
	_start_match(true)
	_log("Rematch started by %s." % players[1].name)
