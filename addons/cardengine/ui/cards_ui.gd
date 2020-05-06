tool
extends Control
class_name CardsUi

onready var _db_select = $CardLayout/ToolLayout/DatabaseSelect
onready var _save_btn = $CardLayout/ToolLayout/SaveBtn
onready var _load_btn = $CardLayout/ToolLayout/LoadBtn
onready var _success_lbl = $CardLayout/ToolLayout/SuccesLbl
onready var _error_lbl = $CardLayout/ToolLayout/ErrorLbl
onready var _card_id = $CardLayout/ToolLayout/CardId
onready var _categ_list = $CardLayout/DataLayout/CategList
onready var _value_list = $CardLayout/DataLayout/ValuesList
onready var _text_list = $CardLayout/DataLayout/TextsList
onready var _del_categ_btn = $CardLayout/DataLayout/CategToolLayout/DelCategBtn
onready var _del_value_btn = $CardLayout/DataLayout/ValuesToolLayout/DelValBtn
onready var _del_text_btn = $CardLayout/DataLayout/TextsToolLayout/DelTxtBtn

var _main_ui: CardEngineUI = null
var _edited_index: int = -1
var _edited_data: Dictionary = {}
var _selected_categ: int = -1
var _selected_val: int = -1
var _selected_text: int = -1

func _ready():
	CardEngine.db().connect("changed", self, "_on_Databases_changed")

func set_main_ui(ui: CardEngineUI) -> void:
	_main_ui = ui

func select_database(db: String):
	for i in range(_db_select.get_item_count()):
		var id = _db_select.get_item_metadata(i)
		if db == id:
			_db_select.select(i)
			return

func load_card(id: String, db_id: String):
	_categ_list.clear()
	_value_list.clear()
	_text_list.clear()
	
	var db = CardEngine.db().get_database(db_id)
	var card = db.get_card(id)
	if card == null:
		_error_lbl.text = "Unable to find the card in the database"
	else:
		_card_id.text = card.id
		for categ in card.categories():
			append_category(categ, card.get_category(categ))
		
		for value in card.values():
			append_value(value, card.get_value(value))
		
		for text in card.texts():
			append_text(text, card.get_text(text))

func save_card(id: String, db: CardDatabase):
	var card = CardData.new(id)
	for i in range(_categ_list.get_item_count()):
		var data = _categ_list.get_item_metadata(i)
		card.add_category(data["id"], data["name"])
	for i in range(_value_list.get_item_count()):
		var data = _value_list.get_item_metadata(i)
		card.add_value(data["id"], data["value"])
	for i in range(_text_list.get_item_count()):
		var data = _text_list.get_item_metadata(i)
		card.add_text(data["id"], data["text"])
	db.add_card(card)
	CardEngine.db().write_database(db)
	_success_lbl.text = "Card saved successfully"

func overwrite_card(id: String, db: CardDatabase):
	if yield():
		save_card(id, db)

func delete_card(id: String, db_id: String):
	if yield():
		var db = CardEngine.db().get_database(db_id)
		db.remove_card(id)
		CardEngine.db().write_database(db)
		$Dialogs/EditDatabaseDialog.remove_selected_card()

func append_category(id: String, name: String):
	_categ_list.add_item("%s: %s" % [id, name])
	_categ_list.set_item_metadata(_categ_list.get_item_count()-1, {"id": id, "name": name})

func replace_category(idx: int, id: String, name: String):
	_categ_list.set_item_text(idx, "%s: %s" % [id, name])
	_categ_list.set_item_metadata(idx, {"id": id, "name": name})

func delete_category(idx: int):
	if yield():
		_categ_list.remove_item(idx)
		_del_categ_btn.disabled = true

func append_value(id: String, value: int):
	_value_list.add_item("%s = %d" % [id, value])
	_value_list.set_item_metadata(_value_list.get_item_count()-1, {"id": id, "value": value})
	
func replace_value(idx: int, id: String, value: int):
	_value_list.set_item_text(idx, "%s = %d" % [id, value])
	_value_list.set_item_metadata(idx, {"id": id, "value": value})

func delete_value(idx: int):
	if yield():
		_value_list.remove_item(idx)
		_del_value_btn.disabled = true
		
func append_text(id: String, text: String):
	var lines = text.split("\n")
	if lines.size() > 1:
		_text_list.add_item("%s: %s (...)" % [id, lines[0]])
	else:
		_text_list.add_item("%s: %s" % [id, text])
	_text_list.set_item_metadata(_text_list.get_item_count()-1, {"id": id, "text": text})
	_text_list.set_item_tooltip(_text_list.get_item_count()-1, text)

