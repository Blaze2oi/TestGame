extends Area2D

@export var item_id: String = "Fruit" 
@export var collection_value: int = 1 

signal collected(item_id, value)

# --- 1. TRACKING VARIABLE ---
var has_been_collected: bool = false

func _ready():
	if not get_node_or_null("CollisionShape2D"):
		print("Warning: Collectable item needs a CollisionShape2D child.")
	$AnimatedSprite2D.play("default")

func _on_body_entered(body):
	if body.has_method("collect_item"):
		
		# --- 2. THE WATCHDOG TRAP ---
		# If this is false, the rule passes. If it's true, the Watchdog screams!
		QAManager.assert_rule(
			not has_been_collected,
			"Double Collect Glitch",
			"The AI managed to collect an apple that was already playing its death animation!",
			{"apple_id": item_id, "apple_pos": position, "player_velocity": body.velocity}
		)
		
		# Immediately flag it as collected so the rule breaks if touched again
		has_been_collected = true 
		
		# --- 3. YOUR NORMAL LOGIC ---
		emit_signal("collected", item_id, collection_value)
		$AnimatedSprite2D.play("collected")
		await $AnimatedSprite2D.animation_finished
		queue_free()
