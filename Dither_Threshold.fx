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

// uniform int iDitherMode <
//     ui_label = "Dither Mode";
//     ui_type  = "combo";
//     ui_items = "Add\0Multiply\0";
// > = 0;

uniform float fThreshold <
    ui_label = "Threshold";
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

//Textures////////////////////////////////////////////////////////////////////////////////

sampler2D sRetroFog_BackBuffer {
    Texture = ReShade::BackBufferTex;
    SRGBTexture = true;
};

//Functions///////////////////////////////////////////////////////////////////////////////

float get_luma_linear(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float dither(float x, float2 uv) {
    return step(fThreshold, x);
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
    color.rgb = color.rgb*pattern;
}

//Technique///////////////////////////////////////////////////////////////////////////////

technique DitherThreshold {
    pass {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Dither;
        SRGBWriteEnable = true;
    }
}
