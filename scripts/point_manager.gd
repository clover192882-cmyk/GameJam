extends Node

signal points_changed(new_points: int, delta: int)
signal game_over
signal health_changed(new_health: int)

const STARTING_POINTS := 100
const MAX_HEALTH := 3

var points := STARTING_POINTS
var is_game_over := false
var health := MAX_HEALTH
var round_start_points := 0


func reset() -> void:
	points = STARTING_POINTS
	health = MAX_HEALTH
	is_game_over = false
	points_changed.emit(points, 0)
	health_changed.emit(health)


func load_points(saved: int, saved_health := MAX_HEALTH) -> void:
	health = clampi(saved_health, 1, MAX_HEALTH)
	points = maxi(saved, 0 if health < MAX_HEALTH else 1)
	is_game_over = false
	health_changed.emit(health)


func add_points(amount: int) -> void:
	if is_game_over or amount <= 0:
		return
	points += amount
	points_changed.emit(points, amount)


func deduct_points(amount: int) -> void:
	if is_game_over or amount <= 0:
		return
	points = maxi(points - amount, 0)
	points_changed.emit(points, -amount)


func begin_round() -> void:
	round_start_points = points


# Ends a round: finishing with 0 points costs a heart, and losing the last heart ends the run.
# Returns {start, final, net, health_lost, game_over}.
func finish_round() -> Dictionary:
	var health_lost := false
	if points <= 0 and not is_game_over:
		health = maxi(health - 1, 0)
		health_lost = true
		health_changed.emit(health)
		if health <= 0:
			is_game_over = true
			game_over.emit()
	return {"start": round_start_points, "final": points, "net": points - round_start_points,
		"health_lost": health_lost, "game_over": is_game_over}


# Spending must leave at least 1 point, so buying an unlock can never cause Game Over.
func can_afford(cost: int) -> bool:
	return not is_game_over and cost > 0 and points - cost >= 1


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	points -= cost
	points_changed.emit(points, -cost)
	return true
