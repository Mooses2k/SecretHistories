#Copyright (c) 2014-present Godot Engine contributors.
#Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# from https://github.com/godotengine/godot-demo-projects/blob/master/3d/graphics_settings/settings.gd
# structure by crazyStewie, additions and cleanup by Mooses2k

extends Node


signal fullscreen_changed(new_value)
signal brightness_changed(new_value)
signal gui_scale_changed(new_value)
signal vsync_changed(new_value)
signal fps_limit_changed(new_value)
signal msaa_changed(new_value)
signal taa_changed(new_value)
signal fxaa_changed(new_value)
signal shadow_size_changed(new_value)
signal shadow_filter_changed(new_value)
signal mesh_lod_changed(new_value)
signal ssr_changed(new_value)
signal ssao_changed(new_value)
signal ssil_changed(new_value)
signal sdgfi_changed(new_value)
signal glow_changed(new_value)
#signal volumetric_fog_changed(new_value)

const GROUP_NAME : String = "Video Settings"

const SETTING_FULLSCREEN : String = "Fullscreen"

const SETTING_BRIGHTNESS : String = "Brightness"
const BRIGHTNESS_MIN = 0.1
const BRIGHTNESS_MAX = 5.0
const BRIGHTNESS_STEP = 0.1
const BRIGHTNESS_DEFAULT = 1.0

const SETTING_GUI_SCALE : String = "GUI Scale"
const GUI_SCALE_MIN = 0.5
const GUI_SCALE_MAX = 2.0
const GUI_SCALE_STEP = 0.25
const GUI_SCALE_DEFAULT = 1.0

const SETTING_VSYNC : String = "V-Sync"
var vsync_array = PackedStringArray(["Disabled", "Adaptive", "Enabled"])

const SETTING_FPS_LIMIT : String = "FPS limit"
var fps_limit_array = PackedStringArray(["No limit", "60", "75", "90", "120", "144", "240"])

const SETTING_MSAA : String = "MSAA"
var msaa_array = PackedStringArray(["Disabled", "2x MSAA", "4x MSAA", "8x MSAA"])

const SETTING_TAA : String = "TAA"

const SETTING_FXAA : String = "FXAA"

const SETTING_SHADOW_SIZE : String = "Shadow map size"
var shadow_size_array = PackedStringArray(["Minimum", "Very Low", "Low", "Medium", "High", "Very High"])

const SETTING_SHADOW_FILTER : String = "Shadow filter quality"
var shadow_filter_array = PackedStringArray(["Minimum", "Very Low", "Low", "Medium", "High", "Very High"])

const SETTING_MESH_LOD : String = "Mesh LOD"
var mesh_lod_array = PackedStringArray(["Very Low", "Low", "Medium", "High", "Very High"])

const SETTING_SSR : String = "Screen space reflections"
var ssr_array = PackedStringArray(["Disabled", "Low", "Medium", "High"])

const SETTING_SSAO : String = "Screen space ambient occlusion"
var ssao_array = PackedStringArray(["Disabled", "Very Low", "Low", "Medium", "High"])

const SETTING_SSIL : String = "Screen space indirect lighting"
var ssil_array = PackedStringArray(["Disabled", "Very Low", "Low", "Medium", "High"])

const SETTING_SDFGI : String = "SDF global illumination"
var sdfgi_array = PackedStringArray(["Disabled", "Low", "High"])

const SETTING_GLOW : String = "Glow"

var fullscreen_enabled : bool: get = get_fullscreen_enabled, set = set_fullscreen_enabled
var brightness : bool: get = get_brightness, set = set_brightness
var gui_scale : float: get = get_gui_scale, set = set_gui_scale
var vsync : int: get = get_vsync, set = set_vsync
var fps_limit : int: get = get_fps_limit, set = set_fps_limit
var msaa : int: get = get_msaa, set = set_msaa
var taa : bool: get = get_taa, set = set_taa
var fxaa : bool: get = get_fxaa, set = set_fxaa
var shadow_size : int: get = get_shadow_size, set = set_shadow_size
var shadow_filter : int: get = get_shadow_filter, set = set_shadow_filter
var mesh_lod : int: get = get_mesh_lod, set = set_mesh_lod
var ssr : int: get = get_ssr, set = set_ssr
var ssao : int: get = get_ssao, set = set_ssao
var ssil : int: get = get_ssil, set = set_ssil
var sdfgi : int: get = get_sdfgi, set = set_sdfgi
var glow : bool: get = get_glow, set = set_glow
#var volumetric_fog


