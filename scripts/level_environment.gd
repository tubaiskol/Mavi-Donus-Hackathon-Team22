extends RefCounted

const BACKGROUNDS := {
	1: preload("res://assets/backgrounds/bg1/full.png"),
	2: preload("res://assets/backgrounds/bg4/full.png"),
	3: preload("res://assets/backgrounds/bg3/full.png"),
	4: preload("res://assets/backgrounds/bg2/full.png"),
	5: preload("res://assets/general-game-background.jpeg")
}

# Kaynak görseldeki yatay su sınırları: resif üstü ve batığın suya girişi.
const SURFACE_SOURCE_Y := {1: 540.0, 2: 738.0}


static func has_surface(level: int) -> bool:
	return SURFACE_SOURCE_Y.has(level)


static func surface_y(screen: Rect2, level: int) -> float:
	if not has_surface(level):
		return screen.position.y
	var texture: Texture2D = BACKGROUNDS[level]
	var source_size := texture.get_size()
	# TextureRect.STRETCH_KEEP_ASPECT_COVERED ile aynı ölçek ve ortalama.
	var scale_factor := maxf(screen.size.x / source_size.x, screen.size.y / source_size.y)
	var image_top := screen.get_center().y - source_size.y * scale_factor * 0.5
	return clampf(image_top + float(SURFACE_SOURCE_Y[level]) * scale_factor, screen.position.y, screen.end.y)
