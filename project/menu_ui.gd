extends RefCounted

static func panel(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

static func copy(parent: Node, text: String, font_size: int = 17, color: Color = Color("#a8bfcb")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func field(parent: Node, title: String, initial: String, hint: String = "") -> LineEdit:
	copy(parent, title, 14)
	var input := LineEdit.new()
	input.text = initial
	input.placeholder_text = hint
	input.custom_minimum_size.y = 46
	parent.add_child(input)
	return input

static func page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return body

static func tabs_in(parent: Node) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tabs)
	tabs.tab_changed.connect(func(_index: int):
		var content: Control = tabs.get_current_tab_control()
		content.modulate.a = 0.25
		content.create_tween().tween_property(content, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	return tabs

static func make_theme(base: Theme) -> Theme:
	var styled: Theme = base.duplicate()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	styled.default_font = font
	styled.default_font_size = 17
	for widget in ["Button", "LineEdit", "OptionButton"]:
		styled.set_stylebox("normal", widget, panel(Color("#112431"), Color("#304653")))
		styled.set_stylebox("hover", widget, panel(Color("#1c3e49"), Color("#66cab6")))
		styled.set_stylebox("pressed", widget, panel(Color("#225649"), Color("#85e6be")))
		styled.set_stylebox("focus", widget, panel(Color(0,0,0,0), Color("#85e6be")))
		styled.set_color("font_color", widget, Color("#e5f4ee"))
	styled.set_stylebox("panel", "TabContainer", panel(Color("#0b1923"), Color("#243f4b")))
	styled.set_stylebox("tab_selected", "TabContainer", panel(Color("#214f45"), Color("#69caae")))
	styled.set_stylebox("tab_unselected", "TabContainer", panel(Color("#10222d"), Color("#243f4b")))
	styled.set_stylebox("tab_hovered", "TabContainer", panel(Color("#1b3b43"), Color("#69caae")))
	styled.set_stylebox("panel", "PanelContainer", panel(Color("#0b1923"), Color("#243f4b")))
	styled.set_stylebox("normal", "TextEdit", panel(Color("#09141d"), Color("#304653")))
	styled.set_stylebox("focus", "TextEdit", panel(Color("#09141d"), Color("#69caae")))
	styled.set_color("font_color", "TextEdit", Color("#e5f4ee"))
	styled.set_color("font_color", "Label", Color("#d9e7ff"))
	return styled

static func build(game) -> void:
	var backdrop := ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV; float wave=sin(p.x*5.0+p.y*3.0+TIME*0.16)*0.5+0.5; float light=exp(-length((p-vec2(0.85,0.28))*vec2(1.0,1.4))*4.0); vec3 base=mix(vec3(0.019,0.034,0.052),vec3(0.035,0.15,0.17),light*(0.65+wave*0.25)); COLOR=vec4(base,1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	game.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 64)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	game.add_child(margin)
	margin.theme = make_theme(game.theme)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	game.shell = layout
	var title := copy(layout, "TERMINUS-BATTLES", 58, Color("#e0f6ee"))
	copy(layout, "Write your strategy. Build your defense. Own the next wave.", 20)
	var tabs := tabs_in(layout)
	var solo := page(tabs, "Singleplayer")
	copy(solo, "Your code. One battlefield.", 30, Color("#e0f6ee"))
	copy(solo, "Learn at your own pace in solo survival. Build with GDScript, then press READY to launch the next wave. No second player required.")
	var solo_name := field(solo, "Commander name", "Commander")
	solo.add_child(game._button("START SOLO SURVIVAL", func():
		game.multiplayer.multiplayer_peer = null
		game.network_role = "offline"
		game.peer_ready = false
		game.solo_mode = true
		game.match_mode_option.selected = 1
		game.local_name_fields[0].text = solo_name.text
		game._start_match()
	))
	solo.add_child(game._button("START GDSCRIPT ACADEMY", func():
		game.multiplayer.multiplayer_peer = null
		game.network_role = "offline"
		game.peer_ready = false
		game.learning_mode = true
		game.solo_mode = true
		game.match_mode_option.selected = 1
		game.local_name_fields[0].text = solo_name.text
		game._start_match()
	))
	copy(solo, 'First plan: build("dart", 4, 3)\nRUN PLAN queues it. READY starts the wave.', 16, Color("#8bd4b8"))
	var multiplayer := page(tabs, "Multiplayer")
	copy(multiplayer, "Bring a rival. Or an ally.", 30, Color("#e0f6ee"))
	copy(multiplayer, "Duel on separate boards or share a defense in co-op. Both players plan together; the host resolves the wave.")
	copy(multiplayer, "Host / local game mode", 14)
	game.match_mode_option = OptionButton.new()
	game.match_mode_option.add_item("1v1 Duel")
	game.match_mode_option.add_item("Co-op Survival")
	game.match_mode_option.custom_minimum_size.y = 46
	multiplayer.add_child(game.match_mode_option)
	var rooms := tabs_in(multiplayer)
	rooms.custom_minimum_size.y = 285
	var host := page(rooms, "Host")
	game.host_name_field = field(host, "Your name", "Player 1")
	copy(host, "Open a room, then share your IP with your friend. Stay on this screen until they join.")
	host.add_child(game._button("OPEN ROOM", game._host_match))
	copy(host, "Different houses: use your public IP with UDP 24680 forwarded, or your shared VPN address. Both players need the same build.", 14)
	var join := page(rooms, "Join")
	game.join_name_field = field(join, "Your name", "Player 2")
	game.join_ip_field = field(join, "Host address", "", "Public, LAN or shared VPN IP")
	join.add_child(game._button("CONNECT TO HOST", game._join_match))
	copy(join, "Ask your friend to open a room first. Their selected game mode applies to both players.", 14)
	var local := page(rooms, "Local")
	copy(local, "Two commanders, one keyboard. Pass control after READY.")
	game.local_name_fields.clear()
	game.local_name_fields.append(field(local, "First commander", "Player 1"))
	game.local_name_fields.append(field(local, "Second commander", "Player 2"))
	local.add_child(game._button("START LOCAL MATCH", game._start_match))
	game.network_status_label = copy(multiplayer, "No room connected.", 15, Color("#ebcd8e"))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	footer.add_child(game._button("SETTINGS", game._show_settings))
	footer.add_child(game._button("HANDBOOK", game._show_help))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(game._button("QUIT", func(): game.get_tree().quit()))
	layout.modulate.a = 0.15
	layout.create_tween().tween_property(layout, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title.create_tween().tween_property(title, "self_modulate", Color("#85e6be"), 1.1).set_trans(Tween.TRANS_SINE)
