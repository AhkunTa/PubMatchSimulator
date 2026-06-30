extends Control

const ENCOUNTER_SCENE := "res://scenes/match/encounter.tscn"

const ROUTE_BUTTON_SIZE := Vector2(132.0, 86.0)
const ROUTE_PADDING := Vector2(84.0, 72.0)

var route_nodes: Array[Dictionary] = []
var node_buttons: Dictionary = {}
var selected_node_id: String = ""

var route_board_canvas: Control
var route_line_layer: Control
var route_node_layer: Control
var squad_member_list: VBoxContainer
var current_step_label: Label
var threat_value_label: Label
var cohesion_value_label: Label
var loot_value_label: Label
var heat_value_label: Label
var detail_title_label: Label
var detail_summary_label: RichTextLabel
var detail_tag_flow: HFlowContainer
var detail_attitude_box: VBoxContainer
var confirm_button: Button


func _ready() -> void:
	_bind_scene_nodes()
	_apply_static_i18n()
	_setup_route_data()
	_populate_static_scene_data()
	_add_route_buttons()
	_update_available_nodes()
	_select_first_available()
	call_deferred("_refresh_route_board")


func _bind_scene_nodes() -> void:
	route_board_canvas = %RouteBoardCanvas
	route_line_layer = %RouteLineLayer
	route_node_layer = %RouteNodeLayer
	squad_member_list = %SquadMemberList
	current_step_label = %CurrentStepLabel
	threat_value_label = get_node("RootMargin/RootColumn/TopBar/TopBarRow/ThreatStat/StatBox/Value")
	cohesion_value_label = get_node("RootMargin/RootColumn/TopBar/TopBarRow/CohesionStat/StatBox/Value")
	loot_value_label = get_node("RootMargin/RootColumn/TopBar/TopBarRow/LootStat/StatBox/Value")
	heat_value_label = get_node("RootMargin/RootColumn/TopBar/TopBarRow/HeatStat/StatBox/Value")
	detail_title_label = %DetailTitleLabel
	detail_summary_label = %DetailSummaryLabel
	detail_tag_flow = %DetailTagFlow
	detail_attitude_box = %DetailAttitudeBox
	confirm_button = %ConfirmButton

	route_board_canvas.resized.connect(_refresh_route_board)
	confirm_button.pressed.connect(_confirm_selected_node)


func _apply_static_i18n() -> void:
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/TitleBox/TitleLabel") as Label).text = I18n.msg("ui.route.title")
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/TitleBox/SubtitleLabel") as Label).text = I18n.msg("ui.route.subtitle")
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/ThreatStat/StatBox/Label") as Label).text = I18n.msg("ui.stats.threat")
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/CohesionStat/StatBox/Label") as Label).text = I18n.msg("ui.stats.cohesion")
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/LootStat/StatBox/Label") as Label).text = I18n.msg("ui.stats.loot")
	(get_node("RootMargin/RootColumn/TopBar/TopBarRow/HeatStat/StatBox/Label") as Label).text = I18n.msg("ui.stats.heat")
	(get_node("RootMargin/RootColumn/ContentRow/SquadPanel/SquadBox/Heading") as Label).text = I18n.msg("ui.route.squad")
	(get_node("RootMargin/RootColumn/ContentRow/SquadPanel/SquadBox/Hint") as Label).text = I18n.msg("ui.route.squad_hint")
	(get_node("RootMargin/RootColumn/ContentRow/DetailPanel/DetailBox/DetailScroll/DetailScrollContent/Heading") as Label).text = I18n.msg("ui.route.detail")
	(get_node("RootMargin/RootColumn/ContentRow/DetailPanel/DetailBox/DetailScroll/DetailScrollContent/TagsTitle") as Label).text = I18n.msg("ui.route.tags")
	(get_node("RootMargin/RootColumn/ContentRow/DetailPanel/DetailBox/DetailScroll/DetailScrollContent/AttitudeTitle") as Label).text = I18n.msg("ui.route.teammate_read")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/Title") as Label).text = I18n.msg("ui.route.legend")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/CurrentLegend/Label") as Label).text = I18n.msg("ui.route.current")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/AvailableLegend/Label") as Label).text = I18n.msg("ui.route.available")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/VisitedLegend/Label") as Label).text = I18n.msg("ui.route.visited")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/LockedLegend/Label") as Label).text = I18n.msg("ui.route.locked_legend")
	(get_node("RootMargin/RootColumn/LegendBar/LegendRow/PathLegend/Label") as Label).text = I18n.msg("ui.route.path")


