extends Node2D

onready var game_scene: GameScene = get_parent()

var objectives: Dictionary = {
	1:{"objective_name":"Enter the bank",
	"objective_subtitle":"BAIN: This is our target. Get inside and case the joint.",
	"subtitle_priority":2,
	"subtitle_length":5},
	2:{"objective_name":"Find the vault",
	"objective_subtitle":"BAIN: Good, you're inside. Look for a vault. I think it's in the back areas.",
	"subtitle_priority":2,
	"subtitle_length":7},	
	3:{"objective_name":"Find the manager's office",
	"objective_subtitle":"BAIN: Hmm... Looks like we need a special keycard and a vault code. Best bet you'll find these in the manager's office. Go find it.",
	"subtitle_priority":2,
	"subtitle_length":10},
	4:{"objective_name":"Look for a way to open the office",
	"objective_subtitle":"BAIN: And.. crap! What is he locking inside for anyway? Look for a way to get him out of there or try finding backup keys for his room.",
	"subtitle_priority":2,
	"subtitle_length":12},
	5:{"objective_name":"Enter the manager's room"},
	6:{"objective_name":"Get the code and keycard",
	"objective_subtitle":"BAIN: Great. Now look around. The keycard must be in this room. As for the code it must be on his computer or in his head.",
	"subtitle_priority":2,
	"subtitle_length":10},
	7:{"objective_name":"Open the vault",
	"objective_subtitle":"BAIN: Perfect! You got both items needed! Head to that panel near the vault door. You should be able to open the vault now.",
	"subtitle_priority":2,
	"subtitle_length":10},
	8:{"objective_name":"Find the drill",
	"objective_subtitle":"BAIN: Crap! Why did you trigger the alarm? Now we have to switch to plan B, go find the thermal drill.",
	"subtitle_priority":2,
	"subtitle_length":10},
	9:{"objective_name":"Mount the drill",
	"objective_subtitle":"BAIN: Okay, this looks like the thing. Get back to the vault and mount it.",
	"subtitle_priority":2,
	"subtitle_length":7.5},
	10:{"objective_name":"Wait for the drill to end",
	"objective_subtitle":"BAIN: Well, you know what comes now. Watch for the drill, it can jam.",
	"subtitle_priority":2,
	"subtitle_length":7},
	12:{"objective_name":"Secure one bag of cash",
	"objective_subtitle":"BAIN: Vault's open! We need one bag of cash. You know where the van is.",
	"subtitle_priority":2,
	"subtitle_length":12},
	13:{"objective_name":"Escape",
	"objective_subtitle":"BAIN: Perfect. You can escape now, or hang around for more loot. I won't complain.",
	"subtitle_priority":2,
	"subtitle_length":7.5},
}

var current_objective: int = 0

var camera_amounts: Array = [8,10,12,14]
var guard_amounts: Array = [4,6,8,8]

var camera_amount: int = camera_amounts[Game.difficulty]
var guard_amount: int = guard_amounts[Game.difficulty]

var secured_bags: int = 0

var has_found_drill: bool = false
var has_found_office: bool = false
var has_found_number: bool = false
var has_shown_note_dialouge: bool = false

onready var drill_bag = $Objectives/Drill_bag
onready var key_door = $Objectives/KeyDoor
onready var phone = $Objectives/Phone
onready var red_kc = $Objectives/Red_keycard
onready var pc = $Objectives/PC
onready var vault_panel = $Objectives/Vault_panel
onready var vault = $Objectives/Vault
onready var van = $Objectives/Van

onready var manager_point = $NPCs/Manager_point
onready var manager = $NPCs/Manager

func _ready():
	Game.map = self
	Game.map_nav = $Navigation2D
	Game.map_objects = $Objects
	Game.map_guard_restpoints = $NPCs/Guards/RestPoints
	Game.map_empl_restpoints = $NPCs/Employees/RestPoints
	Game.map_escape_zone = $NPCs/Escape_Zone

	var camera: Camera2D = Game.player.get_node("Player_camera")
	var ground_size: Rect2 = $Ground.get_used_rect()
	
	camera.limit_top = (ground_size.position.y * 128) + 128
	camera.limit_bottom = (ground_size.end.y * 128) - 128
	camera.limit_left = (ground_size.position.x * 128) + 128
	camera.limit_right = (ground_size.size.x * 128) - 256
	
	for item in $Objectives/Notes.get_children():
		if (item.name.find("Note") != -1):
			item.connect("object_interaction_finished",self,"interaction_finish")
			
	drill_bag.connect("object_interaction_finished",self,"interaction_finish")
	phone.connect("object_interaction_finished",self,"interaction_finish")
	key_door.connect("object_interaction_finished",self,"interaction_finish")
	red_kc.connect("object_interaction_finished",self,"interaction_finish")
	pc.connect("object_interaction_finished",self,"interaction_finish")
	vault_panel.connect("object_interaction_finished",self,"interaction_finish")
	vault.connect("object_interaction_finished",self,"interaction_finish")
	
	van.connect("bag_secured",self,"bag_secured")
	
	for safe in $Objectives/Safe_locations.get_children():
		safe.connect("object_interaction_finished",self,"interaction_finish")
	
	$Objectives/Vault/Drill.connect("drill_finished",self,"vault_finished")
	
	$ObjectiveZones/EnterZone.connect("objective_entered",self,"objective_enter")
	$ObjectiveZones/ManagerZone.connect("objective_entered",self,"objective_enter")
	$ObjectiveZones/VaultZone.connect("objective_entered",self,"objective_enter")
	
	randomize_note()
	randomize_safe()
	randomize_blue_keycard()
	
	randomize_cameras()
	set_difficulty()
	