func _ready():
	Settings.add_bool_setting(SETTING_FULLSCREEN, ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN)))
	Settings.set_setting_group(SETTING_FULLSCREEN, GROUP_NAME)
	
	Settings.add_float_setting(SETTING_BRIGHTNESS, BRIGHTNESS_MIN, BRIGHTNESS_MAX, BRIGHTNESS_STEP, BRIGHTNESS_DEFAULT)
	Settings.set_setting_group(SETTING_BRIGHTNESS, GROUP_NAME)
	
	Settings.add_float_setting(SETTING_GUI_SCALE, GUI_SCALE_MIN, GUI_SCALE_MAX, GUI_SCALE_STEP, GUI_SCALE_DEFAULT)
	Settings.set_setting_group(SETTING_GUI_SCALE, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_VSYNC, vsync_array, 0)
	Settings.set_setting_group(SETTING_VSYNC, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_FPS_LIMIT, fps_limit_array, 0)
	Settings.set_setting_group(SETTING_FPS_LIMIT, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_MSAA, msaa_array, 0)
	Settings.set_setting_group(SETTING_MSAA, GROUP_NAME)
	
	Settings.add_bool_setting(SETTING_TAA, false)
	Settings.set_setting_group(SETTING_TAA, GROUP_NAME)
	
	Settings.add_bool_setting(SETTING_FXAA, false)
	Settings.set_setting_group(SETTING_FXAA, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SHADOW_SIZE, shadow_size_array, 3)
	Settings.set_setting_group(SETTING_SHADOW_SIZE, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SHADOW_FILTER, shadow_filter_array, 2)
	Settings.set_setting_group(SETTING_SHADOW_FILTER, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_MESH_LOD, mesh_lod_array, 3)
	Settings.set_setting_group(SETTING_MESH_LOD, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SSR, ssr_array, 0)
	Settings.set_setting_group(SETTING_SSR, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SSAO, ssao_array, 0)
	Settings.set_setting_group(SETTING_SSAO, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SSIL, ssil_array, 0)
	Settings.set_setting_group(SETTING_SSIL, GROUP_NAME)
	
	Settings.add_enum_setting(SETTING_SDFGI, sdfgi_array, 0)
	Settings.set_setting_group(SETTING_SDFGI, GROUP_NAME)
	
	Settings.add_bool_setting(SETTING_GLOW, false)
	Settings.set_setting_group(SETTING_GLOW, GROUP_NAME)
	
	Settings.connect("setting_changed", Callable(self, "on_setting_changed"))


func set_fullscreen_enabled(value : bool):
	Settings.set_setting(SETTING_FULLSCREEN, value)

func get_fullscreen_enabled() -> bool:
	return Settings.get_setting(SETTING_FULLSCREEN)


func set_brightness(value : bool):
	Settings.set_setting(SETTING_BRIGHTNESS, value)

func get_brightness() -> bool:
	return Settings.get_setting(SETTING_BRIGHTNESS)


func set_gui_scale(value : float):
	Settings.set_setting(SETTING_GUI_SCALE, value)

func get_gui_scale() -> float:
	return Settings.get_setting(SETTING_GUI_SCALE)


func set_vsync(value: int):
	Settings.set_setting(SETTING_VSYNC, value)

func get_vsync() -> bool:
	return Settings.get_setting(SETTING_VSYNC)


func set_fps_limit(value: int):
	Settings.set_setting(SETTING_FPS_LIMIT, value)

func get_fps_limit() -> bool:
	return Settings.get_setting(SETTING_FPS_LIMIT)


func set_msaa(value: int):
	Settings.set_setting(SETTING_MSAA, value)

func get_msaa() -> bool:
	return Settings.get_setting(SETTING_MSAA)


func set_taa(value: int):
	Settings.set_setting(SETTING_TAA, value)

func get_taa() -> bool:
	return Settings.get_setting(SETTING_TAA)


func set_fxaa(value: int):
	Settings.set_setting(SETTING_FXAA, value)

func get_fxaa() -> bool:
	return Settings.get_setting(SETTING_FXAA)


func set_shadow_size(value: int):
	Settings.set_setting(SETTING_SHADOW_SIZE, value)

func get_shadow_size() -> bool:
	return Settings.get_setting(SETTING_SHADOW_SIZE)


func set_shadow_filter(value: int):
	Settings.set_setting(SETTING_SHADOW_FILTER, value)

func get_shadow_filter() -> bool:
	return Settings.get_setting(SETTING_SHADOW_FILTER)


func set_mesh_lod(value: int):
	Settings.set_setting(SETTING_MESH_LOD, value)

func get_mesh_lod() -> bool:
	return Settings.get_setting(SETTING_MESH_LOD)


func set_ssr(value: int):
	Settings.set_setting(SETTING_SSR, value)

func get_ssr() -> bool:
	return Settings.get_setting(SETTING_SSR)


