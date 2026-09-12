// credits: https://github.com/rymdlego
//
// Light-theme variant: preserves the original geometry and animation, but
// renders the cubes as subtle cool-gray ink instead of additive white light.
// The effect is restricted to pixels matching Ghostty's configured background
// color so glyphs, ANSI colors, selections, and cursor pixels remain legible.

const float speed = 0.2;
const float cube_size = 1.0;
const float cube_opacity = 0.12;
const float cube_rotation_speed = 2.8;
const float camera_rotation_speed = 0.1;

const vec3 CUBE_INK = vec3(0.32, 0.38, 0.46);
const float CUBE_SPECULAR_WEIGHT = 0.45;
const float BACKGROUND_EDGE_START = 0.01;
const float BACKGROUND_EDGE_END = 0.12;



mat3 rotationMatrix(vec3 m,float a) {
    m = normalize(m);
    float c = cos(a),s=sin(a);
    return mat3(c+(1.-c)*m.x*m.x,
        (1.-c)*m.x*m.y-s*m.z,
        (1.-c)*m.x*m.z+s*m.y,
        (1.-c)*m.x*m.y+s*m.z,
        c+(1.-c)*m.y*m.y,
        (1.-c)*m.y*m.z-s*m.x,
        (1.-c)*m.x*m.z-s*m.y,
        (1.-c)*m.y*m.z+s*m.x,
        c+(1.-c)*m.z*m.z);
}

float sphere(vec3 pos, float radius)
{
    return length(pos) - radius;
}

float box(vec3 pos, vec3 size)
{
    float t = iTime;
    pos = pos * 0.9 * rotationMatrix(vec3(sin(t/4.0*speed)*10.,cos(t/4.0*speed)*12.,2.7), t*2.4/4.0*speed*cube_rotation_speed);
    return length(max(abs(pos) - size, 0.0));
}


float distfunc(vec3 pos)
{
    float t = iTime;

    float size = 0.45 + 0.25*abs(16.0*sin(t*speed/4.0));
    // float size = 2.3 + 1.8*tan((t-5.4)*6.549);
    size = cube_size * 0.16 * clamp(size, 2.0, 4.0);

    //pos = pos * rotationMatrix(vec3(0.,-3.,0.7), 3.3 * mod(t/30.0, 4.0));
    vec3 q = mod(pos, 5.0) - 2.5;
    float obj1 = box(q, vec3(size));
    return obj1;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float t = iTime;
    vec2 screenPos = -1.0 + 2.0 * fragCoord.xy / iResolution.xy;
    screenPos.x *= iResolution.x / iResolution.y;
    vec3 cameraOrigin = vec3(t*1.0*speed, 0.0, 0.0);
    // vec3 cameraOrigin = vec3(t*1.8*speed, 3.0+t*0.02*speed, 0.0);
    vec3 cameraTarget = vec3(t*100., 0.0, 0.0);
    cameraTarget = vec3(t*20.0,0.0,0.0) * rotationMatrix(vec3(0.0,0.0,1.0), t*speed*camera_rotation_speed);

    vec3 upDirection = vec3(0.5, 1.0, 0.6);

    vec3 cameraDir = normalize(cameraTarget - cameraOrigin);
    vec3 cameraRight = normalize(cross(upDirection, cameraOrigin));
    vec3 cameraUp = cross(cameraDir, cameraRight);

    vec3 rayDir = normalize(cameraRight * screenPos.x + cameraUp * screenPos.y + cameraDir);

    const int MAX_ITER = 64;
    const float MAX_DIST = 48.0;
    const float EPSILON = 0.001;

    float totalDist = 0.0;
    vec3 pos = cameraOrigin;
    float dist = EPSILON;

    for (int i = 0; i < MAX_ITER; i++)
    {
        if (dist < EPSILON || totalDist > MAX_DIST)
            break;
        dist = distfunc(pos);
        totalDist += dist;
        pos += dist*rayDir;
    }

    float cubeMask = 0.0;

    if (dist < EPSILON)
    {
        vec2 eps = vec2(0.0, EPSILON);
        vec3 normal = normalize(vec3(
            distfunc(pos + eps.yxx) - distfunc(pos - eps.yxx),
            distfunc(pos + eps.xyx) - distfunc(pos - eps.xyx),
            distfunc(pos + eps.xxy) - distfunc(pos - eps.xxy)));
        float diffuse = max(0.0, dot(-rayDir, normal));
        float specular = pow(diffuse, 32.0);
        float surfaceLight = clamp(
            diffuse + CUBE_SPECULAR_WEIGHT * specular,
            0.0,
            1.0
        );
        float distanceFade = 1.0 - clamp(totalDist / MAX_DIST, 0.0, 1.0);
        cubeMask = surfaceLight * distanceFade;
    }

    vec2 uv = fragCoord/iResolution.xy;
    vec4 terminalColor = texture(iChannel0, uv);

    float backgroundDistance = distance(terminalColor.rgb, iBackgroundColor);
    float backgroundMask = 1.0 - smoothstep(
        BACKGROUND_EDGE_START,
        BACKGROUND_EDGE_END,
        backgroundDistance
    );

    float opacity = cubeMask * cube_opacity;
    vec3 cubeLayer = mix(terminalColor.rgb, CUBE_INK, opacity);
    vec3 blendedColor = mix(terminalColor.rgb, cubeLayer, backgroundMask);
    fragColor = vec4(blendedColor, terminalColor.a);
}
