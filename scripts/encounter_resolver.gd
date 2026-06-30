class_name EncounterResolver
extends RefCounted


static func get_basic_cards() -> Array[Dictionary]:
	return [
		{
			"id": "attack_push",
			"name": "Strong Push",
			"type": "Attack",
			"summary": "Break the front and ask others to follow.",
			"risk": "Bad if nobody follows.",
		},
		{
			"id": "suppress_fire",
			"name": "Suppress Fire",
			"type": "Attack",
			"summary": "Lower immediate threat and stabilize the fight.",
			"risk": "Low loot this turn.",
		},
		{
			"id": "scramble_loot",
			"name": "Scramble Loot",
			"type": "Resource",
			"summary": "Grab supplies while everyone is distracted.",
			"risk": "Greedy teammates may split.",
		},
		{
			"id": "steal_bag",
			"name": "Steal Bag",
			"type": "Resource",
			"summary": "Take goods from the richest teammate.",
			"risk": "Infamy and heat rise sharply.",
		},
		{
			"id": "fallback",
			"name": "Fallback",
			"type": "Survival",
			"summary": "Step back and push toward evacuation.",
			"risk": "Aggressive teammates may refuse.",
		},
		{
			"id": "rear_guard",
			"name": "Rear Guard",
			"type": "Support",
			"summary": "Cover a teammate and keep the group readable.",
			"risk": "You take the dangerous job.",
		},
	]


static func get_shouts() -> Array[Dictionary]:
	return [
		{"id": "none", "name": "No Shout", "summary": "Let the card speak for itself."},
		{"id": "follow", "name": "Follow me!", "summary": "Raises follow intent if trust is decent."},
		{"id": "retreat", "name": "Pull back!", "summary": "Raises retreat intent."},
		{"id": "cover", "name": "I cover you.", "summary": "Raises trust if you play support or survival."},
	]


static func resolve_encounter(node: Dictionary, squad: Array[Dictionary], run_stats: Dictionary, card_id: String, shout_id: String) -> Dictionary:
	var card: Dictionary = _find_by_id(get_basic_cards(), card_id)
	if card.is_empty():
		card = get_basic_cards()[0]

	var updated_squad: Array[Dictionary] = squad.duplicate(true)
	var player: Dictionary = updated_squad[0]
	var ai_intents: Array[Dictionary] = []
	for i in range(1, updated_squad.size()):
		var actor: Dictionary = updated_squad[i]
		var intent: Dictionary = _choose_ai_intent(actor, node, run_stats, card_id, shout_id)
		ai_intents.append(intent)
		_apply_ai_intent(actor, intent)
		updated_squad[i] = actor

	var run_delta: Dictionary = {
		"threat": 0,
		"cohesion": 0,
		"loot": 0,
		"accident_heat": 0,
	}
	var log: Array[String] = []
	log.append("You played %s." % card["name"])

	match card_id:
		"attack_push":
			var followers: int = _count_intent(ai_intents, "follow")
			run_delta["threat"] = -6 if followers > 0 else 6
			run_delta["cohesion"] = 4 if followers > 0 else -6
			player["hp"] = clampi(int(player["hp"]) - (4 if followers > 0 else 12), 0, 100)
			log.append("The push had %d teammate(s) behind it." % followers)
		"suppress_fire":
			run_delta["threat"] = -8
			run_delta["cohesion"] = 2
			player["hp"] = clampi(int(player["hp"]) - 3, 0, 100)
			log.append("Suppressive fire bought a quieter turn.")
		"scramble_loot":
			var loot_gain: int = 34
			player["bag"] = int(player["bag"]) + loot_gain
			run_delta["loot"] = loot_gain
			run_delta["accident_heat"] = 8
			run_delta["cohesion"] = -4
			log.append("You grabbed supplies before the team settled the room.")
		"steal_bag":
			var target_index: int = _richest_teammate_index(updated_squad)
			if target_index >= 1:
				var target: Dictionary = updated_squad[target_index]
				var stolen = mini(24, int(target["bag"]))
				target["bag"] = maxi(0, int(target["bag"]) - stolen)
				target["trust"] = clampi(int(target["trust"]) - 18, 0, 100)
				player["bag"] = int(player["bag"]) + stolen
				updated_squad[target_index] = target
				run_delta["loot"] = stolen
				run_delta["cohesion"] = -12
				run_delta["accident_heat"] = 16
				log.append("You stole %d loot from %s." % [stolen, target["name"]])
		"fallback":
			run_delta["threat"] = -4
			run_delta["accident_heat"] = -6
			run_delta["cohesion"] = -2 if _count_intent(ai_intents, "attack") > 0 else 2
			log.append("You created distance and looked for a safer exit.")
		"rear_guard":
			run_delta["threat"] = -3
			run_delta["cohesion"] = 6
			run_delta["accident_heat"] = -4
			player["hp"] = clampi(int(player["hp"]) - 5, 0, 100)
			for i in range(1, updated_squad.size()):
				var ally: Dictionary = updated_squad[i]
				ally["trust"] = clampi(int(ally["trust"]) + 4, 0, 100)
				updated_squad[i] = ally
			log.append("The team noticed you stayed back to cover them.")

	if shout_id == "follow" and card_id in ["attack_push", "suppress_fire"]:
		run_delta["cohesion"] += 2
		log.append("Your shout made the plan easier to read.")
	elif shout_id == "cover" and card_id in ["fallback", "rear_guard"]:
		run_delta["cohesion"] += 3
		log.append("The cover call sounded believable this time.")
	elif shout_id == "retreat":
		run_delta["accident_heat"] -= 2
		log.append("The retreat call lowered the immediate panic.")

	updated_squad[0] = player
	var updated_run: Dictionary = run_stats.duplicate(true)
	for key in run_delta.keys():
		if key == "loot":
			updated_run[key] = maxi(0, int(updated_run.get(key, 0)) + int(run_delta[key]))
		else:
			updated_run[key] = clampi(int(updated_run.get(key, 0)) + int(run_delta[key]), 0, 100)

	for intent in ai_intents:
		log.append("%s: %s (%s)" % [intent["actor_name"], intent["label"], intent["reason"]])

	return {
		"card": card,
		"shout_id": shout_id,
		"ai_intents": ai_intents,
		"run_delta": run_delta,
		"updated_run_stats": updated_run,
		"updated_squad": updated_squad,
		"log": log,
		"is_evac_node": String(node.get("type", "")) == "Evac",
	}


