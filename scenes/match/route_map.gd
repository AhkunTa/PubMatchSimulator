extends Control

const ENCOUNTER_SCENE := "res://scenes/match/encounter.tscn"
const BACKGROUND := preload("res://assets/ui/chibi_pixel/backgrounds/route-selection-background.png")

var route_nodes: Array[Dictionary] = []
var node_buttons: Dictionary = {}
var selected_node_id := ""
var detail_label: RichTextLabel
var confirm_button: Button


func _ready() -> void:
	_setup_background()
	_setup_route_data()
	_setup_layout()
	_update_available_nodes()
	_select_first_available()


func _setup_background() -> void:
	var bg := TextureRect.new()
	bg.name = "PixelBackground"
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -20
	add_child(bg)

	var shade := ColorRect.new()
	shade.name = "ReadableOverlay"
	shade.color = Color(0.03, 0.025, 0.035, 0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = -19
	add_child(shade)


func _setup_route_data() -> void:
	route_nodes = [
		_node("start", 0, 0.50, "Start", "Rally", "Low", "Low", ["Current squad"], ["n1a", "n1b", "n1c"]),
		_node("n1a", 1, 0.25, "Abandoned Depot", "Search", "Medium", "High", ["Loot", "Conflict"], ["n2a", "n2b"], 4, -2, 95, 5),
		_node("n1b", 1, 0.50, "Crossfire Block", "Battle", "High", "Medium", ["Enemy team", "High threat"], ["n2b", "n2c"], 9, -5, 40, 8),
		_node("n1c", 1, 0.75, "Injured Stranger", "Bond", "Low", "Medium", ["Rescue", "Dispute"], ["n2c"], 1, 4, 20, 3),
		_node("n2a", 2, 0.30, "Back Alley Store", "Search", "Medium", "Medium", ["Supplies", "Exposure"], ["n3a", "n3b"], 4, -1, 70, 4),
		_node("n2b", 2, 0.52, "Rooftop Pass", "Story", "Medium", "High", ["Hidden risk", "Shortcut"], ["n3a", "n3c"], 5, -3, 80, 9),
		_node("n2c", 2, 0.72, "Safe Room", "Bond", "Low", "Low", ["Rest", "Trust"], ["n3c"], -3, 6, 0, -2),
		_node("n3a", 3, 0.25, "Airdrop Fight", "Battle", "High", "High", ["Rare loot", "Ambush"], ["n4a", "n4b"], 11, -6, 140, 10),
		_node("n3b", 3, 0.50, "Temporary Camp", "Bond", "Medium", "Medium", ["Share conflict"], ["n4b"], 3, 2, 45, 5),
		_node("n3c", 3, 0.74, "Subway Tunnel", "Story", "Medium", "Medium", ["Panic", "Low exposure"], ["n4b", "n4c"], 2, -3, 35, 7),
		_node("n4a", 4, 0.28, "Blockade Line", "Battle", "High", "Medium", ["Break through"], ["n5"], 8, -4, 35, 8),
		_node("n4b", 4, 0.53, "Temp Evac Point", "Evac", "Medium", "Medium", ["Early exit"], ["n5"], -2, 2, 0, -4),
		_node("n4c", 4, 0.76, "Old Metro", "Search", "Medium", "High", ["Last supplies"], ["n5"], 5, -2, 110, 6),
		_node("n5", 5, 0.52, "Final Evac", "Evac", "High", "High", ["Run endpoint"], [], -4, 4, 0, -8),
	]


func _setup_layout() -> void:
	_add_top_bar()
	_add_route_buttons()
	_update_available_nodes()
	_add_route_lines()
	_add_detail_panel()


func _add_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "TopStatusBar"
	panel.position = Vector2(24, 18)
	panel.size = Vector2(1330, 74)
	panel.z_index = 10
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.07, 0.09, 0.82), Color(0.97, 0.72, 0.25)))
	add_child(panel)

	var label := Label.new()
	label.text = "Node %d/%d    Threat %d    Cohesion %d    Loot %d    Heat %d" % [
		RunState.run_stats["step"],
		RunState.run_stats["max_step"],
		RunState.run_stats["threat"],
		RunState.run_stats["cohesion"],
		RunState.run_stats["loot"],
		RunState.run_stats["accident_heat"],
	]
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	panel.add_child(label)