func _populate_static_scene_data() -> void:
	current_step_label.text = I18n.msgf("ui.route.step", [RunState.run_stats["step"], RunState.run_stats["max_step"]])
	threat_value_label.text = "%d/100" % RunState.run_stats["threat"]
	cohesion_value_label.text = "%d/100" % RunState.run_stats["cohesion"]
	loot_value_label.text = "%d" % RunState.run_stats["loot"]
	heat_value_label.text = "%d%%" % RunState.run_stats["accident_heat"]

	_clear_children(squad_member_list)
	for member in RunState.squad_members:
		squad_member_list.add_child(_build_member_card(member))


func _setup_route_data() -> void:
	route_nodes = [
		_node("start", 0, 0.50, "node.start.title", "Rally", "Low", "Low", ["tag.current_squad"], ["n1a", "n1b", "n1c"]),
		_node("n1a", 1, 0.22, "node.n1a.title", "Search", "Mid", "High", ["tag.loot", "tag.conflict"], ["n2a", "n2b"], 4, -2, 95, 5),
		_node("n1b", 1, 0.50, "node.n1b.title", "Battle", "High", "Mid", ["tag.crossfire", "tag.high_threat"], ["n2b", "n2c"], 9, -5, 40, 8),
		_node("n1c", 1, 0.78, "node.n1c.title", "Bond", "Low", "Mid", ["tag.support", "tag.argument"], ["n2c"], 1, 4, 20, 3),
		_node("n2a", 2, 0.26, "node.n2a.title", "Intel", "Mid", "High", ["tag.recon", "tag.electronics"], ["n3a", "n3b"], 4, -1, 70, 4),
		_node("n2b", 2, 0.50, "node.n2b.title", "Search", "Mid", "Mid", ["tag.supplies", "tag.exposure"], ["n3a", "n3c"], 5, -3, 80, 9),
		_node("n2c", 2, 0.76, "node.n2c.title", "Supply", "Low", "Low", ["tag.rest", "tag.heal"], ["n3c"], -3, 6, 0, -2),
		_node("n3a", 3, 0.22, "node.n3a.title", "Supply", "Mid", "High", ["tag.medical", "tag.sightline"], ["n4a"], 3, 1, 85, 3),
		_node("n3b", 3, 0.50, "node.n3b.title", "Story", "Mid", "Mid", ["tag.unknown", "tag.shortcut"], ["n4b"], 2, -1, 45, 5),
		_node("n3c", 3, 0.76, "node.n3c.title", "Bond", "Mid", "Mid", ["tag.split_loot", "tag.reset"], ["n4b", "n4c"], 2, -3, 35, 7),
		_node("n4a", 4, 0.26, "node.n4a.title", "Intel", "Mid", "Mid", ["tag.survey", "tag.route_info"], ["n5a"], 3, 0, 20, 4),
		_node("n4b", 4, 0.50, "node.n4b.title", "Search", "Mid", "High", ["tag.high_value", "tag.solo_risk"], ["n5a", "n5b"], 5, -2, 110, 6),
		_node("n4c", 4, 0.76, "node.n4c.title", "Battle", "High", "Mid", ["tag.blockade", "tag.strong_enemy"], ["n5b"], 8, -4, 35, 8),
		_node("n5a", 5, 0.42, "node.n5a.title", "Evac", "Mid", "Mid", ["tag.early_evac"], [], -2, 2, 0, -4),
		_node("n5b", 5, 0.66, "node.n5b.title", "Evac", "High", "High", ["tag.final_evac"], [], -4, 4, 0, -8),
	]


