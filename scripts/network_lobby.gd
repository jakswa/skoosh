extends CanvasLayer
class_name SkooshNetworkLobby

signal server_requested(port: int)
signal join_requested(address: String, port: int)

@onready var panel := $Panel as PanelContainer
@onready var address_input := $Panel/Layout/AddressRow/Address as LineEdit
@onready var port_input := $Panel/Layout/AddressRow/Port as SpinBox
@onready var status_label := $Panel/Layout/Status as Label
@onready var host_button := $Panel/Layout/Buttons/Host as Button
@onready var join_button := $Panel/Layout/Buttons/Join as Button


func _ready() -> void:
	host_button.pressed.connect(func(): server_requested.emit(roundi(port_input.value)))
	join_button.pressed.connect(func(): join_requested.emit(address_input.text.strip_edges(), roundi(port_input.value)))
	address_input.text_submitted.connect(func(_text: String): _request_join())
	address_input.grab_focus()


func _request_join() -> void:
	join_requested.emit(address_input.text.strip_edges(), roundi(port_input.value))


func set_status(message: String, connected: bool = false) -> void:
	status_label.text = message
	if connected:
		visible = false


func show_error(message: String) -> void:
	status_label.text = message
	visible = true
	panel.visible = true


func hide_lobby() -> void:
	visible = false


func show_lobby() -> void:
	visible = true
	panel.visible = true
