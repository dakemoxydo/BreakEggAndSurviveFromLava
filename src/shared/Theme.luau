local rgb = Color3.fromRGB
return {
	outline = 3,
	radius = 10,
	innerStroke = 1,
	bevel = 4,
	shadow = 4,
	index = { outline = 3, radius = 10, bevel = 4, shadow = 4 },
	colors = {
		ink = rgb(15, 17, 15),
		body = rgb(38, 40, 43),
		muted = rgb(76, 80, 85),
		green = rgb(100, 255, 0),
		blue = rgb(0, 192, 255),
		purple = rgb(206, 35, 255),
		gold = rgb(255, 202, 38),
		red = rgb(245, 36, 37),
		white = rgb(255, 255, 255),
	},
	studs = "rbxassetid://71143262474046",
	motion = {
		hoverScale = 1.05,
		denseHoverScale = 1.025,
		pressedScale = 0.96,
		frequency = 5,
		transitionFrequency = 4.8,
		precision = 0.005,
		transitionPrecision = 0.0005,
		-- Windows open on a softer spring than they close; onClosed fires once the window is this close to hidden.
		openFrequency = 3.8,
		closedAt = 0.02,
		-- Hover/press springs settle with a small bounce; opening windows overshoot a little more.
		dampingRatio = 0.62,
		openDampingRatio = 0.68,
		-- Hover tilt in degrees, toward the side the pointer entered from; wide buttons tilt less.
		tilt = 4,
		denseTilt = 1.5,
		-- Modal windows grow from this scale while fading in.
		openScale = 0.86,
		-- Cards and rows pop in one after another when a window opens.
		revealScale = 0.7,
		revealStagger = 0.035,
		-- Idle sway of item images: degrees, pixels, radians per second.
		swayAngle = 3,
		bobHeight = 4,
		swaySpeed = 1.8,
		burstSpeed = 18,
		-- Background pictures falling through a button (design px per second).
		fallSpeed = 26,
		-- Shine stripes sweep across in shineTime seconds, once every shineEvery seconds.
		shineTime = 0.7,
		shineEvery = 4,
		-- Header Studs conveyor: Figma tile period (420 px art at 0.14) and leftward speed, design px per second.
		studsPeriod = 58.8,
		studsSpeed = 18,
	},
}