func _build_member_card(member: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 164)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.11, 0.88), member["accent"]))

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var avatar: ColorRect = ColorRect.new()
	avatar.custom_minimum_size = Vector2(54, 54)
	avatar.color = member["accent"]
	header.add_child(avatar)

	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_box)

	var name_label: Label = Label.new()
	name_label.text = I18n.msgf("ui.route.member_card_name", [_actor_name(member), I18n.msg("ui.squad.you") if member["id"] == "player" else ""])
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	name_box.add_child(name_label)

	var role_label: Label = Label.new()
	role_label.text = _actor_role(member)
	role_label.add_theme_font_size_override("font_size", 16)
	role_label.add_theme_color_override("font_color", Color(0.64, 0.69, 0.74))
	name_box.add_child(role_label)

	var badge_flow: HFlowContainer = HFlowContainer.new()
	badge_flow.add_theme_constant_override("h_separation", 8)
	badge_flow.add_theme_constant_override("v_separation", 8)
	box.add_child(badge_flow)

	badge_flow.add_child(_build_small_badge("%s %d" % [I18n.msg("ui.stats.hp"), member["hp"]], Color(0.84, 0.35, 0.31)))
	badge_flow.add_child(_build_small_badge("%s %d" % [I18n.msg("ui.stats.bag"), member["bag"]], Color(0.91, 0.72, 0.24)))
	badge_flow.add_child(_build_small_badge("%s %d" % [I18n.msg("ui.stats.trust"), member["trust"]], Color(0.50, 0.85, 0.54)))
	badge_flow.add_child(_build_small_badge("%s %d" % [I18n.msg("ui.stats.care"), member["caution"]], Color(0.41, 0.72, 0.96)))

	var note: Label = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = _member_summary(member)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.72, 0.76, 0.80))
	box.add_child(note)

	return panel


func _build_small_badge(text: String, color: Color) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _badge_style(color))

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	panel.add_child(label)
	return panel


func _add_route_buttons() -> void:
	for node in route_nodes:
		var button: Button = Button.new()
		button.name = "RouteButton_%s" % node["id"]
		button.text = "%s\n%s" % [_type_icon(node["type"]), I18n.msg(String(node["title_key"]))]
		button.custom_minimum_size = ROUTE_BUTTON_SIZE
		button.size = ROUTE_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_route_button_pressed.bind(node["id"]))
		button.mouse_entered.connect(_show_detail.bind(node["id"]))
		route_node_layer.add_child(button)
		node_buttons[node["id"]] = button


func _refresh_route_board() -> void:
	if route_board_canvas == null or route_board_canvas.size.x <= 0.0 or route_board_canvas.size.y <= 0.0:
		return

	for node in route_nodes:
		var button: Button = node_buttons.get(node["id"]) as Button
		if button == null:
			continue
		button.position = _node_position(node["layer"], node["row"])

	_clear_children(route_line_layer)

	for node in route_nodes:
		var from_button: Button = node_buttons.get(node["id"]) as Button
		if from_button == null:
			continue
		for target_id in node["outgoing"]:
			var to_button: Button = node_buttons.get(target_id) as Button
			if to_button == null:
				continue

			var is_available: bool = String(node["id"]) == RunState.current_node_id and RunState.available_node_ids.has(target_id)
			var is_traveled: bool = RunState.traveled_edge_ids.has("%s->%s" % [node["id"], target_id])
			var line_color: Color = Color(0.76, 0.76, 0.78, 0.75)
			if is_traveled:
				line_color = Color(0.40, 0.83, 0.58, 0.95)
			elif is_available:
				line_color = Color(0.95, 0.77, 0.28, 0.95)

			var shadow: Line2D = Line2D.new()
			shadow.points = PackedVector2Array([_button_center(from_button), _button_center(to_button)])
			shadow.width = 8.0
			shadow.default_color = Color(0.02, 0.02, 0.03, 0.62)
			route_line_layer.add_child(shadow)

			var line: Line2D = Line2D.new()
			line.points = PackedVector2Array([_button_center(from_button), _button_center(to_button)])
			line.width = 4.0
			line.default_color = line_color
			route_line_layer.add_child(line)

	_update_button_states()


func _update_available_nodes() -> void:
	var current: Dictionary = _find_node(RunState.current_node_id)
	RunState.available_node_ids.clear()
	if current.is_empty():
		RunState.current_node_id = "start"
		current = _find_node("start")
	for target_id in current.get("outgoing", []):
		RunState.available_node_ids.append(target_id)

	if route_board_canvas != null:
		_refresh_route_board()
	else:
		_update_button_states()


