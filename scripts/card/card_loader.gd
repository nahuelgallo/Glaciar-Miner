class_name CardLoader
extends RefCounted

const DB_PATH := "res://data/cards/cards.json"


static func load_all() -> Array[CardData]:
	var result: Array[CardData] = []
	var file := FileAccess.open(DB_PATH, FileAccess.READ)
	if file == null:
		push_error("CardLoader: no se pudo abrir " + DB_PATH)
		return result
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		push_error("CardLoader: JSON raíz debe ser un array")
		return result
	for entry in parsed:
		if entry is Dictionary:
			result.append(CardData.from_dict(entry))
	return result
