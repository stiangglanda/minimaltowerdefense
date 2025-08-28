extends CanvasLayer

signal build_tower_selected(tower_data: Dictionary)

const ARCHER_TOWER_DATA = {
	"scene": preload("res://scenes/tower.tscn"),
	"cost": 10
}

@onready var archer_button: Button = $Control/BuildMenu/AspectRatioContainer/Button

func _ready():
	archer_button.pressed.connect(_on_archer_tower_button_pressed)
	archer_button.text = "Archer Tower\n%d Gold" % ARCHER_TOWER_DATA.cost

func _on_archer_tower_button_pressed():
	build_tower_selected.emit(ARCHER_TOWER_DATA)

func on_player_gold_updated(new_gold_amount: int):
	archer_button.disabled = new_gold_amount < ARCHER_TOWER_DATA.cost