func _add_route_buttons() -> void:
	for node in route_nodes:
		var button := Button.new()
		button.name = "RouteButton_%s" % node["id"]
		button.text = "%s\n%s" % [_type_icon(node["type"]), node["title"]]
		button.custom_minimum_size = Vector2(150, 72)
		button.size = Vector2(150, 72)
		button.position = _node_position(node["layer"], node["row"])
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _button_style(Color(0.17, 0.14, 0.18), Color(0.50, 0.42, 0.52)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.29, 0.20, 0.18), Color(1.0, 0.82, 0.34)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.16, 0.34, 0.25), Color(0.45, 0.95, 0.60)))
		button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.10, 0.12, 0.72), Color(0.22, 0.20, 0.24)))
		button.z_index = 4
		button.pressed.connect(_on_route_button_pressed.bind(node["id"]))
		button.mouse_entered.connect(_show_detail.bind(node["id"]))
		add_child(button)
		node_buttons[node["id"]] = button


func _add_route_lines() -> void:
	for node in route_nodes:
		var from_button: Button = node_buttons.get(node["id"])
		if from_button == null:
			continue
		for target_id in node["outgoing"]:
			var to_button: Button = node_buttons.get(target_id)
			if to_button == null:
				continue
			var is_available_from_current = node["id"] == RunState.current_node_id and RunState.available_node_ids.has(target_id)
			var is_traveled := RunState.traveled_edge_ids.has("%s->%s" % [node["id"], target_id])
			var line_color := Color(0.36, 0.85, 0.58, 0.95) if (is_available_from_current or is_traveled) else Color(0.25, 0.22, 0.26, 0.42)

			var shadow := Line2D.new()
			shadow.name = "RouteLineShadow_%s_%s" % [node["id"], target_id]
			shadow.points = PackedVector2Array([_button_center(from_button), _button_center(to_button)])
			shadow.width = 10.0
			shadow.default_color = Color(0.06, 0.05, 0.07, 0.45)
			shadow.z_index = -4
			add_child(shadow)

			var line := Line2D.new()
			line.name = "RouteLine_%s_%s" % [node["id"], target_id]
			line.points = PackedVector2Array([_button_center(from_button), _button_center(to_button)])
			line.width = 6.0
			line.default_color = line_color
			line.z_index = -3
			add_child(line)


func _add_detail_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "NodeDetailPanel"
	panel.position = Vector2(1410, 132)
	panel.size = Vector2(460, 712)
	panel.z_index = 10
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.07, 0.09, 0.88), Color(0.45, 0.95, 0.60)))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Node Detail"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58))
	box.add_child(title)

	detail_label = RichTextLabel.new()
	detail_label.fit_content = false
	detail_label.bbcode_enabled = true
	detail_label.custom_minimum_size = Vector2(420, 500)
	detail_label.add_theme_font_size_override("normal_font_size", 22)
	detail_label.add_theme_color_override("default_color", Color(0.98, 0.93, 0.82))
	box.add_child(detail_label)

	confirm_button = Button.new()
	confirm_button.text = "Enter Scene"
	confirm_button.custom_minimum_size = Vector2(420, 64)
	confirm_button.add_theme_font_size_override("font_size", 26)
	confirm_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.36, 0.25), Color(0.45, 0.95, 0.60)))
	confirm_button.add_theme_stylebox_override("hover", _button_style(Color(0.28, 0.46, 0.30), Color(1.0, 0.88, 0.35)))
	confirm_button.add_theme_stylebox_override("disabled", _button_style(Color(0.11, 0.11, 0.12), Color(0.22, 0.20, 0.24)))
	confirm_button.pressed.connect(_confirm_selected_node)
	box.add_child(confirm_button)


