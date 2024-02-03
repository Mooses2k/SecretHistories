@tool
extends Container
class_name MaxAspectContainer

enum MaxAspectContainerMode {
	LIMIT_WIDTH,
	LIMIT_HEIGHT,
}

## Maximum aspect ratio, as width/height
@export_range(0.01, 100, 0.001, "or_greater") var max_aspect_ratio : float = 1:
	set(value):
		max_aspect_ratio = value
		queue_sort()
@export var mode : MaxAspectContainerMode = MaxAspectContainerMode.LIMIT_WIDTH:
	set(value):
		mode = value
		queue_sort()

func _notification(what):
	match what:
		NOTIFICATION_SORT_CHILDREN:
			var child_size : Vector2 = size
			match mode:
				MaxAspectContainerMode.LIMIT_HEIGHT:
					child_size.y = min(child_size.y, child_size.x/max_aspect_ratio)
				MaxAspectContainerMode.LIMIT_WIDTH:
					child_size.x = min(child_size.x, child_size.y*max_aspect_ratio)
			for c in get_children():
				if c is Control:
					var min_size = c.get_combined_minimum_size()
					var actual_size = Vector2(max(child_size.x, min_size.x), max(child_size.y, min_size.y))
					var child_rect : Rect2 = Rect2((size - actual_size)/2, actual_size)
					fit_child_in_rect(c, child_rect)