func loud_ready():
	if (current_objective < 8):
		update_objective(8)
	else:
		Game.ui.update_subtitle("BAIN: Uh oh, looks like that's the alarm. Finish the heist quickly now!",1,6)
		
	$Objectives/Vault_panel.can_interact = false
	
	if ($ObjectiveZones/EnterZone != null):
		$ObjectiveZones/EnterZone.queue_free()
		
	if ($ObjectiveZones/ManagerZone != null):
		$ObjectiveZones/ManagerZone.queue_free()
		
	if ($ObjectiveZones/VaultZone != null):
		$ObjectiveZones/VaultZone.queue_free()
		
	get_tree().call_group("Camera","alarm_on")
	get_tree().call_group("npc","alarm_on")
	
func randomize_note():
	var num = randi() % $Objectives/Notes.get_child_count()
	var note = $Objectives/Notes.get_child(num)
	note.has_phone_number = true
	
func randomize_safe():
	var num = randi() % $Objectives/Safe_locations.get_child_count()
	var safe = $Objectives/Safe_locations.get_child(num)
	safe.visible = true
	safe.can_interact = true
	
func randomize_blue_keycard():
	var num = randi() % $Objectives/Keycards.get_child_count()
	var keycard = $Objectives/Keycards.get_child(num)
	keycard.visible = true
	keycard.can_interact = true
	keycard.connect("object_interaction_finished",self,"interaction_finish")

func randomize_cameras():
	for camera in $Objects/Cameras.get_children():
		camera.is_hidden = true
		camera.is_disabled = true
		camera.hide()
		
	var active_camera = 0
	while true:
		var camera = $Objects/Cameras.get_child(randi() % $Objects/Cameras.get_child_count())
		
		if (camera.is_disabled):
			camera.activate_camera()

			active_camera += 1
			
		if (active_camera == camera_amount):
			break
	
func set_difficulty():
	if (Game.difficulty == 0):
		for x in range(10,6,-1):
			var guard = get_node("NPCs/Guards/Guard" + str(x))
			get_tree().call_group("Detection","remove_exception",guard.get_node("Interaction_hitbox"))
			guard.queue_free()
	elif (Game.difficulty == 1):
		for x in range(10,8,-1):
			var guard = get_node("NPCs/Guards/Guard" + str(x))
			get_tree().call_group("Detection","remove_exception",guard.get_node("Interaction_hitbox"))
			guard.queue_free() 
			
func set_assets():
	for asset in $Assets.get_children():
		if (asset.name in Game.map_assets):
			asset.show()
			
	if (Game.map_assets.has("van")):
		$Objectives/Van.global_position = Vector2(11088,6288)
	else:
		$Objectives/Van.global_position = Vector2(1536,6064)
		
	
func update_objective(objective: int):
	current_objective = objective
	var cur_objective_dict: Dictionary = objectives[current_objective]
	
	Game.ui.update_objective(cur_objective_dict["objective_name"])
	
	if (cur_objective_dict.has("objective_subtitle")):
		Game.ui.update_subtitle(cur_objective_dict["objective_subtitle"],cur_objective_dict["subtitle_priority"],cur_objective_dict["subtitle_length"])
		
	if (current_objective == 3):
		if (has_found_office):
			update_objective(4)
			
	if (current_objective == 8):
		if (has_found_drill):
			update_objective(9)
			
	if (current_objective == 12):
		$Objectives/Van/SecureZoneVisible.visible = true		
		van.can_secure = true
		if (secured_bags > 0):
			update_objective(13)
		
	if (current_objective == 13):
		$Objectives/Van/SecureZoneVisible.visible = true
		van.can_escape = true
		
