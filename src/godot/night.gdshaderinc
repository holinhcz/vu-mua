// Ban đêm, shared by every village shader: the game's night colours as one formula of the day colour (no extra pass,
// no texture). Fitted (least squares, 2nd order in r g b) from the web game's own day and night captures of the same
// views (tools/nightfit.py); mean error ~4/255. uNight 0 = day, 1 = night (main._night_tick sets it on every material).
uniform float uNight = 0.0;
vec3 night_col(vec3 c) {
	// (b54, Link 11-13 19:51 web vs Godot night screenshots: Godot was about half as bright as the web) the web's night is
	// the day picture a little darker and bluer: the godot/ export night frames are day x (0.64 0.68 0.80) on average,
	// the web's night field is day x (0.52 0.66 0.69); one per-channel factor between the two
	if (uNight <= 0.0) return c;
	return mix(c, c * vec3(0.60, 0.68, 0.78), uNight);
}
