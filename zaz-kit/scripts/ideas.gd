class_name Ideas

const SUBJECTS := ["parachuting Santa", "sleepy fox", "retro robot", "cactus in sunglasses"]
const STYLES := ["psychedelic marbled", "flat vector", "vintage woodcut", "pastel watercolor"]
const SETTINGS := ["snowy cabin", "desert sunset", "neon city", "mountain meadow"]
const BG_SUBJECTS := ["snow forest", "wooden table", "marble texture", "sunset sky", "mountain lake", "paper texture", "christmas lights"]


static func roll() -> Dictionary:
	var s: String = SUBJECTS.pick_random()
	var st: String = STYLES.pick_random()
	var se: String = SETTINGS.pick_random()
	return {
		"subject": s,
		"desc": "%s, %s style, %s" % [s, st, se],
		"prompt": "%s, %s style, %s, white background, centered" % [s, st, se],
	}
