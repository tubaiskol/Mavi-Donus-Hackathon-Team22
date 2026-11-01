extends RefCounted

const EDGE_MARGIN := 15.0
const WIDTH := 250.0
const DOCK_HEIGHT := 180.0
const GAP := 12.0


static func dock_rect(screen: Rect2) -> Rect2:
	return Rect2(screen.end - Vector2(WIDTH + EDGE_MARGIN, DOCK_HEIGHT + EDGE_MARGIN), Vector2(WIDTH, DOCK_HEIGHT))


static func quests_rect(screen: Rect2, height: float) -> Rect2:
	var dock := dock_rect(screen)
	return Rect2(dock.position - Vector2(0, height + GAP), Vector2(WIDTH, height))


static func container_body_rect(screen: Rect2) -> Rect2:
	return Rect2(dock_rect(screen).get_center() - Vector2(52, 36), Vector2(104, 72))