func _update_button_states() -> void:
	for node in route_nodes:
		var button: Button = node_buttons.get(node["id"]) as Button
		if button == null:
			continue

		var visited: bool = RunState.visited_node_ids.has(node["id"])
		var available: bool = RunState.available_node_ids.has(node["id"])
		var current_node: bool = String(node["id"]) == RunState.current_node_id
		var selected: bool = String(node["id"]) == selected_node_id

		button.disabled = not available
		button.modulate = Color(1, 1, 1, 1)

		var fill: Color = Color(0.14, 0.15, 0.18, 0.96)
		var border: Color = Color(0.34, 0.36, 0.40)

		if current_node:
			fill = Color(0.31, 0.24, 0.10, 0.96)
			border = Color(0.95, 0.77, 0.28)
		elif visited:
			fill = Color(0.11, 0.24, 0.16, 0.96)
			border = Color(0.40, 0.83, 0.58)
		elif available:
			fill = Color(0.15, 0.28, 0.18, 0.98)
			border = Color(0.68, 0.96, 0.56)
		elif node["type"] == "Evac":
			fill = Color(0.18, 0.18, 0.19, 0.96)
			border = Color(0.52, 0.52, 0.54)

		if selected:
			border = Color(0.98, 0.88, 0.50)

		button.add_theme_stylebox_override("normal", _button_style(fill, border))
		button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.10), Color(0.98, 0.88, 0.50)))
		button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.05), Color(0.98, 0.88, 0.50)))
		button.add_theme_stylebox_override("disabled", _button_style(fill.darkened(0.04), border))


func _select_first_available() -> void:
	if RunState.available_node_ids.is_empty():
		selected_node_id = RunState.current_node_id
	else:
		selected_node_id = RunState.available_node_ids[0]
	_show_detail(selected_node_id)


func _show_detail(node_id: String) -> void:
	selected_node_id = node_id
	var node: Dictionary = _find_node(node_id)
	if node.is_empty():
		return

	var can_enter: bool = RunState.available_node_ids.has(node_id)
	confirm_button.disabled = not can_enter
	confirm_button.text = I18n.msg("ui.route.confirm") if can_enter else I18n.msg("ui.route.locked")

	detail_title_label.text = I18n.msg(String(node["title_key"]))
	detail_summary_label.text = "[font_size=22][color=#f2c95b]%s[/color][/font_size]\n%s: %s\n%s: %s\n\n%s" % [
		_type_label(node["type"]),
		I18n.msg("ui.stats.threat"),
		_level_label(String(node["threat"])),
		I18n.msg("ui.stats.loot"),
		_level_label(String(node["reward"])),
		_node_description(node),
	]

	_clear_children(detail_tag_flow)
	for tag in node["tags"]:
		detail_tag_flow.add_child(_build_small_badge(I18n.msg(String(tag)), _tag_color(node["type"])))

	_clear_children(detail_attitude_box)
	for member in RunState.squad_members:
		if member["id"] == "player":
			continue
		detail_attitude_box.add_child(_build_attitude_row(member, node))

	_update_button_states()


func _build_attitude_row(member: Dictionary, node: Dictionary) -> Control:
	var attitude: Dictionary = _attitude_for_member(member, node)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.11, 0.88), member["accent"]))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var avatar: ColorRect = ColorRect.new()
	avatar.custom_minimum_size = Vector2(34, 34)
	avatar.color = member["accent"]
	row.add_child(avatar)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name: Label = Label.new()
	name.text = _actor_name(member)
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	text_box.add_child(name)

	var note: Label = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "%s  %s" % [attitude["label"], attitude["reason"]]
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", attitude["color"])
	text_box.add_child(note)

	return panel


func _on_route_button_pressed(node_id: String) -> void:
	_show_detail(node_id)
	if RunState.available_node_ids.has(node_id):
		_confirm_selected_node()


func _confirm_selected_node() -> void:
	var node: Dictionary = _find_node(selected_node_id)
	if node.is_empty() or not RunState.available_node_ids.has(selected_node_id):
		return
	RunState.choose_route_node(node)
	get_tree().change_scene_to_file(ENCOUNTER_SCENE)


