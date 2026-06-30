extends Node

var current_node_id: String = "start"
var visited_node_ids: Array[String] = ["start"]
var traveled_edge_ids: Array[String] = []
var available_node_ids: Array[String] = []
var selected_node: Dictionary = {}
var encounter_deck: Array[Dictionary] = []
var encounter_hand: Array[Dictionary] = []
var encounter_discard: Array[Dictionary] = []
var encounter_log: Array[String] = []
var last_encounter_result: Dictionary = {}

var run_stats: Dictionary = {
	"step": 0,
	"max_step": 5,
	"threat": 35,
	"cohesion": 56,
	"loot": 720,
	"accident_heat": 22,
}

var squad_members: Array[Dictionary] = [
	{
		"id": "player",
		"name": "Player",
		"role": "Leader",
		"hp": 92,
		"bag": 36,
		"trust": 61,
		"greed": 42,
		"caution": 58,
		"accent": Color(0.95, 0.77, 0.28),
	},
	{
		"id": "aqiang",
		"name": "A-Qiang",
		"role": "Assaulter",
		"hp": 78,
		"bag": 54,
		"trust": 47,
		"greed": 74,
		"caution": 35,
		"accent": Color(0.44, 0.74, 0.98),
	},
	{
		"id": "xiaoyu",
		"name": "Xiao Yu",
		"role": "Medic",
		"hp": 86,
		"bag": 28,
		"trust": 72,
		"greed": 26,
		"caution": 69,
		"accent": Color(0.58, 0.90, 0.56),
	},
]


func prepare_encounter_hand() -> void:
	if encounter_deck.is_empty():
		encounter_deck.clear()
		var source_cards: Array[Dictionary] = EncounterResolver.get_basic_cards()
		for i in range(source_cards.size()):
			var card: Dictionary = source_cards[i]
			encounter_deck.append(card.duplicate(true))
	if encounter_hand.is_empty():
		for i in range(mini(3, encounter_deck.size())):
			encounter_hand.append(encounter_deck.pop_front())


func finish_encounter(result: Dictionary) -> void:
	last_encounter_result = result.duplicate(true)
	run_stats = result.get("updated_run_stats", run_stats).duplicate(true)

	squad_members.clear()
	var updated_squad: Array = result.get("updated_squad", [])
	for member in updated_squad:
		squad_members.append(member)

	encounter_log.clear()
	var log_items: Array = result.get("log", [])
	for item in log_items:
		encounter_log.append(String(item))

	var card: Dictionary = result.get("card", {})
	if not card.is_empty():
		encounter_discard.append(card)
		var remaining_hand: Array[Dictionary] = []
		for hand_card in encounter_hand:
			if String(hand_card.get("id", "")) != String(card.get("id", "")):
				remaining_hand.append(hand_card)
		encounter_hand = remaining_hand
	if encounter_deck.size() < 3:
		for i in range(encounter_discard.size()):
			var discard_card: Dictionary = encounter_discard[i]
			encounter_deck.append(discard_card)
		encounter_discard.clear()
	prepare_encounter_hand()


func choose_route_node(node: Dictionary) -> void:
	var previous_node_id: String = current_node_id
	selected_node = node.duplicate(true)
	current_node_id = String(node.get("id", current_node_id))
	var edge_id: String = "%s->%s" % [previous_node_id, current_node_id]
	if previous_node_id != current_node_id and not traveled_edge_ids.has(edge_id):
		traveled_edge_ids.append(edge_id)
	if not visited_node_ids.has(current_node_id):
		visited_node_ids.append(current_node_id)
	run_stats["step"] = int(node.get("layer", run_stats["step"]))
	run_stats["threat"] = clampi(run_stats["threat"] + int(node.get("threat_delta", 0)), 0, 100)
	run_stats["cohesion"] = clampi(run_stats["cohesion"] + int(node.get("cohesion_delta", 0)), 0, 100)
	run_stats["loot"] = maxi(0, run_stats["loot"] + int(node.get("loot_delta", 0)))
	run_stats["accident_heat"] = clampi(run_stats["accident_heat"] + int(node.get("heat_delta", 0)), 0, 100)
