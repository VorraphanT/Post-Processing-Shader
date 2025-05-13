#include "ReShade.fxh"


//Uniforms////////////////////////////////////////////////////////////////////////////////
uniform float fFarPlane <
    ui_label = "Farplane";
    ui_type  = "drag";
    ui_min   = 0;
    ui_max   = 1500;
    ui_step  = 10;
> = 1000;
uniform float fRadius <
    ui_label = "Radius";
    ui_type  = "drag";
    ui_min   = 0.1;
    ui_max   = 10.0;
    ui_step  = 0.1;
> = 1.0;
uniform float fOccDivisor <
    ui_label = "occ divisor";
    ui_type  = "drag";
    ui_min   = 8;
    ui_max   = 20;
    ui_step  = 1;
> = 8;
uniform float fBias <
    ui_label = "Bias for checking depth /10000";
    ui_type  = "drag";
    ui_min   = 0.0;
    ui_max   = 10.0;
    ui_step  = 0.1;
> = 1;


//Textures////////////////////////////////////////////////////////////////////////////////


sampler2D sRetroFog_BackBuffer {
    Texture = ReShade::BackBufferTex;
    SRGBTexture = true;
};

//Functions///////////////////////////////////////////////////////////////////////////////
float GetLinearizedDepth(float2 texcoord)
{
    float depth = tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;
    const float C = 0.01;
    depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
    const float N = 1.0;
    depth /= fFarPlane - depth * (fFarPlane - N);

    return depth;
    
}

float calculate_ambient(float2 uv) {
    float linearized_depth = GetLinearizedDepth(uv);
    if (linearized_depth >= fFarPlane) 
        return 0.0;
    float occ = 0.0;
    float radius = fRadius/ ReShade::ScreenSize.x;
    float dx[8] = {-1.0,1.0,0.0,0.0, 0.707, -0.707, 0.707,-0.707};
    float dy[8] = {0.0,0.0,-1.0,1.0, 0.707, -0.707 ,-0.707, 0.707};
    [loop]
    for (int i = 0; i<8; i++){
        float2 k = uv + float2(dx[i]*radius, dy[i]*radius);
        float d_sampled = GetLinearizedDepth(k);
        if (d_sampled < linearized_depth - fBias/10000) // the sampled pixel is blocking the light source
            occ += 1.0;
    }
    return 1-occ/fOccDivisor;
}

//Shaders/////////////////////////////////////////////////////////////////////////////////

void PS_AmbientOcclusion(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    color = tex2D(sRetroFog_BackBuffer, uv);
    float ao = calculate_ambient(uv);
    color.rgb *= ao;
}

//Technique///////////////////////////////////////////////////////////////////////////////

technique Ambient_Occlusion {
    pass {
        VertexShader = PostProcessVS;
        PixelShader  = PS_AmbientOcclusion;
        SRGBWriteEnable = true;
    }
}
