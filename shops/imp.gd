class_name ImpMerchant
extends Interactable
var clock := 0.0
var body: Node3D
func _ready() -> void:
	kind = "imp"
	body = Node3D.new()
	add_child(body)
	Geometry.box(body, Vector3.ZERO, Vector3(0.35,0.4,0.25), Color("a374c5"), false)
	Geometry.box(body, Vector3(0,0.32,0), Vector3(0.4,0.32,0.32), Color("bf99d8"), false)
	for side in [-1,1]:
		var wing := Geometry.box(body, Vector3(side*0.35,0.1,0), Vector3(0.42,0.06,0.28), Color("674b89"), false)
		wing.rotation.z = side * 0.4
		Geometry.box(body, Vector3(side*0.13,0.55,0), Vector3(0.08,0.18,0.08), Color("f6cf8c"), false)
		Geometry.box(body, Vector3(side*0.10,0.35,0.17), Vector3(0.06,0.06,0.025), Color("fff0ba"), false)
	Geometry.box(body, Vector3(0,-0.27,0.12), Vector3(0.45,0.15,0.32), Color("75482f"), false)
	Geometry.label(self, Vector3(0,0.95,0), "PIP\nStock & sundries", 23)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(0.95,1.5,0.7)
	c.shape = s
	add_child(c)

func _process(delta: float) -> void:
	clock += delta
	body.position.y = sin(clock * 2.8) * 0.12
	body.rotation.z = sin(clock * 1.4) * 0.05

