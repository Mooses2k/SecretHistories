extends Node

# Test script to verify scroll functionality in settings UI
# This can be attached to a test scene or used for debugging

func test_scroll_functionality(settings_ui):
	print("=== Testing Scroll Functionality ===")
	
	# Get the content area
	var content_area = settings_ui.get_node("MarginContainer/VBoxContainer/ContentArea")
	if not content_area:
		print("ERROR: ContentArea not found")
		return
	
	# Check all scroll containers
	var scroll_containers = []
	for child in content_area.get_children():
		if child is ScrollContainer:
			scroll_containers.append(child)
	
	print("Found %d scroll containers" % scroll_containers.size())
	
	for scroll_container in scroll_containers:
		print("ScrollContainer: %s" % scroll_container.name)
		print("  Visible: %s" % scroll_container.visible)
		print("  Vertical scroll mode: %s" % scroll_container.get_vertical_scroll_mode())
		print("  Horizontal scroll mode: %s" % scroll_container.get_horizontal_scroll_mode())
		print("  Has vertical scrollbar: %s" % (scroll_container.get_v_scroll_bar() != null))
		print("  Has horizontal scrollbar: %s" % (scroll_container.get_h_scroll_bar() != null))
		
		# Check if it has content
		if scroll_container.get_child_count() > 0:
			var content = scroll_container.get_child(0)
			if content is VBoxContainer:
				print("  Content children: %d" % content.get_child_count())
				print("  Content minimum size: %s" % content.get_minimum_size())
	
	print("=== Scroll functionality test complete ===")