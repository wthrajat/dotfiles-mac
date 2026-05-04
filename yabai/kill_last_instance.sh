#!/usr/bin/env bash

window_pid=$(yabai -m query --windows --window | jq -r '.pid') 
count_pid=$(yabai -m query --windows | jq "[.[] | select(.pid == ${window_pid})] | length")
if [ "$count_pid" -gt 1 ]; then
	yabai -m window --close
else
	kill "${window_pid}"
fi