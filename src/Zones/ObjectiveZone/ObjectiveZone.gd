extends Area2D

signal objective_entered(object)

func _ready():
	pass


func _on_ObjectiveZone_body_entered(body):
	if (body.is_in_group("Player")):
		emit_signal("objective_entered",self)
		queue_free()