func bag_secured(type: String):
	if (type == "money"):
		secured_bags += 1
		Game.ui.update_popup("Bag secured: " + type,4)
		
		if (secured_bags > 0):
			update_objective(13)
	
func interaction_finish(object, action):
	if (object.name == "Drill_bag" && action == "carry"):
		if (current_objective < 8):
			has_found_drill = true
			Game.ui.update_subtitle("BAIN: That's the thermal drill my contact has stashed away. But for now, we have a better plan of opening the vault. Leave it.",1,10)
		elif (current_objective == 8):
			update_objective(9)
			
	elif (object.name == "KeyDoor" && current_objective < 6 && !Game.is_game_loud):
		update_objective(6)
	elif (object.name == "Phone" && current_objective < 5 && !Game.is_game_loud):
		manager.on_move()
		Game.ui.update_subtitle("BAIN: Haha, he took the bait! Okay, the office is now open for you. Go there.",2,7)
		update_objective(5)
	elif (object.name.find("Safe") != -1 && current_objective < 5 && !Game.is_game_loud):
		Game.ui.update_subtitle("BAIN: This safe should have the keys we need. Good find.",2,5)
	elif (object.name.find("Keys") != -1 && current_objective < 5 && !Game.is_game_loud):
		Game.ui.update_subtitle("BAIN: Perfect! That's exactly what we need! Go open the manager's office.",2,7)
		update_objective(5)
	elif (object.name.find("Note") != -1 && current_objective < 5 && !Game.is_game_loud):
		if (object.has_phone_number):
			Game.ui.update_subtitle("BAIN: Hey, you found the manager's phone number! Find a telephone and call him. We'll make him leave his office.",2,12)
		else:
			if (!has_shown_note_dialouge):
				has_shown_note_dialouge = true
				Game.ui.update_subtitle("BAIN: Keep searching these notes, they might have the manager's phone number.",2,7)
	elif (object.name.find("Keycard_blue") != -1 && !Game.is_game_loud):
		Game.ui.update_subtitle("BAIN: That's a keycard for the camera operator room in the back. Nice find.",2,10)
	elif (object.name == "Red_keycard" && current_objective < 7 && !Game.is_game_loud):
		if (Game.player_inventory.has("vault_code")):
			update_objective(7)
		else:
			Game.ui.update_subtitle("BAIN: Okay, that's the red keycard. Now we just need the code.",1,5)
	elif (object.name == "PC" && current_objective < 7 && !Game.is_game_loud):
		if (action == "code"):
			if (Game.player_inventory.has("r_keycard")):
				update_objective(7)
			else:
				Game.ui.update_subtitle("BAIN: Okay, that's the code. Now just find that red keycard.",1,5)
		elif (action == "hack" && current_objective < 7 && !Game.is_game_loud):
			Game.ui.update_subtitle("BAIN: Smart. This computer should have the vault code.",1,5)
	elif (object.name == "Vault_panel" && current_objective < 8 && !Game.is_game_loud):
		vault.can_interact = false
		vault.open_vault()
		update_objective(12)
	elif (object.name == "Vault" && current_objective < 9):
		vault_panel.can_interact = false
		update_objective(10)
		
func manager_killed(object):
	if (!Game.is_game_loud && current_objective < 7):
		if (Game.player_inventory.has("vault_code")):
			Game.ui.update_subtitle("BAIN: Uh... that was... unnecessary",1,7.5)
		else:
			Game.ui.update_subtitle("BAIN: Man are you crazy? He had the vault code! You gotta find another way to get it now. Great job.",1,10)
	
func manager_hostaged(object):
	Game.ui.update_subtitle("BAIN: Good. Ask him politely for the current vault code.",1,7.5)
	
func vault_finished():
	update_objective(12)
	
func interrogated(info):
	if (info == "none"):
		Game.ui.update_popup("This person had no info.",4)
	elif (info == "code"):
		Game.ui.update_popup("You got the vault code.",4)
		Game.add_player_inventory_item("vault_code")
		if (Game.player_inventory.has("r_keycard")):
			update_objective(7)
		else:
			Game.ui.update_subtitle("BAIN: Okay, that's the code. Now just find that keycard.",1,5)
			
func objective_enter(zone):
	if (zone.name == "EnterZone"):
		update_objective(2)
	elif (zone.name == "ManagerZone"):
		if (current_objective < 3):
			has_found_office = true
			Game.ui.update_subtitle("BAIN: Hey, that's the manager's office. Good find.",1,5)
		elif (current_objective == 3):
			update_objective(4)
	elif (zone.name == "VaultZone" && current_objective < 3):
		update_objective(3)

func _exit_tree():
	Game.map = false