func set_ssao(value: int):
	Settings.set_setting(SETTING_SSAO, value)

func get_ssao() -> bool:
	return Settings.get_setting(SETTING_SSAO)


func set_ssil(value: int):
	Settings.set_setting(SETTING_SSIL, value)

func get_ssil() -> bool:
	return Settings.get_setting(SETTING_SSIL)


func set_sdfgi(value: int):
	Settings.set_setting(SETTING_SDFGI, value)

func get_sdfgi() -> bool:
	return Settings.get_setting(SETTING_SDFGI)


func set_glow(value: int):
	Settings.set_setting(SETTING_GLOW, value)

func get_glow() -> bool:
	return Settings.get_setting(SETTING_GLOW)


func on_setting_changed(setting_name, old_value, new_value):
	match setting_name:
		SETTING_FULLSCREEN:
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (new_value) else Window.MODE_WINDOWED
			#fullscreen_enabled = new_value
			emit_signal("fullscreen_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_BRIGHTNESS:
			if is_instance_valid(GameManager.game):   # If the game is loaded, change immediately
				GameManager.game.set_brightness()
			#brightness = new_value
			emit_signal("brightness_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_GUI_SCALE:
			#gui_scale = new_value
			emit_signal("gui_scale_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_VSYNC:
			# Vsync is enabled by default.
			# Vertical synchronization locks framerate and makes screen tearing not visible at the cost of
			# higher input latency and stuttering when the framerate target is not met.
			# Adaptive V-Sync automatically disables V-Sync when the framerate target is not met, and enables
			# V-Sync otherwise. This prevents suttering and reduces input latency when the framerate target
			# is not met, at the cost of visible tearing.
			if new_value == 0: # Disabled (default)
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			elif new_value == 1: # Adaptive
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
			elif new_value == 2: # Enabled
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			emit_signal("vsync_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_FPS_LIMIT:
			# The maximum number of frames per second that can be rendered.
			# A value of 0 means "no limit".
			if new_value == 0:
				Engine.max_fps = 0 # Disabled (default)
			if new_value == 1:
				Engine.max_fps = 60
			if new_value == 2:
				Engine.max_fps = 75
			if new_value == 3:
				Engine.max_fps = 90
			if new_value == 4:
				Engine.max_fps = 120
			if new_value == 5:
				Engine.max_fps = 144
			if new_value == 6:
				Engine.max_fps = 240
			emit_signal("fps_limit_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_MSAA:
			# Multi-sample anti-aliasing. High quality, but slow. It also does not smooth out the edges of
			# transparent (alpha scissor) textures.
			if new_value == 0: # Disabled (default)
				get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			elif new_value == 1: # 2×
				get_viewport().msaa_3d = Viewport.MSAA_2X
			elif new_value == 2: # 4×
				get_viewport().msaa_3d = Viewport.MSAA_4X
			elif new_value == 3: # 8×
				get_viewport().msaa_3d = Viewport.MSAA_8X
			emit_signal("msaa_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_TAA:
			# Temporal antialiasing. Smooths out everything including specular aliasing, but can introduce
			# ghosting artifacts and blurring in motion. Moderate performance cost.
			get_viewport().use_taa = new_value == true
			emit_signal("taa_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_FXAA:
			# Fast approximate anti-aliasing. Much faster than MSAA (and works on alpha scissor edges),
			# but blurs the whole scene rendering slightly.
			if new_value == true:
				get_viewport().screen_space_aa = 1
			else:
				get_viewport().screen_space_aa = 0
			emit_signal("fxaa_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SHADOW_SIZE:
			if new_value == 0: # Minimum
				RenderingServer.directional_shadow_atlas_set_size(512, true)
				# Adjust shadow bias according to shadow resolution.
				# Higher resultions can use a lower bias without suffering from shadow acne.
				#directional_light.shadow_bias = 0.06
				# Disable positional (omni/spot) light shadows entirely to further improve performance.
				# These often don't contribute as much to a scene compared to directional light shadows.
				get_viewport().positional_shadow_atlas_size = 0
			if new_value == 1: # Very Low
				RenderingServer.directional_shadow_atlas_set_size(1024, true)
				#directional_light.shadow_bias = 0.04
				get_viewport().positional_shadow_atlas_size = 1024
			if new_value == 2: # Low
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
				#directional_light.shadow_bias = 0.03
				get_viewport().positional_shadow_atlas_size = 2048
			if new_value == 3: # Medium (default)
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
				#directional_light.shadow_bias = 0.02
				get_viewport().positional_shadow_atlas_size = 4096
			if new_value == 4: # High
				RenderingServer.directional_shadow_atlas_set_size(8192, true)
				#directional_light.shadow_bias = 0.01
				get_viewport().positional_shadow_atlas_size = 8192
			if new_value == 5: # Ultra
				RenderingServer.directional_shadow_atlas_set_size(16384, true)
				#directional_light.shadow_bias = 0.005
				get_viewport().positional_shadow_atlas_size = 16384
			emit_signal("shadow_size_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SHADOW_FILTER:
			if new_value == 0: # Very Low
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			if new_value == 1: # Low
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
			if new_value == 2: # Medium (default)
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			if new_value == 3: # High
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			if new_value == 4: # Very High
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			if new_value == 5: # Ultra
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
				RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
			emit_signal("shadow_filter_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_MESH_LOD:
			if new_value == 0: # Very Low
				get_viewport().mesh_lod_threshold = 8.0
			if new_value == 1: # Low
				get_viewport().mesh_lod_threshold = 4.0
			if new_value == 2: # Medium
				get_viewport().mesh_lod_threshold = 2.0
			if new_value == 3: # High (default)
				get_viewport().mesh_lod_threshold = 1.0
			if new_value == 4: # Ultra
				# Always use highest LODs to avoid any form of pop-in.
				get_viewport().mesh_lod_threshold = 0.0
			emit_signal("mesh_lod_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SSR:
			# This is a setting that is attached to the environment.
			# If your game requires you to change the environment,
			# then be sure to run this function again to make the setting effective.
			if new_value == 0: # Disabled (default)
				GameManager.game.world_environment.environment.set_ssr_enabled(false)
			elif new_value == 1: # Low
				GameManager.game.world_environment.environment.set_ssr_enabled(true)
				GameManager.game.world_environment.environment.set_ssr_max_steps(8)
			elif new_value == 2: # Medium
				GameManager.game.world_environment.environment.set_ssr_enabled(true)
				GameManager.game.world_environment.environment.set_ssr_max_steps(32)
			elif new_value == 3: # High
				GameManager.game.world_environment.environment.set_ssr_enabled(true)
				GameManager.game.world_environment.environment.set_ssr_max_steps(56)
			emit_signal("ssr_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SSAO:
			# This is a setting that is attached to the environment.
			# If your game requires you to change the environment,
			# then be sure to run this function again to make the setting effective.
			if new_value == 0: # Disabled (default)
				GameManager.game.world_environment.environment.ssao_enabled = false
			if new_value == 1: # Very Low
				GameManager.game.world_environment.environment.ssao_enabled = true
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50, 300)
			if new_value == 2: # Low
				GameManager.game.world_environment.environment.ssao_enabled = true
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50, 300)
			if new_value == 3: # Medium
				GameManager.game.world_environment.environment.ssao_enabled = true
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
			if new_value == 4: # High
				GameManager.game.world_environment.environment.ssao_enabled = true
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)
			emit_signal("ssao_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SSIL:
			# This is a setting that is attached to the environment.
			# If your game requires you to change the environment,
			# then be sure to run this function again to make the setting effective.
			if new_value == 0: # Disabled (default)
				GameManager.game.world_environment.environment.ssil_enabled = false
			if new_value == 1: # Very Low
				GameManager.game.world_environment.environment.ssil_enabled = true
				RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, true, 0.5, 4, 50, 300)
			if new_value == 2: # Low
				GameManager.game.world_environment.environment.ssil_enabled = true
				RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50, 300)
			if new_value == 3: # Medium
				GameManager.game.world_environment.environment.ssil_enabled = true
				RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50, 300)
			if new_value == 4: # High
				GameManager.game.world_environment.environment.ssil_enabled = true
				RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH, true, 0.5, 4, 50, 300)
			emit_signal("ssil_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_SDFGI:
			# This is a setting that is attached to the environment.
			# If your game requires you to change the environment,
			# then be sure to run this function again to make the setting effective.
			if new_value == 0: # Disabled (default)
				GameManager.game.world_environment.environment.sdfgi_enabled = false
			if new_value == 1: # Low
				GameManager.game.world_environment.environment.sdfgi_enabled = true
				RenderingServer.gi_set_use_half_resolution(true)
			if new_value == 2: # High
				GameManager.game.world_environment.environment.sdfgi_enabled = true
				RenderingServer.gi_set_use_half_resolution(false)
			emit_signal("sdfgi_changed", new_value)
			SettingsConfig.save_settings()
		SETTING_GLOW:
			# This is a setting that is attached to the environment.
			# If your game requires you to change the environment,
			# then be sure to run this function again to make the setting effective.
			GameManager.game.world_environment.environment.glow_enabled = new_value == true
			emit_signal("glow_changed", new_value)
			SettingsConfig.save_settings()
