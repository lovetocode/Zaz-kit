class_name BgRemover

# Flood fills from the 4 corners, removing pixels close to the corner color.
# Anything inside the design stays, because the fill can't reach it.
static func remove_bg(src: Image, tol := 0.12) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var corners := [0, w - 1, (h - 1) * w, h * w - 1]
	var rr := 0
	var rg := 0
	var rb := 0
	for c in corners:
		rr += d[c * 4]
		rg += d[c * 4 + 1]
		rb += d[c * 4 + 2]
	rr /= 4
	rg /= 4
	rb /= 4
	var t := int(tol * 255.0)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for c in corners:
		stack.append(c)
	while stack.size() > 0:
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i] == 1:
			continue
		seen[i] = 1
		var o := i * 4
		if absi(d[o] - rr) > t or absi(d[o + 1] - rg) > t or absi(d[o + 2] - rb) > t:
			continue
		d[o + 3] = 0
		var x := i % w
		var y := i / w
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)
