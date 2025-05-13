
#include "ReShade.fxh"

//Macros//////////////////////////////////////////////////////////////////////////////////

#ifndef DITHER_NOQUANTIZATION
#define DITHER_NOQUANTIZATION 0
#endif

//Uniforms////////////////////////////////////////////////////////////////////////////////

uniform float fDithering <
    ui_label = "Dithering";
    ui_type  = "drag";
    ui_min   = 0.0;
    ui_max   = 1.0;
    ui_step  = 0.001;
> = 0.5;
#if !DITHER_NOQUANTIZATION
uniform float fQuantization <
    ui_label   = "Quantization";
    ui_tooltip = "Use to simulate lack of colors: 8.0 for 8bits, 16.0 for 16bits etc.\n"
                 "Set to 0.0 to disable quantization.\n"
                 "Only enabled if dithering is enabled as well.";
    ui_type    = "drag";
    ui_min     = 0.0;
    ui_max     = 255.0;
    ui_step    = 1.0;
> = 0.0;
#endif

uniform int iDitherMode <
    ui_label = "Dither Mode";
    ui_type  = "combo";
    ui_items = "Add\0Multiply\0";
> = 0;

uniform int iMatrixSize <
    ui_label = "Dither Matrix";
    ui_type = "combo";
    ui_items = "4\08\0";
> = 0;
//Textures////////////////////////////////////////////////////////////////////////////////

sampler2D sRetroFog_BackBuffer {
    Texture = ReShade::BackBufferTex;
    SRGBTexture = true;
};

//Functions///////////////////////////////////////////////////////////////////////////////

// Source: https://en.wikipedia.org/wiki/Ordered_dithering
int get_void_and_cluster(int size, int2 i) {
    static const int void_and_cluster8[8 * 8] = {
        47, 10, 16, 56, 29, 59, 44, 3, 
        8, 14, 17, 23, 32, 35, 57, 6, 
        5, 50, 60, 63, 27, 24, 0, 43, 
        58, 15,61, 33, 31, 20, 18, 22, 
        48, 42, 46, 11, 45, 2, 37, 21, 
        12, 40, 13, 4, 26, 55, 9, 38, 
        1, 39, 7, 62, 41, 25, 53, 19, 
        28, 54, 51, 36, 49, 52, 30, 34
    };
    if (size == 8) return void_and_cluster8[i.x + 8 * i.y];
    static const int void_and_cluster4[4*4] = {
        2, 5, 13, 9, 8, 14, 1, 0, 3, 12, 11, 7, 4, 15, 10, 6
    };
    return void_and_cluster4[i.x+4*i.y];
    
}

//#define fmod(a, b) ((frac(abs(a / b)) * abs(b)) * ((step(a, 0) - 0.5) * 2.0))
float2 fmod(float2 a, float2 b) {
    float2 c = frac(abs(a / b)) * abs(b);
    return (a < 0) ? -c : c;
}

// Adapted from: http://devlog-martinsh.blogspot.com.br/2011/03/glsl-dithering.html
float dither(float x, float2 uv) {
    float limit;
    #if (__RENDERER__ & 0x10000) // If OpenGL
    if (iMatrixSize == 0){
        float2 index = fmod(uv * ReShade::ScreenSize, 4.0);
        limit  = (float(get_void_and_cluster(4,int2(index)) + 1) / 16.0) * step(index.x, 4.0);
    }
    else {
        float2 index = fmod(uv * ReShade::ScreenSize, 8.0);
        limit  = (float(get_void_and_cluster(8,int2(index)) + 1) / 64.0) * step(index.x, 8.0);
    }
    
    #else // DirectX
    if (iMatrixSize == 0){
        int2 index = int2(uv * ReShade::ScreenSize) % 4;
        limit  = (float(get_void_and_cluster(4,int2(index)) + 1) / 16.0) * step(index.x, 4.0);
    }
    else {
        int2 index = int2(uv * ReShade::ScreenSize) % 8;
        limit  = (float(get_void_and_cluster(8,int2(index)) + 1) / 64.0) * step(index.x, 8.0);
    }
    #endif
    return step(limit, x);
}

float get_luma_linear(float3 color) {
    // luma coefficient
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float rand(float2 uv, float t) {
    float seed = dot(uv, float2(12.9898, 78.233));
    float noise = frac(sin(seed) * 43758.5453 + t);
    return noise;
}

//Shaders/////////////////////////////////////////////////////////////////////////////////

void PS_Dither(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    color = tex2D(sRetroFog_BackBuffer, uv);

    if (fQuantization > 0.0)
        color = round(color * fQuantization) / fQuantization;

    float luma = get_luma_linear(color.rgb);
    float pattern = dither(luma, uv);
    
    if (iDitherMode == 0) // Add
        color.rgb += color.rgb * pattern * fDithering;
    else                  // Multiply
        color.rgb *= lerp(1.0, pattern, fDithering);
}

//Technique///////////////////////////////////////////////////////////////////////////////

technique DitherVC {
    pass {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Dither;
        SRGBWriteEnable = true;
    }
}
