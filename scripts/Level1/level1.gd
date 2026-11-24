# Level 1: provides the feedback shown on the crash screen.
extends Node2D

func death_feedback() -> String:
	var signal_item := get_node("traffic_signal")
	if signal_item.global_position.x >= 933.0:     # still in the sidebar: nothing was placed
		return "Find a way to make the car stop to not hit the pedestrians."
	if not signal_item.ray_used:                   # the car never reached the signal's line
		return "The signal needs to be placed close to the road in order for the car to see it."
	return "The traffic signal needs to be close enough to the pedestrians that they can see the car. Try again!"
