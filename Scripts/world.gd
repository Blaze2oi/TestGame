extends Node2D

@onready var bg = $TextureRect
@onready var item_counter = $CanvasLayer/ItemCounter

func _ready():
	bg.texture = preload("res://Assets/Free/Background/Blue.png")
	bg.expand = true
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.size = Vector2(2000, 800) # Set to your game window or level size
