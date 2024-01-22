extends NavigationMeshInstance
class_name AutoCleanNavigationMeshInstance

var last_state = true
var last_layers = navigation_layers

func _exit_tree():
	last_layers = NavigationServer.region_get_navigation_layers(get_region_rid())
	NavigationServer.region_set_navigation_layers(get_region_rid(), 0)

func _enter_tree():
	NavigationServer.region_set_navigation_layers(get_region_rid(), last_layers)
