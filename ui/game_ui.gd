class_name GameUI
extends CanvasLayer
const StockPanel = preload("res://ui/stock_order_panel.gd")
const ShopName = preload("res://shops/shop_naming.gd")
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
var notify_time := 0.0
var inventory_panel: InventoryPanel
var sale_panel: SalePlatformPanel
var stock_panel
var shop_name_input: LineEdit
var shop_name_feedback: Label

func show_sale_platform(platform_id: String) -> void:
	modal_kind = "sale_platform"
	clear("Stock your sale display","Buy reference = current catalog cost (item value if unavailable). Profit is an estimate, not a completed sale.")
	modal.offset_left = -560
	modal.offset_right = 560
	modal.offset_top = -310
	modal.offset_bottom = 310
	sale_panel = SalePlatformPanel.new()
	sale_panel.platform_id = platform_id
	content.add_child(sale_panel)
	button("Close display",close)

func _ready() -> void:
	# Item tooltips should feel immediate in an item-heavy interface.
	# The board/card callbacks still validate their records before rendering.
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",0.05)
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
	inventory_panel = InventoryPanel.new()
	inventory_panel.game_ui = self
	root.add_child(inventory_panel)
	hints.text += "   •   I Inventory"
	hud.hide()
	show_main()

func modal_open() -> bool:
	return modal.visible or (is_instance_valid(inventory_panel) and inventory_panel.visible)

func show_inventory(with_loot: bool = false, source: String = "supplies") -> void:
	modal.hide()
	modal_kind = "inventory"
	inventory_panel.show_loot = with_loot
	inventory_panel.loot_source = source
	inventory_panel.refresh()
	inventory_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func clear(title: String, subtitle: String = "") -> void:
	sale_panel = null
	stock_panel = null
	shop_name_input = null
	shop_name_feedback = null
	modal.offset_left = -340
	modal.offset_right = 340
	modal.offset_top = -285
	modal.offset_bottom = 285
	if is_instance_valid(inventory_panel):
		inventory_panel.board.cancel_drag()
		inventory_panel.hide()
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
	if is_instance_valid(inventory_panel):
		inventory_panel.board.cancel_drag()
		inventory_panel.hide()
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
	text("Single-player adventure • Your progress saves locally.",15)
	button("Quit",func(): game.get_tree().quit())

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
	clear("Take a breather","Your single-player adventure")
	button("Resume",close)
	button("Save world",func(): Session.request_action("save"))
	button("Return to Main Menu",func(): Session.leave())
	text("Your progress is saved on this computer.",16)

func show_purchase(shop_id: int) -> void:
	modal_kind = "purchase"
	clear(Catalog.SHOP_NAMES[shop_id],"Shop deed • 300 gold")
	text("Unlock a 6 × 6 metre shop and your own IMP supplier.\nFurnish your shop and order stock.")
	button("Purchase • 300 gold",func():
		var before := int(Session.state.purchased_shop)
		Session.request_action("buy",{"shop":shop_id})
		if int(Session.state.purchased_shop) == shop_id and before != shop_id:
			close()
			show_shop_naming()
	)
	button("Cancel",close)

func show_shop_naming() -> void:
	modal_kind = "shop_naming"
	clear("NAME YOUR SHOP","Your adventure starts here.\nWhat would you like to call your shop?")
	text("Choose a memorable name for your new business.",16,Color("c6d0cc"))
	shop_name_input = LineEdit.new()
	shop_name_input.placeholder_text = "The Silver Griffin"
	shop_name_input.max_length = ShopName.MAX_LENGTH
	shop_name_input.custom_minimum_size.y = 44
	shop_name_input.text_changed.connect(_shop_name_changed)
	content.add_child(shop_name_input)
	text("3–30 characters",14,Color("aebdb9"))
	shop_name_feedback = text(" ",14,Color("f08a83"))
	var confirm := button("Confirm",_confirm_shop_name)
	confirm.name = "ConfirmShopName"
	shop_name_input.grab_focus()
	_shop_name_changed(shop_name_input.text)
	button("Cancel",func(): close())

func _shop_name_changed(value: String) -> void:
	if not is_instance_valid(shop_name_feedback): return
	var error := ShopName.validate(value)
	shop_name_feedback.text = " " if error.is_empty() else error
	shop_name_feedback.add_theme_color_override("font_color",Color("9fe3ae") if error.is_empty() else Color("f08a83"))
	for child in content.get_children():
		if child is Button and child.name == "ConfirmShopName": child.disabled = not error.is_empty()

func _confirm_shop_name() -> void:
	if not is_instance_valid(shop_name_input): return
	var name := ShopName.normalize(shop_name_input.text)
	var error := ShopName.validate(name)
	if not error.is_empty():
		_shop_name_changed(name)
		return
	var previous := str(Session.state.get("shop_name",""))
	Session.request_action("set_shop_name",{"name":name})
	if str(Session.state.get("shop_name","")) != previous: close()

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
	clear("Pip's stock ledger","BUY adds to your backpack · PLACE DELIVERY ORDER arrives in 5 minutes")
	modal.offset_left = -520
	modal.offset_right = 520
	modal.offset_top = -330
	modal.offset_bottom = 330
	stock_panel = StockPanel.new()
	content.add_child(stock_panel)
	order_labels = stock_panel.labels
	button("Close ledger",close)

func refresh() -> void:
	if is_instance_valid(sale_panel) and modal.visible and modal_kind == "sale_platform": sale_panel.refresh()
	if is_instance_valid(inventory_panel) and inventory_panel.visible: inventory_panel.refresh()
	if is_instance_valid(stock_panel) and modal.visible and modal_kind == "stock": stock_panel.refresh()
	money.text = "LANTERN LANE   /   %d gold\nSingle-player" % Session.state.money

func notify(value: String) -> void:
	status.text = value
	notify_time = 6.0

func _process(delta: float) -> void:
	notify_time -= delta
	if notify_time <= 0: status.text = ""
