// CRT display functions. The CRT pass draws the internal-resolution image onto the
// screen, so it works in two spaces at once: scanlines and beam width follow the
// source rows (one scanline per internal row, whatever the window size), and the
// aperture grille follows screen pixels.

// Barrel distortion of a 0..1 UV around the centre. Points pushed outside 0..1 are
// off the tube.
vec2 tk_crt_curve(vec2 uv, float curvature) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	return c * 0.5 + 0.5;
}

bool tk_crt_off_tube(vec2 uv) {
	return any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)));
}

// Brightness of a scanline at vertical distance `d` (in rows) from its centre, for a
// row of colour `c`. Brighter rows draw a wider beam, so highlights bleed into the gap.
vec3 tk_crt_beam(vec3 c, float d, float bloom) {
	vec3 width = mix(vec3(0.25), vec3(0.25 + 0.25 * bloom), sqrt(clamp(c, 0.0, 1.0)));
	return c * exp(-(d * d) / (2.0 * width * width));
}

// Aperture grille: each screen column passes one of red, green or blue at full and
// the other two at 1 - strength. Scaled so a flat grey keeps its brightness.
vec3 tk_crt_mask(float screen_x, float strength) {
	int column = int(mod(floor(screen_x), 3.0));
	vec3 m = vec3(1.0 - strength);
	m[column] = 1.0;
	return m / (1.0 - strength * 2.0 / 3.0);
}

// Corner darkening on the curved UV. 1 at the centre.
float tk_crt_vignette(vec2 uv, float amount) {
	float v = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	return mix(1.0, pow(clamp(v, 0.0, 1.0), 0.3), amount);
}
