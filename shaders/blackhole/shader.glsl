// blackhole/shader.glsl — Ghostty black-hole reminder renderer
//
// Role split:
//   schedule.mjs  owns continuous-work streak state and sends an OSC 12 trigger.
//   shader.glsl   only recognizes that trigger and renders a 30-second effect.
//
// Ghostty config:
//   custom-shader = /Users/wanchenfang/.config/ghostty/shaders/blackhole/shader.glsl
//   custom-shader-animation = true

const float EFFECT_SECONDS    = 30.0;
const float MAX_SHADOW_RADIUS = 0.115;
const float LENS_STRENGTH     = 0.185;
const float DISK_GAIN         = 1.350;
const float WORK_AREA         = 0.240;
const float DRIFT_SPEED       = 0.170;

// Keep in sync with schedule.mjs: high nibbles #D_A_0_, low green = 1,
// low blue = event nonce, low red = checksum.
const ivec3 TRIGGER_BASE_HI = ivec3(0xD, 0xA, 0x0);

bool isTriggerColor(vec3 color) {
    vec3 c = clamp(color, 0.0, 1.0);
    ivec3 bytes = ivec3(floor(c * 255.0 + 0.5));
    ivec3 lo = bytes & 0xF;
    if ((bytes >> 4) != TRIGGER_BASE_HI) return false;
    if (lo.g != 0x1) return false;
    return lo.r == (lo.g ^ lo.b ^ 0xA);
}

float triggerProgress() {
    if (!isTriggerColor(iCurrentCursorColor.rgb)) return -1.0;
    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < 0.0 || elapsed > EFFECT_SECONDS) return -1.0;
    return elapsed / EFFECT_SECONDS;
}

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 rotate2(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2 mirrorUV(vec2 u) {
    return 1.0 - abs(1.0 - mod(u, 2.0));
}

float bell(float u, float fadeIn, float fadeOut) {
    return smoothstep(0.0, fadeIn, u) * (1.0 - smoothstep(1.0 - fadeOut, 1.0, u));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    float aspect = res.x / res.y;

    vec4 original = texture(iChannel0, uv);

    float progress = triggerProgress();
    if (progress < 0.0) {
        fragColor = original;
        return;
    }

    float active = bell(progress, 0.10, 0.22);
    if (active <= 0.001) {
        fragColor = original;
        return;
    }

    float yUp = 1.0 - uv.y;
    float shield = smoothstep(WORK_AREA, WORK_AREA + 0.16, yUp);
    float effect = active * shield;

    float t = iTime * DRIFT_SPEED;
    vec2 center = vec2(
        0.50 + 0.055 * sin(t * 1.70) + 0.025 * sin(t * 3.10 + 1.40),
        0.38 + 0.035 * sin(t * 1.13 + 2.20));

    float swell = sin(progress * 3.14159265);
    float shadowRadius = MAX_SHADOW_RADIUS * (0.45 + 0.55 * swell);
    vec2 p = (uv - center) * vec2(aspect, 1.0);
    float r = length(p);
    vec2 dir = p / max(r, 1e-5);

    float lensRadius = shadowRadius * 4.2;
    float lensWindow = exp(-pow(r / max(lensRadius, 1e-4), 2.0));
    float pull = LENS_STRENGTH * effect * shadowRadius * shadowRadius / (r * r + shadowRadius * shadowRadius);
    vec2 tangent = vec2(-dir.y, dir.x);
    vec2 warpedP = p + dir * pull + tangent * pull * 0.28 * sin(10.0 * r - iTime * 1.8);
    vec2 sampleUV = mirrorUV(center + warpedP / vec2(aspect, 1.0));

    vec3 lensed;
    float chroma = 0.010 * effect * lensWindow;
    lensed.r = texture(iChannel0, mirrorUV(sampleUV + dir * chroma / vec2(aspect, 1.0))).r;
    lensed.g = texture(iChannel0, sampleUV).g;
    lensed.b = texture(iChannel0, mirrorUV(sampleUV - dir * chroma / vec2(aspect, 1.0))).b;

    vec2 q = rotate2(p, 0.28);
    vec2 diskP = vec2(q.x, q.y / 0.34);
    float diskR = length(diskP);
    float diskAngle = atan(diskP.y, diskP.x);
    float ringR = shadowRadius * 1.55;
    float ringW = shadowRadius * 0.24;
    float ring = exp(-pow((diskR - ringR) / max(ringW, 1e-4), 2.0));
    float streak = noise2(vec2(diskR * 40.0, diskAngle * 3.0 + iTime * 1.7));
    float hotSide = 0.58 + 0.42 * smoothstep(-0.55, 0.85, cos(diskAngle - 0.85));
    vec3 diskColor = mix(vec3(1.00, 0.33, 0.05), vec3(1.00, 0.82, 0.28), hotSide);
    vec3 disk = diskColor * ring * (0.55 + 0.95 * streak) * DISK_GAIN * effect;

    float shadow = 1.0 - smoothstep(shadowRadius * 0.78, shadowRadius * 1.05, r);
    float photonRing = exp(-pow((r - shadowRadius * 1.04) / max(shadowRadius * 0.055, 1e-4), 2.0));
    vec3 photon = vec3(1.0, 0.68, 0.18) * photonRing * effect;

    float coreDim = 1.0 - smoothstep(shadowRadius * 0.65, lensRadius * 1.15, r);
    float dim = 1.0 - 0.32 * effect * coreDim;
    vec3 color = lensed * dim;
    color = mix(color, vec3(0.0), shadow * effect);

    float mixAmount = clamp(effect * lensWindow, 0.0, 1.0);
    vec3 finalColor = mix(original.rgb, color, mixAmount) + disk + photon;
    fragColor = vec4(finalColor, original.a);
}
