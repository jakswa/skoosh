extends Node
class_name SkooshNetworkMatchState

var red_score := 0
var blue_score := 0
var score_limit := 3
var red_flag_state := 0
var red_flag_carrier := 0
var red_flag_position := Vector3.ZERO
var red_flag_return_tick := -1
var blue_flag_state := 0
var blue_flag_carrier := 0
var blue_flag_position := Vector3.ZERO
var blue_flag_return_tick := -1
var round_over := false
var winner_team := -1
var round_restart_tick := -1
var round_number := 1
var objective_reset_tick := -1
var match_state_generation := 1