func replace_text(idx: int, id: String, text: String):
	var lines = text.split("\n")
	if lines.size() > 1:
		_text_list.set_item_text(idx, "%s: %s (...)" % [id, lines[0]])
	else:
		_text_list.set_item_text(idx, "%s: %s" % [id, text])
	_text_list.set_item_metadata(idx, {"id": id, "text": text})
	_text_list.set_item_tooltip(idx, text)

func delete_text(idx: int):
	if yield():
		_text_list.remove_item(idx)
		_del_text_btn.disabled = true

func _on_Databases_changed():
	if _db_select == null: return
	
	_db_select.clear()
	var databases = CardEngine.db().databases()
	for id in databases:
		var db = databases[id]
		_db_select.add_item("%s: %s" % [db.id, db.name])
		_db_select.set_item_metadata(_db_select.get_item_count()-1, db.id)

func _on_CardId_text_changed(new_text):
	_success_lbl.text = ""
	if Utils.is_id_valid(new_text):
		_save_btn.disabled = false
		_load_btn.disabled = false
		_error_lbl.text = ""
	else:
		_save_btn.disabled = true
		_load_btn.disabled = true
		_error_lbl.text = "Invalid ID"

func _on_SaveBtn_pressed():
	_success_lbl.text = ""
	_error_lbl.text = ""
	
	var id = _card_id.text
	var db = CardEngine.db().get_database(_db_select.get_selected_metadata())
	
	if db.card_exists(id):
		_main_ui.show_confirmation_dialog("Overwrite Card", funcref(self, "overwrite_card"), [id, db])
	else:
		save_card(id, db)

func _on_LoadBtn_pressed():
	_success_lbl.text = ""
	_error_lbl.text = ""
	load_card(_card_id.text, _db_select.get_selected_metadata())

func _on_AddCategBtn_pressed():
	_main_ui.show_categ_dialog()

func _on_DelCategBtn_pressed():
	_main_ui.show_confirmation_dialog("Delete Category", funcref(self, "delete_category"), [_selected_categ])

func _on_CategList_item_selected(index):
	_del_categ_btn.disabled = false
	_selected_categ = index
	
func _on_CategList_item_activated(index):
	_edited_index = index
	_edited_data = _categ_list.get_item_metadata(index)
	_main_ui.show_categ_dialog(_edited_data)

func _on_CategoryDialog_form_validated(form):
	if form["edit"] && _edited_data["id"] == form["id"]:
		replace_category(_edited_index, form["id"], form["name"])
	else:
		append_category(form["id"], form["name"])

func _on_AddValBtn_pressed():
	_main_ui.show_value_dialog()

func _on_DelValBtn_pressed():
	_main_ui.show_confirmation_dialog("Delete Value", funcref(self, "delete_value"), [_selected_val])

func _on_ValuesList_item_selected(index):
	_del_value_btn.disabled = false
	_selected_val = index

func _on_ValuesList_item_activated(index):
	_edited_index = index
	_edited_data = _value_list.get_item_metadata(index)
	_main_ui.show_value_dialog(_edited_data)

func _on_ValueDialog_form_validated(form):
	if form["edit"] && _edited_data["id"] == form["id"]:
		replace_value(_edited_index, form["id"], form["value"])
	else:
		append_value(form["id"], form["value"])

func _on_AddTxtBtn_pressed():
	_main_ui.show_text_dialog()

func _on_DelTxtBtn_pressed():
	_main_ui.show_confirmation_dialog("Delete Text", funcref(self, "delete_text"), [_selected_text])

func _on_TextsList_item_selected(index):
	_del_text_btn.disabled = false
	_selected_text = index

func _on_TextsList_item_activated(index):
	_edited_index = index
	_edited_data = _text_list.get_item_metadata(index)
	_main_ui.show_text_dialog(_edited_data)

func _on_TextDialog_form_validated(form):
	if form["edit"] && _edited_data["id"] == form["id"]:
		replace_text(_edited_index, form["id"], form["text"])
	else:
		append_text(form["id"], form["text"])

func _on_EditDatabaseDialog_edit_card(card, db):
	_main_ui.change_tab(1)
	load_card(card, db)
	select_database(db)
	_save_btn.disabled = false

func _on_EditDatabaseDialog_delete_card(card, db):
	_main_ui.show_confirmation_dialog("Delete Card", funcref(self, "delete_card"), [card, db])
