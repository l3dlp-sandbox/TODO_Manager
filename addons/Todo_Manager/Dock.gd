tool
extends Control

#signal tree_built # used for debugging

const Project := preload("res://addons/Todo_Manager/Project.gd")
const Current := preload("res://addons/Todo_Manager/Current.gd")
const Uid := preload("res://addons/Todo_Manager/Uid.gd")

const Todo := preload("res://addons/Todo_Manager/Todo.gd")
const TodoScript := preload("res://addons/Todo_Manager/TodoScript.gd")
const ColourPicker := preload("res://addons/Todo_Manager/UI/ColourPicker.tscn")
const Pattern := preload("res://addons/Todo_Manager/UI/Pattern.tscn")
const DEFAULT_PATTERNS := [["\\bTODO\\b", Color("96f1ad")], ["\\bHACK\\b", Color("d5bc70")], ["\\bFIXME\\b", Color("d57070")]]
const DEFAULT_SCRIPT_COLOUR := Color("ccced3")
const DEFAULT_SCRIPT_NAME := false
const DEFAULT_SORT := true

var plugin : EditorPlugin

var todo_scripts : Array

var script_colour := Color("ccced3")
var ignore_paths := []
var full_path := false
var sort_alphabetical := true
var auto_refresh := true

var patterns := [["\\bTODO\\b", Color("96f1ad")], ["\\bHACK\\b", Color("d5bc70")], ["\\bFIXME\\b", Color("d57070")]]

onready var tabs := $VBoxContainer/TabContainer as TabContainer
onready var project := $VBoxContainer/TabContainer/Project as Project
onready var current := $VBoxContainer/TabContainer/Current as Current
onready var project_tree := $VBoxContainer/TabContainer/Project/Tree as Tree
onready var current_tree := $VBoxContainer/TabContainer/Current/Tree as Tree
onready var settings_panel := $VBoxContainer/TabContainer/Settings as Panel
onready var colours_container := $VBoxContainer/TabContainer/Settings/ScrollContainer/MarginContainer/VBoxContainer/HBoxContainer3/Colours as VBoxContainer
onready var pattern_container := $VBoxContainer/TabContainer/Settings/ScrollContainer/MarginContainer/VBoxContainer/HBoxContainer4/Patterns as VBoxContainer
onready var ignore_textbox := $VBoxContainer/TabContainer/Settings/ScrollContainer/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2/Scripts/IgnorePaths/TextEdit as LineEdit
onready var progress_bar := $ProgressBar as ProgressBar

func _ready() -> void:
	load_config()
	populate_settings()


func build_tree() -> void:
	match tabs.current_tab:
		0:
			project.build_tree(todo_scripts, ignore_paths, patterns, sort_alphabetical, full_path)
		1:
			current.build_tree(get_active_script(), patterns)
		2:
			pass
		_:
			pass


func get_active_script() -> TodoScript:
	var current_script : Script = plugin.get_editor_interface().get_script_editor().get_current_script()
	var script_path = current_script.resource_path
	for todo_script in todo_scripts:
		if todo_script.script_path == script_path:
			return todo_script
	
	# nothing found
	var todo_script := TodoScript.new()
	todo_script.script_path = script_path
	return todo_script


func go_to_script(script_path: String, line_number : int = 0) -> void:
	var script := load(script_path)
	plugin.get_editor_interface().edit_resource(script)
	plugin.get_editor_interface().get_script_editor().goto_line(line_number - 1)


func sort_alphabetical(a, b) -> bool:
	if a.script_path > b.script_path:
		return true
	else:
		return false

func sort_backwards(a, b) -> bool:
	if a.script_path < b.script_path:
		return true
	else:
		return false


func populate_settings() -> void:
	for i in patterns.size():
		## Create Colour Pickers
		var colour_picker := ColourPicker.instance()
		colour_picker.colour = patterns[i][1]
		colour_picker.title = patterns[i][0]
		colour_picker.index = i
		colours_container.add_child(colour_picker)
		colour_picker.colour_picker.connect("color_changed", self, "change_colour", [i])
		
		## Create Patterns
		var pattern_edit := Pattern.instance()
		pattern_edit.text = patterns[i][0]
		pattern_edit.index = i
		pattern_container.add_child(pattern_edit)
		pattern_edit.line_edit.connect("text_changed", self, "change_pattern", [i, colour_picker])
		pattern_edit.remove_button.connect("pressed", self, "remove_pattern", [i, pattern_edit, colour_picker])
	$VBoxContainer/TabContainer/Settings/ScrollContainer/MarginContainer/VBoxContainer/HBoxContainer4/Patterns/AddPatternButton.raise()
	
	# path filtering
	var ignore_paths_field := ignore_textbox
	if !ignore_paths_field.is_connected("text_changed", self, "_on_ignore_paths_changed"):
		ignore_paths_field.connect("text_changed", self, "_on_ignore_paths_changed")
	var ignore_paths_text := ""
	for path in ignore_paths:
		ignore_paths_text += path + ", "
	ignore_paths_text.rstrip(' ').rstrip(',')
	ignore_paths_field.text = ignore_paths_text


