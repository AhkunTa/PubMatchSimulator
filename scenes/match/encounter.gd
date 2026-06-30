extends Control

const ROUTE_SCENE := "res://scenes/match/route_map.tscn"

var selected_card_id: String = ""
var shout_ids: Array[String] = []
var card_buttons: Array[Button] = []

@onready var title_label: Label = %TitleLabel
@onready var node_info_label: Label = %NodeInfoLabel
@onready var stats_label: Label = %StatsLabel
@onready var scene_text_label: RichTextLabel = %SceneTextLabel
@onready var player_label: RichTextLabel = %PlayerLabel
@onready var ally_1_label: RichTextLabel = %Ally1Label
@onready var ally_2_label: RichTextLabel = %Ally2Label
@onready var intent_1_label: Label = %Intent1Label
@onready var intent_2_label: Label = %Intent2Label
@onready var card_button_1: Button = %CardButton1
@onready var card_button_2: Button = %CardButton2
@onready var card_button_3: Button = %CardButton3
@onready var shout_option: OptionButton = %ShoutOption
@onready var selected_card_label: Label = %SelectedCardLabel
@onready var resolve_button: Button = %ResolveButton
@onready var result_log_label: RichTextLabel = %ResultLogLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	card_buttons = [card_button_1, card_button_2, card_button_3]
	RunState.prepare_encounter_hand()
	_bind_actions()
	_apply_static_i18n()
	_populate_shouts()
	_render_all()
	if not RunState.encounter_hand.is_empty():
		_select_card(String(RunState.encounter_hand[0].get("id", "")))


func _bind_actions() -> void:
	card_button_1.pressed.connect(func(): _select_card_by_index(0))
	card_button_2.pressed.connect(func(): _select_card_by_index(1))
	card_button_3.pressed.connect(func(): _select_card_by_index(2))
	resolve_button.pressed.connect(_resolve_current_card)
	continue_button.pressed.connect(func(): get_tree().change_scene_to_file(ROUTE_SCENE))
	shout_option.item_selected.connect(func(_index: int): _render_intent_preview())


func _apply_static_i18n() -> void:
	(get_node("RootMargin/RootColumn/ContentRow/SquadPanel/SquadBox/SquadHeading") as Label).text = I18n.msg("ui.encounter.squad")
	(get_node("RootMargin/RootColumn/ContentRow/MainPanel/MainBox/IntentPanel/IntentBox/IntentHeading") as Label).text = I18n.msg("ui.encounter.intent")
	(get_node("RootMargin/RootColumn/ContentRow/ResultPanel/ResultBox/ResultHeading") as Label).text = I18n.msg("ui.encounter.result")
	resolve_button.text = I18n.msg("ui.encounter.resolve")
	continue_button.text = I18n.msg("ui.encounter.back")
	selected_card_label.text = I18n.msg("ui.encounter.select_card")


func _populate_shouts() -> void:
	shout_option.clear()
	shout_ids.clear()
	for shout in EncounterResolver.get_shouts():
		shout_ids.append(String(shout["id"]))
		shout_option.add_item("%s - %s" % [
			I18n.msg(String(shout["name_key"])),
			I18n.msg(String(shout["summary_key"])),
		])


func _render_all() -> void:
	_render_header()
	_render_squad()
	_render_cards()
	_render_result()
	_render_intent_preview()


func _render_header() -> void:
	var node: Dictionary = RunState.selected_node
	title_label.text = I18n.msg(String(node.get("title_key", "ui.encounter.title_fallback")))
	node_info_label.text = I18n.msgf("ui.encounter.node_info", [
		_type_label(String(node.get("type", "Event"))),
		_level_label(String(node.get("threat", "Mid"))),
		_level_label(String(node.get("reward", "Mid"))),
		_join_tags(node.get("tags", [])),
	])
	stats_label.text = I18n.msgf("ui.encounter.stats", [
		int(RunState.run_stats["threat"]),
		int(RunState.run_stats["cohesion"]),
		int(RunState.run_stats["loot"]),
		int(RunState.run_stats["accident_heat"]),
	])
	scene_text_label.text = I18n.msgf("ui.encounter.scene_prompt", [
		I18n.msg(String(node.get("title_key", "ui.encounter.title_fallback"))),
		_node_description(node),
	])