func _update_available_nodes() -> void:
	var current := _find_node(RunState.current_node_id)
	RunState.available_node_ids.clear()
	if current.is_empty():
		RunState.current_node_id = "start"
		current = _find_node("start")
	for target_id in current.get("outgoing", []):
		RunState.available_node_ids.append(target_id)

	for node in route_nodes:
		var button: Button = node_buttons[node["id"]]
		var visited := RunState.visited_node_ids.has(node["id"])
		var available := RunState.available_node_ids.has(node["id"])
		var currentn_node = node["id"] == RunState.current_node_id
		button.disabled = not available
		if currentn_node:
			button.add_theme_stylebox_override("disabled", _button_style(Color(0.13, 0.34, 0.22), Color(0.45, 0.95, 0.60)))
			button.modulate = Color(0.42, 1.0, 0.58)
		elif visited:
			button.add_theme_stylebox_override("disabled", _button_style(Color(0.12, 0.28, 0.20), Color(0.36, 0.85, 0.58)))
			button.modulate = Color(0.56, 0.95, 0.64)
		elif available:
			button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.36, 0.22), Color(0.45, 0.95, 0.60)))
			button.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.46, 0.28), Color(1.0, 0.88, 0.35)))
			button.modulate = Color(0.70, 1.0, 0.76)
		else:
			button.add_theme_stylebox_override("disabled", _button_style(Color(0.10, 0.10, 0.12, 0.72), Color(0.22, 0.20, 0.24)))
			button.modulate = Color(0.38, 0.38, 0.42)


func _select_first_available() -> void:
	if RunState.available_node_ids.is_empty():
		selected_node_id = RunState.current_node_id
	else:
		selected_node_id = RunState.available_node_ids[0]
	_show_detail(selected_node_id)


func _show_detail(node_id: String) -> void:
	selected_node_id = node_id
	var node := _find_node(node_id)
	var can_enter := RunState.available_node_ids.has(node_id)
	confirm_button.disabled = not can_enter
	confirm_button.text = "Enter Scene" if can_enter else "Locked Route"
	detail_label.text = "[font_size=28][color=#ffe76e]%s[/color][/font_size]\n\nType: %s\nThreat: %s\nReward: %s\nTags: %s\n\nSquad read:\nA-Qiang: %s\nXiao Dao: %s\nOld Zhou: %s" % [
		node["title"],
		node["type"],
		node["threat"],
		node["reward"],
		_join_tags(node["tags"]),
		"Wants it" if node["reward"] == "High" else "Watching",
		"Resists" if node["threat"] == "High" else "Neutral",
		"Unclear" if node["type"] == "Story" else "Can follow",
	]


func _on_route_button_pressed(node_id: String) -> void:
	_show_detail(node_id)
	if RunState.available_node_ids.has(node_id):
		_confirm_selected_node()


func _confirm_selected_node() -> void:
	var node := _find_node(selected_node_id)
	if node.is_empty() or not RunState.available_node_ids.has(selected_node_id):
		return
	RunState.choose_route_node(node)
	get_tree().change_scene_to_file(ENCOUNTER_SCENE)


func _node(id: String, layer: int, row: float, title: String, type: String, threat: String, reward: String, tags: Array, outgoing: Array, threat_delta := 0, cohesion_delta := 0, loot_delta := 0, heat_delta := 0) -> Dictionary:
	return {
		"id": id,
		"layer": layer,
		"row": row,
		"title": title,
		"type": type,
		"threat": threat,
		"reward": reward,
		"tags": tags,
		"outgoing": outgoing,
		"threat_delta": threat_delta,
		"cohesion_delta": cohesion_delta,
		"loot_delta": loot_delta,
		"heat_delta": heat_delta,
	}


func _find_node(node_id: String) -> Dictionary:
	for node in route_nodes:
		if node["id"] == node_id:
			return node
	return {}


func _node_position(layer: int, row: float) -> Vector2:
	return Vector2(115 + layer * 214, 130 + row * 780)


func _button_center(button: Button) -> Vector2:
	return button.position + button.size * 0.5


func _type_icon(type: String) -> String:
	match type:
		"Battle":
			return "ATK"
		"Search":
			return "SRC"
		"Bond":
			return "BND"
		"Story":
			return "EVT"
		"Evac":
			return "EXT"
		_:
			return "RUN"


func _join_tags(tags: Array) -> String:
	var parts: PackedStringArray = []
	for tag in tags:
		parts.append(String(tag))
	return " / ".join(parts)


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
