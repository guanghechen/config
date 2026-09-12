// Light variant: retain the animation and shade only the configured background.
// Standalone for Ghostty; macOS Metal, native blending, configured sRGB colors.
// Palette values are native gamma-encoded Display P3. Preserve input alpha.

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 10.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

  // First corner
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);

  // Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);

  //   x0 = x0 - 0.0 + 0.0 * C.xxx;
  //   x1 = x0 - i1  + 1.0 * C.xxx;
  //   x2 = x0 - i2  + 2.0 * C.xxx;
  //   x3 = x0 - 1.0 + 3.0 * C.xxx;
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

  // Permutations
  i = mod289(i);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y +
                           vec4(0.0, i1.y, i2.y, 1.0)) +
                   i.x + vec4(0.0, i1.x, i2.x, 1.0));

  // Gradients: 7x7 points over a square, mapped onto an octahedron.
  // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
  float n_ = 0.142857142857; // 1.0/7.0
  vec3 ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z); //  mod(p,7*7)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_); // mod(j,N)

  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);

  // vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
  // vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);

  // Normalise gradients
  vec4 norm =
      taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  // Mix final noise value
  vec4 m =
      max(0.5 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 105.0 *
         dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float noise2D(vec2 uv) {
  uvec2 pos = uvec2(floor(uv * 1000.));
  return float((pos.x * 68657387u ^ pos.y * 361524851u + pos.x) % 890129u) *
         (1.0 / 890128.0);
}

float roundRectSDF(vec2 center, vec2 size, float radius) {
  return length(max(abs(center) - size + radius, 0.)) - radius;
}

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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 termUV = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, termUV);
    vec3 background = srgbToDisplayP3(iBackgroundColor);
    float mask = backgroundMask(fragColor, background);
    if (mask <= 0.0) return;

    vec2 uv = termUV;
    float ratio = iResolution.y / iResolution.x;
    // Exact pixel derivatives for this full-viewport UV mapping.
    float fw = max(1.0 / iResolution.x, 1.0 / iResolution.y);
    vec2 puv = floor(uv * vec2(60.0, 60.0 * ratio)) / 60.0;
    puv += (smoothstep(0.0, 0.7, noise2D(puv)) - 0.5) * 0.05 - vec2(0.0, iTime * 0.08);
    uv = fract(vec2(uv.x, uv.y * ratio) * 10.0);
    float d = roundRectSDF(2.01 * (uv - 0.5), vec2(1.0), 0.075);
    float d2 = roundRectSDF(2.065 * (fract(uv * 6.0) - 0.5), vec2(1.0), 0.2);
    float noiseTime = iTime * 0.03;
    float field = snoise(vec3(puv, noiseTime));
    field += snoise(vec3(puv * 1.1, noiseTime + 0.5)) + 0.1;
    field += snoise(vec3(puv * 2.0, noiseTime + 0.8));
    field *= field;
    float shade = mix(0.0, 0.07898, smoothstep(0.0, 0.3, field));
    shade = mix(shade, 0.0, smoothstep(0.0, 0.5, field));
    shade = mix(shade, 0.089184, smoothstep(0.0, 1.0, field));
    float tiles = (1.0 - smoothstep(-fw, fw, d)) * (1.0 - smoothstep(-fw, fw, d2));
    float opacity = mix(1.0, shade / 0.089184, tiles) * 0.10 * mask;
    fragColor.rgb = mix(fragColor.rgb, vec3(0.33, 0.38, 0.44) * fragColor.a, opacity);
}