func _render_squad() -> void:
	var labels: Array[RichTextLabel] = [player_label, ally_1_label, ally_2_label]
	for i in range(mini(labels.size(), RunState.squad_members.size())):
		var member: Dictionary = RunState.squad_members[i]
		labels[i].text = I18n.msgf("ui.squad.role_line", [
			_actor_name(member),
			I18n.msg("ui.squad.you") if String(member["id"]) == "player" else "",
			_actor_role(member),
			int(member["hp"]),
			int(member["bag"]),
			int(member["trust"]),
			int(member["greed"]),
			int(member["caution"]),
		])


func _render_cards() -> void:
	for i in range(card_buttons.size()):
		var button: Button = card_buttons[i]
		if i >= RunState.encounter_hand.size():
			button.disabled = true
			button.text = "-"
			continue
		var card: Dictionary = RunState.encounter_hand[i]
		button.disabled = false
		var marker: String = I18n.msg("ui.encounter.selected_marker") if String(card.get("id", "")) == selected_card_id else ""
		button.text = I18n.msgf("ui.encounter.card_button", [
			marker,
			I18n.msg(String(card["name_key"])),
			I18n.msg(String(card["type_key"])),
			I18n.msg(String(card["summary_key"])),
			I18n.msg(String(card["risk_key"])),
		])


func _render_intent_preview() -> void:
	var preview: Dictionary = EncounterResolver.resolve_encounter(
		RunState.selected_node,
		RunState.squad_members,
		RunState.run_stats,
		selected_card_id,
		_current_shout_id()
	)
	var intents: Array = preview.get("ai_intents", [])
	intent_1_label.text = _intent_line(intents, 0)
	intent_2_label.text = _intent_line(intents, 1)


func _render_result() -> void:
	if RunState.encounter_log.is_empty():
		result_log_label.text = I18n.msg("ui.encounter.no_result")
		return
	result_log_label.text = "\n".join(RunState.encounter_log)


func _select_card_by_index(index: int) -> void:
	if index < 0 or index >= RunState.encounter_hand.size():
		return
	_select_card(String(RunState.encounter_hand[index].get("id", "")))


func _select_card(card_id: String) -> void:
	selected_card_id = card_id
	var card: Dictionary = _current_card()
	selected_card_label.text = I18n.msgf("ui.encounter.selected", [
		I18n.msg(String(card.get("type_key", ""))),
		I18n.msg(String(card.get("summary_key", ""))),
	])
	_render_cards()
	_render_intent_preview()


func _resolve_current_card() -> void:
	if selected_card_id.is_empty():
		return
	var result: Dictionary = EncounterResolver.resolve_encounter(
		RunState.selected_node,
		RunState.squad_members,
		RunState.run_stats,
		selected_card_id,
		_current_shout_id()
	)
	RunState.finish_encounter(result)
	if RunState.encounter_hand.is_empty():
		RunState.prepare_encounter_hand()
	selected_card_id = String(RunState.encounter_hand[0].get("id", "")) if not RunState.encounter_hand.is_empty() else ""
	_render_all()


func _current_card() -> Dictionary:
	for card in RunState.encounter_hand:
		if String(card.get("id", "")) == selected_card_id:
			return card
	return {}


func _current_shout_id() -> String:
	var index: int = shout_option.selected
	if index < 0 or index >= shout_ids.size():
		return "none"
	return shout_ids[index]


func _intent_line(intents: Array, index: int) -> String:
	if index >= intents.size():
		return I18n.msg("ui.encounter.no_intent")
	var intent: Dictionary = intents[index]
	return I18n.msgf("ui.encounter.intent_line", [
		String(intent.get("actor_name", "AI")),
		String(intent.get("label", "Unknown")),
		String(intent.get("reason", "unclear")),
	])


func _node_description(node: Dictionary) -> String:
	var node_type: String = String(node.get("type", "Event"))
	match node_type:
		"Battle":
			return I18n.msg("encounter.desc.battle")
		"Search", "Intel", "Supply":
			return I18n.msg("encounter.desc.resource")
		"Evac":
			return I18n.msg("encounter.desc.evac")
		"Bond":
			return I18n.msg("encounter.desc.bond")
		_:
			return I18n.msg("encounter.desc.default")


func _join_tags(tags: Array) -> String:
	if tags.is_empty():
		return "-"
	var parts: PackedStringArray = []
	for tag in tags:
		parts.append(I18n.msg(String(tag)))
	return " / ".join(parts)


func _actor_name(member: Dictionary) -> String:
	return I18n.msg(String(member.get("name_key", "actor.player.name")))


func _actor_role(member: Dictionary) -> String:
	return I18n.msg(String(member.get("role_key", "actor.player.role")))


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