func _node(id: String, layer: int, row: float, title_key: String, type: String, threat: String, reward: String, tags: Array, outgoing: Array, threat_delta: int = 0, cohesion_delta: int = 0, loot_delta: int = 0, heat_delta: int = 0) -> Dictionary:
	return {
		"id": id,
		"layer": layer,
		"row": row,
		"title_key": title_key,
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
	var max_layer: float = 5.0
	var content_size: Vector2 = route_board_canvas.size - ROUTE_PADDING * 2.0
	var x_ratio: float = float(layer) / max_layer
	var position: Vector2 = ROUTE_PADDING + Vector2(content_size.x * x_ratio, content_size.y * row)
	return position - ROUTE_BUTTON_SIZE * 0.5


func _button_center(button: Button) -> Vector2:
	return button.position + ROUTE_BUTTON_SIZE * 0.5


func _type_icon(type: String) -> String:
	match type:
		"Battle":
			return I18n.msg("ui.icon.battle")
		"Search":
			return I18n.msg("ui.icon.search")
		"Bond":
			return I18n.msg("ui.icon.bond")
		"Story":
			return I18n.msg("ui.icon.story")
		"Evac":
			return I18n.msg("ui.icon.evac")
		"Supply":
			return I18n.msg("ui.icon.supply")
		"Intel":
			return I18n.msg("ui.icon.intel")
		_:
			return I18n.msg("ui.icon.route")


func _type_label(type: String) -> String:
	match type:
		"Battle":
			return I18n.msg("ui.type.battle")
		"Search":
			return I18n.msg("ui.type.search")
		"Bond":
			return I18n.msg("ui.type.bond")
		"Story":
			return I18n.msg("ui.type.story")
		"Evac":
			return I18n.msg("ui.type.evac")
		"Supply":
			return I18n.msg("ui.type.supply")
		"Intel":
			return I18n.msg("ui.type.intel")
		_:
			return I18n.msg("ui.type.route")


func _tag_color(type: String) -> Color:
	match type:
		"Battle":
			return Color(0.84, 0.35, 0.31)
		"Search":
			return Color(0.94, 0.77, 0.30)
		"Bond":
			return Color(0.56, 0.76, 0.98)
		"Evac":
			return Color(0.40, 0.83, 0.58)
		"Supply":
			return Color(0.52, 0.89, 0.60)
		"Intel":
			return Color(0.61, 0.94, 0.70)
		_:
			return Color(0.72, 0.72, 0.76)


func _node_description(node: Dictionary) -> String:
	match String(node["type"]):
		"Battle":
			return I18n.msg("node.desc.battle")
		"Search":
			return I18n.msg("node.desc.search")
		"Bond":
			return I18n.msg("node.desc.bond")
		"Story":
			return I18n.msg("node.desc.story")
		"Evac":
			return I18n.msg("node.desc.evac")
		"Supply":
			return I18n.msg("node.desc.supply")
		"Intel":
			return I18n.msg("node.desc.intel")
		_:
			return I18n.msg("node.desc.default")


func _member_summary(member: Dictionary) -> String:
	var trust: int = int(member["trust"])
	var greed: int = int(member["greed"])
	if trust >= 65:
		return I18n.msg("ui.route.member_summary_loyal")
	if greed >= 65:
		return I18n.msg("ui.route.member_summary_greedy")
	return I18n.msg("ui.route.member_summary_flexible")


func _attitude_for_member(member: Dictionary, node: Dictionary) -> Dictionary:
	var reward_weight: float = float(_level_value(String(node["reward"])))
	var threat_weight: float = float(_level_value(String(node["threat"])))
	var greed: float = float(member["greed"])
	var caution: float = float(member["caution"])
	var trust: float = float(member["trust"])
	var score: float = reward_weight * greed - threat_weight * caution + trust * 0.25

	if String(node["type"]) == "Evac":
		score = caution * 1.4 + trust * 0.2 - greed * 0.3
	elif String(node["type"]) == "Bond":
		score = trust * 1.1 - threat_weight * 8.0
	elif String(node["type"]) == "Battle":
		score += 12.0

	if score >= 120.0:
		return {"label": I18n.msg("ui.route.attitude_positive"), "reason": I18n.msg("ui.route.attitude_positive_reason"), "color": Color(0.60, 0.92, 0.58)}
	if score >= 85.0:
		return {"label": I18n.msg("ui.route.attitude_neutral"), "reason": I18n.msg("ui.route.attitude_neutral_reason"), "color": Color(0.86, 0.87, 0.64)}
	return {"label": I18n.msg("ui.route.attitude_cautious"), "reason": I18n.msg("ui.route.attitude_cautious_reason"), "color": Color(0.95, 0.67, 0.35)}


func _actor_name(member: Dictionary) -> String:
	return I18n.msg(String(member.get("name_key", "actor.player.name")))


func _actor_role(member: Dictionary) -> String:
	return I18n.msg(String(member.get("role_key", "actor.player.role")))


func _level_label(level: String) -> String:
	match level:
		"Low":
			return I18n.msg("ui.level.low")
		"Mid":
			return I18n.msg("ui.level.mid")
		"High":
			return I18n.msg("ui.level.high")
		_:
			return level


func _level_value(level: String) -> int:
	match level:
		"Low":
			return 1
		"Mid":
			return 2
		"High":
			return 3
		_:
			return 1


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _badge_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.20, color.g * 0.20, color.b * 0.20, 0.92)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(999)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
