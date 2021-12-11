extends Node

# Items tracked exclusively by ammount, don't contribute to weight, 
# don't show in hotbar
var special : Dictionary

# Usable items that appear in the hotbar
var hotbar : Array

# Armor currently equipped by the character
var current_armor : Resource