func rebuild_settings() -> void:
	for node in colours_container.get_children():
		node.queue_free()
	for node in pattern_container.get_children():
		if node is Button:
			continue
		node.queue_free()
	populate_settings()


#### CONFIG FILE ####
func create_config_file() -> void:
	var config = ConfigFile.new()
	config.set_value("scripts", "full_path", full_path)
	config.set_value("scripts", "sort_alphabetical", sort_alphabetical)
	config.set_value("scripts", "script_colour", script_colour)
	config.set_value("scripts", "ignore_paths", ignore_paths)
	
	config.set_value("patterns", "patterns", patterns)
	
	config.set_value("config", "auto_refresh", auto_refresh)
	
	var err = config.save("res://addons/Todo_Manager/todo.cfg")


func load_config() -> void:
	var config := ConfigFile.new()
	if config.load("res://addons/Todo_Manager/todo.cfg") == OK:
		full_path = config.get_value("scripts", "full_path", DEFAULT_SCRIPT_NAME)
		sort_alphabetical = config.get_value("scripts", "sort_alphabetical", DEFAULT_SORT)
		script_colour = config.get_value("scripts", "script_colour", DEFAULT_SCRIPT_COLOUR)
		ignore_paths = config.get_value("scripts", "ignore_paths", [])
		patterns = config.get_value("patterns", "patterns", DEFAULT_PATTERNS)
		auto_refresh = config.get_value("config", "auto_refresh", true)
	else:
		create_config_file()


#### Events ####
func _on_SettingsButton_toggled(button_pressed: bool) -> void:
	settings_panel.visible = button_pressed
	if button_pressed == false:
		create_config_file()
#		plugin.find_tokens_from_path(plugin.script_cache)
		if auto_refresh:
			plugin.rescan_files()

func _on_Tree_item_activated() -> void:
	var item : TreeItem
	match tabs.current_tab:
		0:
			item = project_tree.get_selected()
		1: 
			item = current_tree.get_selected()
	if item.get_metadata(0) is Todo:
		var todo : Todo = item.get_metadata(0)
		call_deferred("go_to_script", todo.script_path, todo.line_number)
	else:
		var todo_script = item.get_metadata(0)
		call_deferred("go_to_script", todo_script.script_path)

func _on_FullPathCheckBox_toggled(button_pressed: bool) -> void:
	full_path = button_pressed

func _on_ScriptColourPickerButton_color_changed(color: Color) -> void:
	script_colour = color

func _on_TODOColourPickerButton_color_changed(color: Color) -> void:
	patterns[0][1] = color

func _on_RescanButton_pressed() -> void:
	plugin.rescan_files()

func change_colour(colour: Color, index: int) -> void:
	patterns[index][1] = colour

func change_pattern(value: String, index: int, this_colour: Node) -> void:
	patterns[index][0] = value
	this_colour.title = value

func remove_pattern(index: int, this: Node, this_colour: Node) -> void:
	patterns.remove(index)
	this.queue_free()
	this_colour.queue_free()

func _on_DefaultButton_pressed() -> void:
	patterns = DEFAULT_PATTERNS.duplicate(true)
	sort_alphabetical = DEFAULT_SORT
	script_colour = DEFAULT_SCRIPT_COLOUR
	full_path = DEFAULT_SCRIPT_NAME
	rebuild_settings()

func _on_AlphSortCheckBox_toggled(button_pressed: bool) -> void:
	sort_alphabetical = button_pressed

func _on_AddPatternButton_pressed() -> void:
	patterns.append(["\\bplaceholder\\b", Color.white])
	rebuild_settings()

func _on_RefreshCheckButton_toggled(button_pressed: bool) -> void:
	auto_refresh = button_pressed

func _on_Timer_timeout() -> void:
	plugin.refresh_lock = false

func _on_ignore_paths_changed(new_text: String) -> void:
	var text = ignore_textbox.text
	var split: Array = text.split(',')
	ignore_paths.clear()
	for elem in split:
		if elem == " " || elem == "": 
			continue
		ignore_paths.push_front(elem.lstrip(' ').rstrip(' '))
	# validate so no empty string slips through (all paths ignored)
	var i := 0
	for path in ignore_paths:
		if (path == "" || path == " "):
			ignore_paths.remove(i)
		i += 1

func _on_TabContainer_tab_changed(tab: int) -> void:
	build_tree()



func _on_Button_pressed() -> void:
	pass
