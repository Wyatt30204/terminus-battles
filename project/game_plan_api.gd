extends RefCounted

var actions: Array[Dictionary] = []
var money: float = 0.0
var lives := 0
var round_number := 1
var streak_count := 0


func build(kind: String, x: int, y: int) -> void:
	actions.append({"op": "build", "kind": kind.to_lower(), "x": x, "y": y})


func send(kind: String, count: int = 1, target: String = "") -> void:
	actions.append({"op": "send", "kind": kind.to_lower(), "count": count, "target": target})


func upgrade(x: int, y: int) -> void:
	actions.append({"op": "upgrade", "x": x, "y": y})


func upgrade_all(kind: String) -> void:
	actions.append({"op": "upgrade_all", "kind": kind.to_lower()})


func repair(x: int, y: int) -> void:
	actions.append({"op": "repair", "x": x, "y": y})


func spikes(x: int, y: int) -> void:
	actions.append({"op": "spikes", "x": x, "y": y})


func streak(kind: String) -> void:
	actions.append({"op": "streak", "kind": kind.to_lower()})


func nuke() -> void:
	actions.append({"op": "streak", "kind": "nuke"})
