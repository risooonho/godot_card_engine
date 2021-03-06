tool
extends WindowDialog

signal edit_card(card, db)
signal delete_card(card, db)

var _db: CardDatabase = null
var _store: CardDeck = CardDeck.new()
var _query: Query = Query.new()
var _selected_card_idx: int = -1
var _selected_card: String = ""
var _selected_categ: String = "all"
var _selected_val: String = "none"
var _selected_txt: String = "none"

onready var _manager = CardEngine.db()
onready var _card_list = $MainLayout/CardsLayout/CardList
onready var _detail_list = $MainLayout/CardsLayout/DetailsLayout/DetailsList
onready var _delete_btn = $MainLayout/CardsLayout/DetailsLayout/ToolsLayout/DeleteBtn
onready var _edit_btn = $MainLayout/CardsLayout/DetailsLayout/ToolsLayout/EditBtn
onready var _categ_filter = $MainLayout/FiltersLayout/CategFilter
onready var _val_filter = $MainLayout/FiltersLayout/ValFilter
onready var _txt_filter = $MainLayout/FiltersLayout/TxtFilter
onready var _comp_op = $MainLayout/FiltersLayout/CompLayout/CompOp
onready var _comp_val = $MainLayout/FiltersLayout/CompLayout/CompVal
onready var _contains = $MainLayout/FiltersLayout/ContainsFilter
onready var _list_lbl = $MainLayout/CardsLayout/ListLbl


func _ready():
	_manager.connect("changed", self, "_on_db_changed")


func set_database(id: String):
	_db = _manager.get_database(id)
	_query.clear()
	_categ_filter.clear()
	_val_filter.clear()
	_txt_filter.clear()
	_selected_categ = "all"
	_selected_val = "none"
	_selected_txt = "none"
	_comp_op.select(0)
	_comp_val.value = 0
	
	_clear_lists()
	_fill_card_list()


func remove_selected_card():
	_card_list.remove_item(_selected_card_idx)
	_detail_list.clear()
	_delete_btn.disabled = true
	_edit_btn.disabled = true


func _clear_lists():
	if _card_list != null:
		_card_list.clear()
	if _detail_list != null:
		_detail_list.clear()


func _fill_card_list():
	if _db == null:
		return
	
	_store.clear()
	_db.exec_query(_query, _store)
	
	if _store.count() > 0:
		_update_filters()
		_store.sort_by_id()
	
	var cards = _store.cards()
	_list_lbl.text = "Card List (%d cards)" % cards.size()
	for card in cards:
		_card_list.add_item(card.id)


func _apply_filters():
	var from: Array = []
	var where: Array = []
	var contains: Array = []
	
	if _categ_filter.selected > 0:
		from.append(_categ_filter.get_selected_metadata())
	
	if _val_filter.selected > 0:
		where.append(
			"%s %s %d" % [
				_val_filter.get_item_text(_val_filter.selected),
				_comp_op.get_item_text(_comp_op.selected),
				_comp_val.value])
	
	if _txt_filter.selected > 0 and not _contains.text.empty():
		contains.append("%s:%s" % [
			_txt_filter.get_item_text(_txt_filter.selected),
			_contains.text])
	
	_query.clear().from(from).where(where).contains(contains)
	
	_clear_lists()
	_fill_card_list()


func _update_filters():
	_update_categs()
	_update_values()
	_update_texts()


func _update_categs():
	_categ_filter.clear()
	_categ_filter.add_item("All")
	for id in _store.categories():
		var categ = _store.get_category(id)
		_categ_filter.add_item("%s (%d)" % [categ["name"], categ["count"]])
		_categ_filter.set_item_metadata(_categ_filter.get_item_count() - 1, id)
		if id == _selected_categ:
			_categ_filter.select(_categ_filter.get_item_count() - 1)


func _update_values():
	_val_filter.clear()
	_val_filter.add_item("None")
	for id in _store.values():
		_val_filter.add_item(id)
		if id == _selected_val:
			_val_filter.select(_val_filter.get_item_count() - 1)


func _update_texts():
	_txt_filter.clear()
	_txt_filter.add_item("None")
	for id in _store.texts():
		_txt_filter.add_item(id)
		if id == _selected_txt:
			_txt_filter.select(_txt_filter.get_item_count() - 1)


func _on_DoneBtn_pressed():
	hide()


func _on_EditDatabaseDialog_about_to_show():
	_delete_btn.disabled = true
	_edit_btn.disabled = true
	_clear_lists()


func _on_CardList_item_selected(index):
	_detail_list.clear()
	
	_selected_card_idx = index
	_selected_card = _card_list.get_item_text(index)
	
	var card = _db.get_card(_selected_card)
	_detail_list.add_item("Categories:")
	for categ in card.categories():
		_detail_list.add_item("  * %s: %s" % [categ, card.get_category(categ)])
		
	_detail_list.add_item("Values:")
	for value in card.values():
		_detail_list.add_item("  * %s = %d" % [value, card.get_value(value)])
		
	_detail_list.add_item("Texts:")
	for text in card.texts():
		_detail_list.add_item("  * %s:" % text)
		var lines = card.get_text(text).split("\n")
		for line in lines:
			_detail_list.add_item("       %s" % line)
	
	_delete_btn.disabled = false
	_edit_btn.disabled = false


func _on_EditBtn_pressed():
	emit_signal("edit_card", _selected_card, _db.id)
	hide()


func _on_DeleteBtn_pressed():
	emit_signal("delete_card", _selected_card, _db.id)


func _on_db_changed():
	_clear_lists()
	_fill_card_list()


func _on_CategFilter_item_selected(id):
	if id == 0:
		_selected_categ = "all"
	else:
		_selected_categ = _categ_filter.get_item_metadata(id)
		
	_apply_filters()


func _on_ValFilter_item_selected(id):
	if id == 0:
		_selected_val = "none"
	else:
		_selected_val = _val_filter.get_item_text(id)
		
	_apply_filters()


func _on_TxtFilter_item_selected(id):
	if id == 0:
		_selected_txt = "none"
	else:
		_selected_txt = _txt_filter.get_item_text(id)
	
	_apply_filters()


func _on_CompOp_item_selected(_id):
	_apply_filters()


func _on_CompVal_value_changed(_value):
	_apply_filters()


func _on_ContainsFilter_text_changed(_new_text):
	_apply_filters()
