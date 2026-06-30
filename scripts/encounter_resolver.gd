class_name EncounterResolver
extends RefCounted


static func get_basic_cards() -> Array[Dictionary]:
	return [
		{
			"id": "attack_push",
			"name_key": "card.attack_push.name",
			"type_key": "card.attack_push.type",
			"summary_key": "card.attack_push.summary",
			"risk_key": "card.attack_push.risk",
		},
		{
			"id": "suppress_fire",
			"name_key": "card.suppress_fire.name",
			"type_key": "card.suppress_fire.type",
			"summary_key": "card.suppress_fire.summary",
			"risk_key": "card.suppress_fire.risk",
		},
		{
			"id": "scramble_loot",
			"name_key": "card.scramble_loot.name",
			"type_key": "card.scramble_loot.type",
			"summary_key": "card.scramble_loot.summary",
			"risk_key": "card.scramble_loot.risk",
		},
		{
			"id": "steal_bag",
			"name_key": "card.steal_bag.name",
			"type_key": "card.steal_bag.type",
			"summary_key": "card.steal_bag.summary",
			"risk_key": "card.steal_bag.risk",
		},
		{
			"id": "fallback",
			"name_key": "card.fallback.name",
			"type_key": "card.fallback.type",
			"summary_key": "card.fallback.summary",
			"risk_key": "card.fallback.risk",
		},
		{
			"id": "rear_guard",
			"name_key": "card.rear_guard.name",
			"type_key": "card.rear_guard.type",
			"summary_key": "card.rear_guard.summary",
			"risk_key": "card.rear_guard.risk",
		},
	]


static func get_shouts() -> Array[Dictionary]:
	return [
		{"id": "none", "name_key": "shout.none.name", "summary_key": "shout.none.summary"},
		{"id": "follow", "name_key": "shout.follow.name", "summary_key": "shout.follow.summary"},
		{"id": "retreat", "name_key": "shout.retreat.name", "summary_key": "shout.retreat.summary"},
		{"id": "cover", "name_key": "shout.cover.name", "summary_key": "shout.cover.summary"},
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
	log.append(I18n.msgf("log.played_card", [I18n.msg(String(card["name_key"]))]))

	match card_id:
		"attack_push":
			var followers: int = _count_intent(ai_intents, "follow")
			run_delta["threat"] = -6 if followers > 0 else 6
			run_delta["cohesion"] = 4 if followers > 0 else -6
			player["hp"] = clampi(int(player["hp"]) - (4 if followers > 0 else 12), 0, 100)
			log.append(I18n.msgf("log.attack_push", [followers]))
		"suppress_fire":
			run_delta["threat"] = -8
			run_delta["cohesion"] = 2
			player["hp"] = clampi(int(player["hp"]) - 3, 0, 100)
			log.append(I18n.msg("log.suppress_fire"))
		"scramble_loot":
			var loot_gain: int = 34
			player["bag"] = int(player["bag"]) + loot_gain
			run_delta["loot"] = loot_gain
			run_delta["accident_heat"] = 8
			run_delta["cohesion"] = -4
			log.append(I18n.msg("log.scramble_loot"))
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
				log.append(I18n.msgf("log.steal_bag", [_actor_name(target), stolen]))
		"fallback":
			run_delta["threat"] = -4
			run_delta["accident_heat"] = -6
			run_delta["cohesion"] = -2 if _count_intent(ai_intents, "attack") > 0 else 2
			log.append(I18n.msg("log.fallback"))
		"rear_guard":
			run_delta["threat"] = -3
			run_delta["cohesion"] = 6
			run_delta["accident_heat"] = -4
			player["hp"] = clampi(int(player["hp"]) - 5, 0, 100)
			for i in range(1, updated_squad.size()):
				var ally: Dictionary = updated_squad[i]
				ally["trust"] = clampi(int(ally["trust"]) + 4, 0, 100)
				updated_squad[i] = ally
			log.append(I18n.msg("log.rear_guard"))

	if shout_id == "follow" and card_id in ["attack_push", "suppress_fire"]:
		run_delta["cohesion"] += 2
		log.append(I18n.msg("log.shout_follow"))
	elif shout_id == "cover" and card_id in ["fallback", "rear_guard"]:
		run_delta["cohesion"] += 3
		log.append(I18n.msg("log.shout_cover"))
	elif shout_id == "retreat":
		run_delta["accident_heat"] -= 2
		log.append(I18n.msg("log.shout_retreat"))

	updated_squad[0] = player
	var updated_run: Dictionary = run_stats.duplicate(true)
	for key in run_delta.keys():
		if key == "loot":
			updated_run[key] = maxi(0, int(updated_run.get(key, 0)) + int(run_delta[key]))
		else:
			updated_run[key] = clampi(int(updated_run.get(key, 0)) + int(run_delta[key]), 0, 100)

	for intent in ai_intents:
		log.append(I18n.msgf("log.intent", [
			String(intent["actor_name"]),
			String(intent["label"]),
			String(intent["reason"]),
		]))

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
		return _intent(actor, "steal_bag", "intent.steal_bag.label", "intent.steal_bag.reason")
	if shout_id == "retreat" or card_id == "fallback" or node_type == "Evac" or hp < 45:
		if caution + bag > 86:
			return _intent(actor, "retreat", "intent.retreat.label", "intent.retreat.reason")
	if node_type in ["Search", "Intel", "Supply"] and greed + heat > trust + caution:
		return _intent(actor, "solo_loot", "intent.solo_loot.label", "intent.solo_loot.reason")
	if card_id in ["attack_push", "suppress_fire"] and trust + (10 if shout_id == "follow" else 0) > caution:
		return _intent(actor, "follow", "intent.follow.label", "intent.follow.reason")
	if caution > greed + 20:
		return _intent(actor, "hold", "intent.hold.label", "intent.hold.reason")
	return _intent(actor, "attack", "intent.attack.label", "intent.attack.reason")


static func _intent(actor: Dictionary, id: String, label: String, reason: String) -> Dictionary:
	return {
		"actor_id": actor.get("id", ""),
		"actor_name": _actor_name(actor),
		"id": id,
		"label": I18n.msg(label),
		"reason": I18n.msg(reason),
	}


static func _actor_name(actor: Dictionary) -> String:
	if actor.has("name_key"):
		return I18n.msg(String(actor["name_key"]))
	return String(actor.get("name", "AI"))


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
