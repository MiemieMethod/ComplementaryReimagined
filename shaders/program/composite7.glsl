/////////////////////////////////////
// Complementary Shaders by EminGT //
/////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

noperspective in vec2 texCoord;

//Pipeline Constants//

//Common Variables//

//Common Functions//
float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#if FXAA_DEFINE == 1 && FXAA_STRENGTH > 1
    #include "/lib/antialiasing/fxaa.glsl"
#endif

// VOXY-FIX: self-contained lightweight FXAA applied ONLY to LoD-terrain pixels.
// LoD uses low TAA history blend (to kill reprojection trails on Iris 1.6.11), which leaves
// aliasing/noise. This current-frame spatial AA cleans those edges without touching near terrain
// and without relying on history (so it adds no ghosting). Independent of the global FXAA setting.
#ifdef VOXY
float vfxLuma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void VoxyLodFXAA(inout vec3 color) {
    vec2 view = 1.0 / vec2(viewWidth, viewHeight);
    float lC = vfxLuma(color);
    float lU = vfxLuma(texture2D(colortex3, texCoord + vec2(0.0,  view.y)).rgb);
    float lD = vfxLuma(texture2D(colortex3, texCoord + vec2(0.0, -view.y)).rgb);
    float lL = vfxLuma(texture2D(colortex3, texCoord + vec2(-view.x, 0.0)).rgb);
    float lR = vfxLuma(texture2D(colortex3, texCoord + vec2( view.x, 0.0)).rgb);
    float lMin = min(lC, min(min(lU, lD), min(lL, lR)));
    float lMax = max(lC, max(max(lU, lD), max(lL, lR)));
    float range = lMax - lMin;
    if (range < 0.04) return; // flat area, skip
    // edge direction (sobel-ish), blend along the edge
    vec2 dir = vec2(-((lU + lD) - 2.0 * lC), ((lL + lR) - 2.0 * lC));
    float dirReduce = max((lU + lD + lL + lR) * 0.03125, 0.0078125);
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = clamp(dir * rcpDirMin, -8.0, 8.0) * view;
    vec3 rgbA = 0.5 * (
        texture2D(colortex3, texCoord + dir * (1.0/3.0 - 0.5)).rgb +
        texture2D(colortex3, texCoord + dir * (2.0/3.0 - 0.5)).rgb);
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture2D(colortex3, texCoord + dir * -0.5).rgb +
        texture2D(colortex3, texCoord + dir *  0.5).rgb);
    float lB = vfxLuma(rgbB);
    color = (lB < lMin || lB > lMax) ? rgbA : rgbB;
}
#endif

//Program//
void main() {
    vec3 color = texelFetch(colortex3, texelCoord, 0).rgb;
        
    #if FXAA_DEFINE == 1 && FXAA_STRENGTH > 1
        FXAA311(color);
    #endif

    // VOXY-FIX: extra spatial AA on LoD-terrain pixels (where vanilla depth is far but Voxy LoD is near)
    #ifdef VOXY
    {
        float dbgZ0 = texelFetch(depthtex0, texelCoord, 0).r;
        float vxd = texture2D(vxDepthTexOpaque, texCoord).r;
        if (dbgZ0 >= 1.0 && vxd < 1.0) {
            VoxyLodFXAA(color);
        }
    }
    #endif

    /* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(color, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

noperspective out vec2 texCoord;

//Attributes//

//Common Variables//

//Common Functions//

//Includes//

//Program//
void main() {
    gl_Position = ftransform();

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
