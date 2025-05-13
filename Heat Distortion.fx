#include "ReShade.fxh"

uniform float timer < source = "timer"; >;

uniform float DistortionStrength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 50.0;
    ui_label = "Distortion Strength";
    ui_tooltip = "Controls how strong the heat distortion effect is";
> = 10.0;

uniform float DistortionSpeed <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Distortion Speed";
    ui_tooltip = "Controls how fast the heat waves move";
> = 2.0;

uniform float DistortionScale <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 50.0;
    ui_label = "Distortion Scale";
    ui_tooltip = "Controls the size of the heat waves";
> = 15.0;

uniform float3 HeatColor <
    ui_type = "color";
    ui_label = "Heat Color";
    ui_tooltip = "Color tint for the heat effect";
> = float3(1.0, 0.5, 0.0);

uniform float ColorIntensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Color Intensity";
    ui_tooltip = "How strong the color tint is";
> = 0.2;

uniform bool UseGradient <
    ui_label = "Use Vertical Gradient";
    ui_tooltip = "Makes the effect stronger at the bottom of the screen";
> = true;

// Hash function for the noise
float3 hash33(float3 p) {
    p = float3(dot(p, float3(127.1, 311.7, 74.7)),
               dot(p, float3(269.5, 183.3, 246.1)),
               dot(p, float3(113.5, 271.9, 124.6)));
    
    return frac(sin(p) * 43758.5453123);
}

// Noise function for creating the heat wave pattern
float noise(float2 p) {
    float2 ip = floor(p);
    float2 u = frac(p);
    u = u * u * (3.0 - 2.0 * u);
    
    float res = lerp(
        lerp(dot(hash33(float3(ip, 1.0)).xy, u - float2(0.0, 0.0)),
             dot(hash33(float3(ip + float2(1.0, 0.0), 1.0)).xy, u - float2(1.0, 0.0)), u.x),
        lerp(dot(hash33(float3(ip + float2(0.0, 1.0), 1.0)).xy, u - float2(0.0, 1.0)),
             dot(hash33(float3(ip + float2(1.0, 1.0), 1.0)).xy, u - float2(1.0, 1.0)), u.x), u.y);
    return res * 0.5 + 0.5;
}

float fbm(float2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 5; i++) {
        f += w * noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

float4 HeatDistortionPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float time = timer * 0.001 * DistortionSpeed;
    
    float distortionAmount = DistortionStrength * 0.01;
    
    if (UseGradient) {
        distortionAmount *= 1.0 - texcoord.y;
    }
    
    float2 offset = float2(
        fbm(texcoord * DistortionScale + float2(0.0, time)),
        fbm(texcoord * DistortionScale + float2(time, 0.0))
    );

    float2 distortedCoord = texcoord + (offset - 0.5) * distortionAmount;

    float4 color = tex2D(ReShade::BackBuffer, distortedCoord);

    float distortionMask = length(offset - 0.5) * 2.0;
    color.rgb = lerp(color.rgb, color.rgb * HeatColor, distortionMask * ColorIntensity);
    
    return color;
}

technique HeatDistortion {
    pass {
        VertexShader = PostProcessVS;
        PixelShader = HeatDistortionPS;
    }
}
