// Light variant: retain the animation and shade only the configured background.
// Standalone for Ghostty; macOS Metal, native blending, configured sRGB colors.
// Palette values are native gamma-encoded Display P3. Preserve input alpha.

// This Ghostty shader is a lightly modified port of https://www.shadertoy.com/view/4dBGRw


//Creates a diagonal red-and-white striped pattern.
vec3 barberpole(vec2 pos, vec2 rocketpos) {
    float d = (pos.x - rocketpos.x) + (pos.y - rocketpos.y);
    vec3 col = vec3(1.0);

    d = mod(d * 20., 2.0);
    if (d > 1.0) {
        col = vec3(1.0, 0.0, 0.0);
    }

    return col;
}

vec3 rocket(vec2 pos, vec2 rocketpos) {
    vec3 col = vec3(0.0);
    float f = 0.;
    float absx = abs(rocketpos.x - pos.x);
    float absy = abs(rocketpos.y - pos.y);

    // Wooden stick
    if (absx < 0.01 && absy < 0.22) {
        col = vec3(1.0, 0.5, 0.5);
    }

    // Barberpole
    if (absx < 0.05 && absy < 0.15) {
        col = barberpole(pos, rocketpos);
    }

    // Rocket Point
    float pointw = (rocketpos.y - pos.y - 0.25) * -0.7;
    if ((rocketpos.y - pos.y) > 0.1) {
        f = smoothstep(pointw - 0.001, pointw + 0.001, absx);

        col = mix(vec3(1.0, 0.0, 0.0), col, f);
    }

    // Shadow
    f = -.5 + smoothstep(-0.05, 0.05, (rocketpos.x - pos.x));
    col *= 0.7 + f;

    return col;
}

float rand(float val, float seed) {
    return cos(val * sin(val * seed) * seed);
}

float distance2(in vec2 a, in vec2 b) {
    return dot(a - b, a - b);
}

mat2 rr = mat2(cos(1.0), -sin(1.0), sin(1.0), cos(1.0));

vec3 drawParticles(vec2 pos, vec3 particolor, float time, vec2 cpos, float gravity, float seed, float timelength) {
    vec3 col = vec3(0.0);
    // All particles lie within time + the 0.01-unit antialiasing radius.
    if (distance2(pos, cpos) > (time + 0.011) * (time + 0.011)) return col;
    vec2 pp = vec2(1.0, 0.0);
    for (float i = 1.0; i <= 128.0; i++) {
        float d = rand(i, seed);
        float fade = max((i / 128.0) * time, 0.000001);
        vec2 particpos = cpos + time * pp * d;
        pp = rr * pp;
        col = mix(particolor / fade, col, smoothstep(0.0, 0.0001, distance2(particpos, pos)));
    }
    col *= smoothstep(0.0, 1.0, (timelength - time) / timelength);

    return col;
}
vec3 drawFireworks(float time, vec2 uv, vec3 particolor, float seed) {
    float timeoffset = 2.0;
    vec3 col = vec3(0.0);
    if (time <= 0.) {
        return col;
    }
    if (mod(time, 6.0) > timeoffset) {
        col = drawParticles(uv, particolor, mod(time, 6.0) - timeoffset, vec2(rand(ceil(time / 6.0), seed), -0.5), 0.5, ceil(time / 6.0), seed);
    } else {
        col = rocket(uv * 3., vec2(3. * rand(ceil(time / 6.0), seed), 3. * (-0.5 + (timeoffset - mod(time, 6.0)))));
    }
    return col;
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

    vec2 uv = 1.0 - 2.0 * termUV;
    uv.x *= iResolution.x / iResolution.y;
    uv.y = -uv.y;
    vec3 effect = drawFireworks(iTime, uv, vec3(1.0, 0.1, 0.1), 1.0);
    effect += drawFireworks(iTime - 2.0, uv, vec3(0.0, 1.0, 0.5), 2.0);
    effect += drawFireworks(iTime - 4.0, uv, vec3(1.0, 1.0, 0.1), 3.0);
    float intensity = max(effect.r, max(effect.g, effect.b));
    vec3 hue = effect / max(intensity, 0.000001);
    vec3 ink = mix(vec3(0.20), hue * 0.60, 0.80);
    float opacity = 0.25 * intensity / (1.0 + intensity);
    fragColor.rgb = mix(fragColor.rgb, ink * fragColor.a, opacity * mask);
}
