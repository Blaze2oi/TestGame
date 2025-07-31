extends Area2D

@export var item_id: String = "Fruit" # Unique identifier for this type of item
@export var collection_value: int = 1 # How many items this collectable counts as

signal collected(item_id, value)

func _ready():
	# Ensure the Area2D has a collision shape
	if not get_node_or_null("CollisionShape2D"):
		print("Warning: Collectable item needs a CollisionShape2D child.")
	# Play the default animation
	$AnimatedSprite2D.play("default")

func _on_body_entered(body):
	# Check if the entering body is the player
	if body.has_method("collect_item"):
		# Emit the signal to the player
		emit_signal("collected", item_id, collection_value)
		# Play the collected animation
		$AnimatedSprite2D.play("collected")
		# Wait for the animation to finish before queue_freeing
		await $AnimatedSprite2D.animation_finished
		queue_free() # Remove the collectable from the scene
