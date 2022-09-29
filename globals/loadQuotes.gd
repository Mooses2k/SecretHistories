extends Node

onready var file1 = 'res://resources/list1.txt' #text files on 'resources' folder
onready var file2 = 'res://resources/list2.txt'


var list1 : PoolStringArray
var list2 : PoolStringArray
var temp


func load_files():
	var f = File.new()
	f.open(file1, File.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		list1.append(f.get_line())
	f.close()
	
	f.open(file2, File.READ)
	while not f.eof_reached(): # iterate through all lines until the end of file is reached
		list2.append(f.get_line())
	f.close()
	return
