extends Control

# Root scene controller — switches between Select and Arena.

@onready var current_scene: Node = null

const SELECT_SCENE = preload("res://scenes/Select.tscn")
const ARENA_SCENE  = preload("res://scenes/Arena.tscn")

func _ready():
	_load_select()

func _load_select():
	if current_scene:
		current_scene.queue_free()
	current_scene = SELECT_SCENE.instantiate()
	current_scene.fight_started.connect(_on_fight_started)
	add_child(current_scene)

func _on_fight_started(left_id: String, right_id: String):
	if current_scene:
		current_scene.queue_free()
	current_scene = ARENA_SCENE.instantiate()
	current_scene.battle_finished.connect(_on_battle_finished)
	add_child(current_scene)
	current_scene.start_battle(left_id, right_id)

func _on_battle_finished():
	_load_select()
