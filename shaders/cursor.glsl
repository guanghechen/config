// Cursor motion for Ghostty 1.3+: a tapered smear and railgun-style bubbles.
// One texture sample, no frame history, one bubble candidate at normal cursor sizes.
// macOS Metal, alpha-blending=native, window-colorspace=srgb:
// uniforms are sRGB; the input/output textures are gamma-encoded Display P3.

const float TRAIL_SECONDS = 0.20;
const float TRAIL_OPACITY = 0.65;
const float BUBBLE_SECONDS = 0.42;
const float BUBBLE_DELAY = 0.04;
const float BUBBLE_OPACITY = 0.75; // Set to 0.0 for the smear alone.
const float BUBBLE_FILL_OPACITY = 0.32;
const float BUBBLE_DARK_GAIN = 1.65;
const float MAX_BUBBLES = 32.0;
const float BUBBLE_RADIUS_SCALE = 0.16;
const vec2 BUBBLE_STROKE_SCALE = vec2(0.026, 0.016);
const float BUBBLE_MIN_STROKE_PX = 0.50;

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

float bubbleHash(float value) {
    value = fract(value * 0.1031);
    value *= value + 33.33;
    return fract(value * (value + value));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < 0.0 || elapsed >= BUBBLE_SECONDS + BUBBLE_DELAY
        || iFocus == 0 || iCursorVisible == 0
        || iTimeCursorChange <= iTimeFocus) return;

    // Ignore uninitialized geometry, font-height changes, and cursor mode changes.
    if (any(lessThanEqual(iCurrentCursor.zw, vec2(0.0)))
        || any(lessThanEqual(iPreviousCursor.zw, vec2(0.0)))
        || abs(iCurrentCursor.w - iPreviousCursor.w) > 0.5
        || iCurrentCursorStyle != iPreviousCursorStyle) return;

    vec2 movement = iCurrentCursor.xy - iPreviousCursor.xy;
    if (dot(movement, movement) < 1.0) return;

    vec2 currentHalf = iCurrentCursor.zw * 0.5;
    vec2 current = iCurrentCursor.xy + vec2(currentHalf.x, -currentHalf.y);
    vec2 previous = iPreviousCursor.xy + iPreviousCursor.zw * vec2(0.5, -0.5);
    if (any(lessThan(current, vec2(0.0))) || any(greaterThan(current, iResolution.xy))
        || any(lessThan(previous, vec2(0.0))) || any(greaterThan(previous, iResolution.xy))) return;

    float scale = max(max(iCurrentCursor.z, iCurrentCursor.w),
        max(iPreviousCursor.z, iPreviousCursor.w));
    float aa = max(0.75, scale * 0.025);
    float margin = scale * 0.9 + aa * 2.0;
    if (any(lessThan(fragCoord, min(previous, current) - margin))
        || any(greaterThan(fragCoord, max(previous, current) + margin))) return;

    // Leave the actual cursor and its glyph untouched, including the AA edge.
    if (all(lessThanEqual(abs(fragCoord - current), currentHalf + aa))) return;

    vec2 delta = current - previous;
    float pathLength = length(delta);
    if (pathLength < 1.0) return;
    vec2 direction = delta / pathLength;
    vec2 normal = vec2(-direction.y, direction.x);
    vec2 relative = fragCoord - previous;
    float along = dot(relative, direction);
    float across = dot(relative, normal);
    if (along < -margin || along > pathLength + margin || abs(across) > margin) return;

    float trail = 0.0;
    if (elapsed < TRAIL_SECONDS) {
        float remaining = 1.0 - elapsed / TRAIL_SECONDS;
        float tail = pathLength * (1.0 - remaining * remaining * remaining);
        float position = clamp((along - tail) / max(pathLength - tail, 0.001), 0.0, 1.0);
        float halfWidth = mix(scale * 0.035, dot(abs(normal), currentHalf) * 0.85, position);
        float edge = 1.0 - smoothstep(halfWidth, halfWidth + aa, abs(across));
        float ends = smoothstep(tail - aa, tail + aa, along)
            * (1.0 - smoothstep(pathLength - aa, pathLength + aa, along));
        trail = edge * ends * remaining * mix(0.25, 1.0, position) * TRAIL_OPACITY;
    }

    float bubbles = 0.0;
    float highlights = 0.0;
    // Ordinary typing gets only a short smear; larger jumps get the railgun rings.
    if (BUBBLE_OPACITY > 0.0 && pathLength >= scale * 2.0) {
        float spacing = max(scale * 1.5, pathLength / MAX_BUBBLES);
        float nearest = floor(along / spacing);
        float seed = dot(previous, vec2(0.013, 0.017));
        // Keep the reflection fixed in screen space when the cursor changes direction.
        vec2 light = vec2(dot(direction, vec2(-0.6, 0.8)), dot(normal, vec2(-0.6, 0.8)));
        float maxRadius = scale * BUBBLE_RADIUS_SCALE;
        float maxThickness = max(BUBBLE_MIN_STROKE_PX,
            scale * max(BUBBLE_STROKE_SCALE.x, BUBBLE_STROKE_SCALE.y));
        float bubbleExtent = maxRadius + maxThickness + aa;
        // A ring contained in its spacing cell cannot reach a neighboring cell.
        // Tiny cursors can cross the boundary because AA has a pixel-size floor.
        int neighbors = bubbleExtent < spacing * 0.5 ? 0 : 1;
        for (int offset = -neighbors; offset <= neighbors; offset++) {
            float index = nearest + float(offset);
            float center = (index + 0.5) * spacing;
            if (index < 0.0 || center > pathLength
                || abs(along - center) > bubbleExtent) continue;

            float proximity = center / pathLength;
            float age = elapsed - BUBBLE_DELAY * proximity;
            float lifetime = BUBBLE_SECONDS * mix(0.78, 1.0, proximity);
            if (age <= 0.0 || age >= lifetime) continue;
            float life = age / lifetime;
            float growth = life * (2.0 - life);
            float random = bubbleHash(index + seed);
            float phase = index * 2.399963 + random * 6.283185 + life * 2.0;
            float drift = sin(phase) * scale * (0.18 + life * 0.28);
            // Perspective follows the jump: small at the old position, large near the cursor.
            // Time only adds a slight expansion, preserving that spatial size gradient.
            float perspective = mix(0.38, 1.0, proximity * proximity);
            float radius = maxRadius * perspective * mix(0.9, 1.0, growth);
            float thickness = max(BUBBLE_MIN_STROKE_PX,
                scale * mix(BUBBLE_STROKE_SCALE.x, BUBBLE_STROKE_SCALE.y, growth));
            vec2 ringPoint = vec2(along - center, across - drift);
            if (any(greaterThan(abs(ringPoint), vec2(radius + thickness + aa)))) continue;

            float ringDistance = length(ringPoint);
            float ring = 1.0 - smoothstep(thickness - aa, thickness + aa,
                abs(ringDistance - radius));
            float fill = 1.0 - smoothstep(radius - aa, radius + aa, ringDistance);
            float lighting = dot(ringPoint, light) / max(ringDistance, aa);
            float reflection = smoothstep(0.55, 0.96, lighting);
            float oppositeRim = smoothstep(0.65, 1.0, -lighting);
            float fade = smoothstep(0.0, 0.018, age) * (1.0 - smoothstep(0.28, 1.0, life));
            fade *= mix(0.7, 1.0, proximity);
            // Neovide's thick strokes read as filled particles at small sizes.
            float coverage = fade * BUBBLE_OPACITY;
            float body = max(fill * BUBBLE_FILL_OPACITY, ring * (0.50 + 0.12 * oppositeRim));
            bubbles = max(bubbles, coverage * body);
            highlights = max(highlights, coverage * ring * reflection);
        }
    }

    if (max(trail, max(bubbles, highlights)) <= 0.0) return;

    vec3 backgroundColor = srgbToDisplayP3(iBackgroundColor);
    vec3 cursorColor = srgbToDisplayP3(iCurrentCursorColor.rgb);
    float lightBackground = smoothstep(0.35, 0.75,
        dot(backgroundColor, vec3(0.2126, 0.7152, 0.0722)));
    // Earlier shaders can darken the background; that alone does not imply text.
    vec3 backgroundDelta = fragColor.rgb - backgroundColor;
    vec3 contentDelta = mix(max(backgroundDelta, vec3(0.0)), backgroundDelta, lightBackground);
    float content = smoothstep(0.08, 0.35, length(contentDelta));
    float visibility = iCurrentCursorColor.a * mix(1.0, 0.25, content);
    fragColor.rgb = mix(fragColor.rgb, cursorColor * fragColor.a, trail * visibility);
    // Dark backgrounds need more particle contrast, while light themes keep their opacity.
    float particleVisibility = visibility * mix(BUBBLE_DARK_GAIN, 1.0, lightBackground);
    vec3 rimColor = mix(vec3(0.98), vec3(0.2), lightBackground);
    rimColor = mix(rimColor, cursorColor, 0.12);
    fragColor.rgb = mix(fragColor.rgb, rimColor * fragColor.a,
        clamp(bubbles * particleVisibility, 0.0, 1.0));
    vec3 reflectionColor = mix(vec3(1.0), cursorColor, 0.08);
    fragColor.rgb = mix(fragColor.rgb, reflectionColor * fragColor.a, highlights * visibility);
}
