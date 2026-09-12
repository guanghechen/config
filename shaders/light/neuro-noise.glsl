// Source: https://github.com/lexrus/lex-ghostty-shaders/blob/132eb505390cbb9dab7b8f5f84de5045ccc1056c/neuro_noise.glsl
// Upstream Paper Design code: https://www.apache.org/licenses/LICENSE-2.0
// Powered by Paper Shaders: https://shaders.paper.design
// Modified 2026-09-12: background-only rendering, light palette,
// preserved alpha, and macOS Metal/native/sRGB color matching.
// Palette constants below are gamma-encoded Display P3, as in Ghostty's texture.

// Neuro shape: zozuar, https://x.com/zozuar/status/1625182758745128981
// Paper Design: https://github.com/paper-design/shaders (neuro-noise.ts).
// Modified to work with opaque backgrounds instead of relying on 1 - terminal.a.

vec3 srgbToDisplayP3(vec3 color) {
    vec3 linear = mix(
        pow((color + 0.055) / 1.055, vec3(2.4)),
        color / 12.92,
        lessThanEqual(color, vec3(0.04045))
    );
    // Ghostty 1.3.1 shaders.metal: precomposed D50 sRGB -> XYZ -> Display P3.
    const mat3 conversion = mat3(
        vec3(0.822545400385, 0.033175949970, 0.017149503676),
        vec3(0.177358540694, 0.966882867076, 0.072423415948),
        vec3(0.000020894241, -0.000070714284, 0.910822964610)
    );
    linear = conversion * linear;
    vec3 encoded = mix(
        1.055 * pow(max(linear, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
        linear * 12.92,
        lessThanEqual(linear, vec3(0.0031308))
    );
    // The rounded conversion matrix can place gamut endpoints slightly outside [0, 1].
    return clamp(encoded, 0.0, 1.0);
}


float backgroundMask(vec4 terminal, vec3 background) {
    if (terminal.a <= 0.0) return 0.0;
    // Compare straight colors so window transparency does not look like text.
    float difference = length(terminal.rgb / terminal.a - background);
    return 1.0 - smoothstep(0.01, 0.12, difference);
}

const vec3  COLOR_FRONT   = vec3(1.0);                  // #ffffff crossing-point highlight
const float BRIGHTNESS    = 0.05;                       // luminosity of crossing points (0..1)
const float CONTRAST      = 0.3;                        // sharpness of the bright-dark transition (0..1)
const float PATTERN_SCALE = 0.13;                       // shape_uv scale (upstream literal); smaller = denser web

// --- colorMid: rotating neon palette ---------------------------------------
// colorMid cycles continuously through these key colors. Add/remove entries
// freely; the palette interpolates between adjacent stops and wraps around.
const float COLOR_CYCLE_SPEED = 0.08;                   // full palette passes per second (lower = slower)
const vec3  NEON_0 = vec3(1.0, 0.06, 0.94);             // hot pink  #ff10f0
const vec3  NEON_1 = vec3(0.0, 1.0, 1.0);               // cyan      #00ffff
const vec3  NEON_2 = vec3(0.22, 1.0, 0.08);             // neon green#39ff14
const vec3  NEON_3 = vec3(1.0, 0.84, 0.0);              // neon yellow #ffd700
const vec3  NEON_4 = vec3(1.0, 0.34, 0.12);             // neon orange #ff571f
const vec3  NEON_5 = vec3(0.31, 0.31, 1.0);             // electric indigo #4f4fff
// ===========================================================================

#define TWO_PI 6.28318530718

// --- rotate (upstream shader-utils.ts, rotation2) --------------------------
vec2 rotate(vec2 uv, float th) {
  return mat2(cos(th), sin(th), -sin(th), cos(th)) * uv;
}

// Smoothly cycle colorMid through the neon palette. `phase` is a continuous
// index into the stops; fractional parts blend adjacent colors with a
// smoothstep for a flowing, non-linear transition.
vec3 neonMidColor(float phase) {
  float n = 6.0;                          // number of palette stops above
  float i = mod(phase, n);                // continuous index in [0, n)
  float idx = floor(i);
  float f = i - idx;
  float s = smoothstep(0.0, 1.0, f);      // ease the crossfade

  // Lookup table (kept inline to stay self-contained, per repo conventions).
  vec3 a, b;
  if      (idx < 0.5) { a = NEON_0; b = NEON_1; }
  else if (idx < 1.5) { a = NEON_1; b = NEON_2; }
  else if (idx < 2.5) { a = NEON_2; b = NEON_3; }
  else if (idx < 3.5) { a = NEON_3; b = NEON_4; }
  else if (idx < 4.5) { a = NEON_4; b = NEON_5; }
  else                { a = NEON_5; b = NEON_0; }   // wrap

  return mix(a, b, s);
}

// zozuar's neuro shape: 15 rotated, time-drifting octaves accumulating
// cos/sin into a web field. Returns a value used (squared) for brightness.
float neuroShape(vec2 uv, float t) {
  vec2 sine_acc = vec2(0.);
  vec2 res = vec2(0.);
  float scale = 8.;

  for (int j = 0; j < 15; j++) {
    uv = rotate(uv, 1.);
    sine_acc = rotate(sine_acc, 1.);
    vec2 layer = uv * scale + float(j) + sine_acc - t;
    sine_acc += sin(layer);
    res += (.5 + .5 * cos(layer)) / scale;
    scale *= (1.2);
  }
  return res.x + res.y;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);
    vec3 background = srgbToDisplayP3(iBackgroundColor);
    float mask = backgroundMask(fragColor, background);
    if (mask <= 0.0) return;
    const float lightTheme = 1.0;

    vec2 shapeUV = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0)
        * PATTERN_SCALE * 10.0;
    float field = neuroShape(shapeUV, 0.5 * iTime);
    field = pow(max(0.0, (1.0 + BRIGHTNESS) * field * field), 0.7 + 6.0 * CONTRAST);
    field = min(1.4, field);
    vec3 midColor = neonMidColor(iTime * COLOR_CYCLE_SPEED);
    vec3 darkColor = mix(midColor, COLOR_FRONT, smoothstep(0.7, 1.4, field));
    vec3 lightColor = mix(vec3(0.18, 0.25, 0.35), midColor * 0.55, 0.35);
    vec3 color = mix(darkColor, lightColor, lightTheme);
    fragColor.rgb = mix(fragColor.rgb, color * fragColor.a,
        clamp(field, 0.0, 1.0) * mask * mix(0.28, 0.16, lightTheme));
}
