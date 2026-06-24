extends Control

const BACKGROUND := preload("res://assets/ui/chibi_pixel/backgrounds/event-trigger-background.png")
const ROUTE_SCENE := "res://scenes/match/route_map.tscn"


func _ready() -> void:
	_setup_background()
	_setup_content()


func _setup_background() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -20
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.025, 0.035, 0.36)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = -19
	add_child(shade)


func _setup_content() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(360, 170)
	panel.size = Vector2(1200, 690)
	panel.z_index = 10
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.07, 0.09, 0.88), Color(1.0, 0.78, 0.30)))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)

	var node := RunState.selected_node
	var title := Label.new()
	title.text = "Encounter: %s" % String(node.get("title", "Unknown Node"))
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58))
	box.add_child(title)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.custom_minimum_size = Vector2(1120, 360)
	info.add_theme_font_size_override("normal_font_size", 26)
	info.add_theme_color_override("default_color", Color(0.98, 0.93, 0.82))
	info.text = "Type: %s\nThreat: %s    Reward: %s\nTags: %s\n\nThis is the MVP encounter placeholder. Next step: add the 8 command cards, AI obey/hesitate/deviate resolution, and result reasons." % [
		String(node.get("type", "Event")),
		String(node.get("threat", "Medium")),
		String(node.get("reward", "Medium")),
		_join_tags(node.get("tags", [])),
	]
	box.add_child(info)

	var return_button := Button.new()
	return_button.text = "Resolve Placeholder: Back To Route"
	return_button.custom_minimum_size = Vector2(1120, 72)
	return_button.add_theme_font_size_override("font_size", 28)
	return_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.36, 0.25), Color(0.45, 0.95, 0.60)))
	return_button.add_theme_stylebox_override("hover", _button_style(Color(0.28, 0.46, 0.30), Color(1.0, 0.88, 0.35)))
	return_button.pressed.connect(func(): get_tree().change_scene_to_file(ROUTE_SCENE))
	box.add_child(return_button)


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


func _join_tags(tags: Array) -> String:
	var parts: PackedStringArray = []
	for tag in tags:
		parts.append(String(tag))
	return " / ".join(parts)


func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	return style
