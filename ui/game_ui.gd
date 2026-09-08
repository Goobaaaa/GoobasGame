class_name GameUI
extends CanvasLayer
var game: Node
var hud: Control
var modal: PanelContainer
var content: VBoxContainer
var money: Label
var prompt: Label
var status: Label
var hints: Label
var order_labels: Dictionary = {}
var modal_kind := ""
var address: LineEdit
var notify_time := 0.0

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("202d30")
	panel_style.border_color = Color("b79a61")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 26
	panel_style.content_margin_right = 26
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	theme.set_stylebox("panel","PanelContainer",panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("35464a")
	button_style.set_corner_radius_all(5)
	button_style.content_margin_top = 10
	button_style.content_margin_bottom = 10
	theme.set_stylebox("normal","Button",button_style)
	var hover := button_style.duplicate()
	hover.bg_color = Color("596653")
	theme.set_stylebox("hover","Button",hover)
	theme.set_color("font_color","Label",Color("eee5cf"))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	money = Label.new()
	hud.add_child(money)
	money.position = Vector2(28,22)
	money.add_theme_font_size_override("font_size",23)
	var cross := Label.new()
	cross.text = "+"
	hud.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(5,14)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt = Label.new()
	hud.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -550
	prompt.offset_right = 550
	prompt.offset_top = -120
	prompt.offset_bottom = -50
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints = Label.new()
	hud.add_child(hints)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.offset_left = 28
	hints.offset_top = -45
	hints.offset_bottom = -20
	hints.offset_right = 1200
	hints.text = "WASD Move   •   Mouse Look   •   Space Jump   •   E Interact   •   B Furnish   •   F5 Save   •   Esc Menu"
	hints.add_theme_font_size_override("font_size",16)
	status = Label.new()
	root.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -720
	status.offset_right = -25
	status.offset_top = 22
	status.offset_bottom = 70
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size",16)
	modal = PanelContainer.new()
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -340
	modal.offset_right = 340
	modal.offset_top = -285
	modal.offset_bottom = 285
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",9)
	modal.add_child(content)
	hud.hide()
	show_main()

func modal_open() -> bool:
	return modal.visible

func clear(title: String, subtitle: String = "") -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	order_labels.clear()
	modal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	text(title,30,Color("f3ce8b"))
	if subtitle != "": text(subtitle,16,Color("aebdb9"))

func text(value: String, size: int = 18, color: Color = Color("eee5cf")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	content.add_child(label)
	return label

func button(title: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.pressed.connect(action)
	content.add_child(b)
	return b

func close() -> void:
	modal.hide()
	modal_kind = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_main() -> void:
	modal_kind = "main"
	clear("LANTERN LANE","A fantasy shopkeeping prototype  /  Godot 4")
	text("A quiet street. An empty shop. Your first gold.",19)
	button("New Game",func(): new_game(false))
	var has_save := not SaveStore.read_save().is_empty()
	if has_save: button("Continue",func(): launch(false,false))
	button("Host Game • LAN",func(): launch(not has_save,true))
	address = LineEdit.new()
	address.placeholder_text = "Host LAN IP address"
	address.text = "127.0.0.1"
	content.add_child(address)
	button("Join Game",func():
		var err: Error = Session.join_game(address.text)
		if err != OK: notify("Join failed: " + error_string(err))
		else: show_connecting())
	text("Host and guests share one shop, purse and stock ledger.\nHost loads the local save, or starts fresh if none exists.",15)
	button("Quit",func(): game.get_tree().quit())

func show_connecting() -> void:
	modal_kind = "connecting"
	clear("Connecting…","Waiting for the LAN host (10 second timeout).")
	button("Cancel",func(): Session.leave())

func new_game(lan: bool) -> void:
	if FileAccess.file_exists(SaveStore.path):
		modal_kind = "confirm"
		clear("Start a new business?","This replaces the current local save. A backup is retained.")
		button("Create New Game",func(): launch(true,lan))
		button("Back",show_main)
	else: launch(true,lan)

func launch(fresh: bool, lan: bool) -> void:
	var err: Error = Session.start_host(fresh,lan)
	if err != OK: notify("Could not start: " + error_string(err))

func show_pause() -> void:
	modal_kind = "pause"
	clear("Take a breather","Your co-op world continues while this menu is open.")
	button("Resume",close)
	button("Save world",func(): Session.request_action("save"))
	button("Return to Main Menu",func(): Session.leave())
	text("LAN: UDP 24567 • Up to 8 merchants\nSave belongs to the host. Guests reconnect at the street.",16)

func show_purchase(shop_id: int) -> void:
	modal_kind = "purchase"
	clear(Catalog.SHOP_NAMES[shop_id],"Shop deed • 300 gold")
	text("Unlock a 6 × 6 metre shop and your own IMP supplier.\nThe whole co-op can furnish the shop and order stock.")
	button("Purchase • 300 gold",func(): Session.request_action("buy",{"shop":shop_id}); close())
	button("Cancel",close)

func show_furniture() -> void:
	modal_kind = "furniture"
	clear("Furnish your shop","Select an item, then aim at the grid. Gold is spent on placement.")
	for id in Catalog.FURNITURE:
		var d: Dictionary = Catalog.FURNITURE[id]
		button("%s  •  %d gold  •  %d × %d  /  %s" % [d.name,d.price,d.size[0],d.size[1],d.category],func(): game.placement.select(id); close())
	text("R Rotate 90°  •  Left click Place  •  Right click / Esc Cancel",16)
	button("Back",close)

func show_stock() -> void:
	modal_kind = "stock"
	clear("Pip's stock ledger","Orders are saved immediately. Physical delivery comes later.")
	for id in Catalog.PRODUCTS:
		var d: Dictionary = Catalog.PRODUCTS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		content.add_child(row)
		var icon := Label.new()
		icon.text = d.icon
		icon.custom_minimum_size.x = 35
		icon.add_theme_color_override("font_color",Color(d.color))
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s • %dg\n%s  /  ordered: %d" % [d.name,d.price,d.category,Session.state.ordered_stock.get(id,0)]
		label.add_theme_font_size_override("font_size",15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		order_labels[id] = label
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = 99
		quantity.value = 1
		quantity.custom_minimum_size.x = 85
		row.add_child(quantity)
		var buy := Button.new()
		buy.text = "Order"
		buy.custom_minimum_size.x = 78
		buy.pressed.connect(func(): Session.request_action("order",{"id":id,"quantity":int(quantity.value)}))
		row.add_child(buy)
	button("Close ledger",close)

func refresh() -> void:
	money.text = "LANTERN LANE   /   %d gold\n%s  •  %d merchant(s)" % [Session.state.money,"Shared co-op" if Session.online else "Solo business",Session.players.size()]
	for id in order_labels:
		var d: Dictionary = Catalog.PRODUCTS[id]
		order_labels[id].text = "%s • %dg\n%s  /  ordered: %d" % [d.name,d.price,d.category,Session.state.ordered_stock.get(id,0)]

func notify(value: String) -> void:
	status.text = value
	notify_time = 6.0

func _process(delta: float) -> void:
	notify_time -= delta
	if notify_time <= 0: status.text = ""
