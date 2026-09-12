// Light variant: retain the animation and shade only the configured background.
// Standalone for Ghostty; macOS Metal, native blending, configured sRGB colors.
// Palette values are native gamma-encoded Display P3. Preserve input alpha.

// based on the following Shader Toy entry
//
// [SH17A] Matrix rain. Created by Reinder Nijhoff 2017
// Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
// @reindernijhoff
//
// https://www.shadertoy.com/view/ldjBW1
//

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

    // Bound the vanishing point so center pixels never divide by zero.
    vec3 v = vec3(fragCoord, 1.0) / iResolution - 0.5;
    vec3 s = 0.9 / max(abs(v), vec3(0.00001));
    s.z = min(s.y, s.x);
    vec3 cell = ceil(800.0 * s.z * (s.y < s.x ? v.xzz : v.zyz)) * 0.1;
    vec3 local = fract(cell);
    cell -= local;
    vec3 p = vec3(9.0, floor(iTime * (9.0 + 8.0 * sin(cell.x))), 0.0) + cell;
    float rain = fract(100.0 * sin(p.x * 8.0 + p.y)) / s.z;
    p *= local;
    float glyph = fract(100.0 * sin(p.x * 8.0 + p.y));
    if (glyph <= 0.5 || local.x >= 0.6 || local.y >= 0.8) return;
    float opacity = clamp(rain, 0.0, 1.0) * 0.24 * mask;
    fragColor.rgb = mix(fragColor.rgb, vec3(0.15, 0.40, 0.32) * fragColor.a, opacity);
}
