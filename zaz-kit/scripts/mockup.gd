class_name Mockup

# Center-crops the photo to a square, then puts the cutout on it with a soft shadow.
static func build(photo: Image, cutout: Image, size := 240, fill := 0.72) -> Image:
	var bg := photo.duplicate() as Image
	bg.convert(Image.FORMAT_RGBA8)
	var side := mini(bg.get_width(), bg.get_height())
	var out := bg.get_region(Rect2i((bg.get_width() - side) / 2, (bg.get_height() - side) / 2, side, side))
	out.resize(size, size, Image.INTERPOLATE_LANCZOS)
	if cutout == null:
		return out

	var fg := cutout.duplicate() as Image
	var used := fg.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		fg = fg.get_region(used)
	var target := float(size) * fill
	var s := minf(target / fg.get_width(), target / fg.get_height())
	fg.resize(maxi(1, int(fg.get_width() * s)), maxi(1, int(fg.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	var pos := Vector2i((size - fg.get_width()) / 2, (size - fg.get_height()) / 2)

	# shadow = black copy of the cutout's alpha, offset and blurred
	var sd := fg.get_data()
	for i in range(0, sd.size(), 4):
		sd[i] = 0
		sd[i + 1] = 0
		sd[i + 2] = 0
		sd[i + 3] = int(sd[i + 3] * 0.55)
	var sh := Image.create_from_data(fg.get_width(), fg.get_height(), false, Image.FORMAT_RGBA8, sd)
	var layer := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var off := Vector2i(int(size * 0.025), int(size * 0.035))
	layer.blend_rect(sh, Rect2i(Vector2i.ZERO, sh.get_size()), pos + off)
	var small := maxi(8, size / 5)
	layer.resize(small, small, Image.INTERPOLATE_BILINEAR)
	layer.resize(size, size, Image.INTERPOLATE_BILINEAR)

	out.blend_rect(layer, Rect2i(0, 0, size, size), Vector2i.ZERO)
	out.blend_rect(fg, Rect2i(Vector2i.ZERO, fg.get_size()), pos)
	return out
