extends Node

const DEFAULT_LOCALE := "zh"
const FALLBACK_LOCALE := "en"
const LOCALE_PATH := "res://data/i18n/%s.json"

var current_locale: String = DEFAULT_LOCALE
var _messages: Dictionary = {}
var _fallback_messages: Dictionary = {}


func _ready() -> void:
	set_locale(DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	current_locale = locale
	_messages = _load_locale(locale)
	_fallback_messages = _load_locale(FALLBACK_LOCALE)


func msg(key: String) -> String:
	if _messages.has(key):
		return String(_messages[key])
	if _fallback_messages.has(key):
		return String(_fallback_messages[key])
	return key


func msgf(key: String, values: Array) -> String:
	return msg(key) % values


func _load_locale(locale: String) -> Dictionary:
	var path: String = LOCALE_PATH % locale
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
