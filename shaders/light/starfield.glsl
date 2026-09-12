// Light variant: retain the animation and shade only the configured background.
// Standalone for Ghostty; macOS Metal, native blending, configured sRGB colors.
// Palette values are native gamma-encoded Display P3. Preserve input alpha.

// Retains the original 21-layer star flight and per-cell star positions.
float N21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

vec2 N22(vec2 p) {
    float n = N21(p);
    return vec2(n, N21(p + n));
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

float starLayer(vec2 uv, float offset) {
    float phase = -(iTime + offset) / 21.0;
    float depth = fract(phase);
    // A collapsed layer covers the viewport with one constant sample.
    if (depth < 0.001) return 0.0;
    uv = (uv - 0.5) * depth + 0.5;
    uv.x *= iResolution.x / iResolution.y;
    uv *= 30.0;
    vec2 cell = floor(uv);
    vec2 point = N22(floor(phase) + cell * (offset + 1.0)) * 0.9 + 0.05;
    vec2 distance = (point - fract(uv)) * (N21(cell) * 100.0 + 200.0);
    float glow = 1.0 / max(dot(distance, distance), 0.0001);
    return glow * (1.0 - smoothstep(0.8, 1.0, depth));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 termUV = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, termUV);
    vec3 background = srgbToDisplayP3(iBackgroundColor);
    float mask = backgroundMask(fragColor, background);
    if (mask <= 0.0) return;

    float stars = 0.0;
    for (int i = 0; i < 21; i++) stars += starLayer(termUV, float(i));
    float opacity = 0.42 * stars / (1.0 + stars) * mask;
    fragColor.rgb = mix(fragColor.rgb, vec3(0.28, 0.35, 0.45) * fragColor.a, opacity);
}