static func _find_by_id(items: Array[Dictionary], id: String) -> Dictionary:
	for item in items:
		if String(item.get("id", "")) == id:
			return item
	return {}


static func _choose_ai_intent(actor: Dictionary, node: Dictionary, run_stats: Dictionary, card_id: String, shout_id: String) -> Dictionary:
	var node_type: String = String(node.get("type", "Event"))
	var greed: int = int(actor.get("greed", 50))
	var trust: int = int(actor.get("trust", 50))
	var caution: int = int(actor.get("caution", 50))
	var heat: int = int(run_stats.get("accident_heat", 0))
	var bag: int = int(actor.get("bag", 0))
	var hp: int = int(actor.get("hp", 100))

	if card_id == "steal_bag" and greed + heat > 82:
		return _intent(actor, "steal_bag", "Eyes on bags", "your theft made looting feel allowed")
	if shout_id == "retreat" or card_id == "fallback" or node_type == "Evac" or hp < 45:
		if caution + bag > 86:
			return _intent(actor, "retreat", "Pulling out", "survival and carried loot beat teamwork")
	if node_type in ["Search", "Intel", "Supply"] and greed + heat > trust + caution:
		return _intent(actor, "solo_loot", "Solo loot", "high greed and messy conditions")
	if card_id in ["attack_push", "suppress_fire"] and trust + (10 if shout_id == "follow" else 0) > caution:
		return _intent(actor, "follow", "Following", "trust beats caution this turn")
	if caution > greed + 20:
		return _intent(actor, "hold", "Holding", "caution is winning")
	return _intent(actor, "attack", "Freelance attack", "the situation looks open enough")


static func _intent(actor: Dictionary, id: String, label: String, reason: String) -> Dictionary:
	return {
		"actor_id": actor.get("id", ""),
		"actor_name": actor.get("name", "AI"),
		"id": id,
		"label": label,
		"reason": reason,
	}


static func _apply_ai_intent(actor: Dictionary, intent: Dictionary) -> void:
	match String(intent["id"]):
		"solo_loot":
			actor["bag"] = int(actor["bag"]) + 18
			actor["trust"] = clampi(int(actor["trust"]) - 4, 0, 100)
		"steal_bag":
			actor["bag"] = int(actor["bag"]) + 10
			actor["trust"] = clampi(int(actor["trust"]) - 7, 0, 100)
		"retreat":
			actor["caution"] = clampi(int(actor["caution"]) + 3, 0, 100)
		"follow":
			actor["trust"] = clampi(int(actor["trust"]) + 2, 0, 100)
		"attack":
			actor["hp"] = clampi(int(actor["hp"]) - 4, 0, 100)


static func _count_intent(intents: Array[Dictionary], id: String) -> int:
	var count: int = 0
	for intent in intents:
		if String(intent.get("id", "")) == id:
			count += 1
	return count


static func _richest_teammate_index(squad: Array[Dictionary]) -> int:
	var best_index: int = -1
	var best_bag: int = -1
	for i in range(1, squad.size()):
		var actor: Dictionary = squad[i]
		var bag: int = int(actor.get("bag", 0))
		if bag > best_bag:
			best_bag = bag
			best_index = i
	return best_index
