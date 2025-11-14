#include "ReShade.fxh"

//-------------------------------------
// User parameters (all editable in UI)
//-------------------------------------
uniform float distortionFactorX 
< 
ui_category = "Bow distortion";
ui_label = "Horizontal";
ui_tooltip = "Higher = more curved distortion";
ui_step = 0.02; 
ui_min = 0; 
ui_max = 1; 
ui_type = "slider";
> = 0.0;

uniform float distortionFactorY 
<
ui_category = "Bow distortion";
ui_label = "Vertical";
ui_tooltip = "Higher = more curved distortion";
ui_step = 0.02; 
ui_min = 0; 
ui_max = 1;
ui_type = "slider";
> = 0.0;

uniform float distortionCenterX 
<
ui_category = "Bow distortion";
ui_label = "Center horizontal";
ui_tooltip = "1 = symmetrical to y. 0 = only bottom. 2 = only top";
ui_step = 0.02; 
ui_min = 0; 
ui_max = 2; 
ui_type = "slider";
> = 1.0;

uniform float distortionCenterY 
<
ui_category = "Bow distortion";
ui_label = "Center vertical";
ui_tooltip = "1 = symmetrical to y. 0 = only bottom. 2 = only top";
ui_step = 0.02;
ui_min = 0; 
ui_max = 2; 
ui_type = "slider";
> = 1.0;

uniform float distortionBowY
<
ui_category = "Bow distortion";
ui_label = "Bow vertical";
ui_tooltip = "1 = none. >1 bow to bottom. <1 bow to top";
ui_step = 0.02; 
ui_min = 0.5; 
ui_max = 2; 
ui_type = "slider";
> = 1.0;

uniform float trapezTop    
<
ui_category = "Trapezoid";
ui_label = "Top";
ui_tooltip = "Trapezoid distortion factor for the top of the picture (use values < 1.0 to avoid cutting the edges)";
ui_step = 0.02; 
ui_min = 0; 
ui_max = 2;
ui_type = "slider";
> = 1.0;

uniform float trapezBottom
<
ui_category = "Trapezoid";
ui_label = "Bottom";
ui_tooltip = "Trapezoid distortion factor for the bottom of the picture (use values < 1.0 to avoid cutting the edges)";
ui_step = 0.02;
ui_min = 0; 
ui_max = 2;
ui_type = "slider";
 > = 1.0;

uniform float linearityCorrectionX 
<
ui_category = "Linearity";
ui_label = "Horizontal";
ui_tooltip = "Corrects horizontal linearity for anamorphic lens";
ui_step = 0.02;
ui_min = 0.5;
ui_max = 2;
ui_type = "slider";
> = 1.0;

uniform float linearityCorrectionY
<
ui_category = "Linearity";
ui_label = "Vertical";
ui_tooltip = "Corrects horizontal linearity for anamorphic lens";
ui_step = 0.02;
ui_min = 0.5;
ui_max = 2;
ui_type = "slider";
> = 1.0;


#define fmod(x,y)(x-y*trunc(x/y))

//-------------------------------------
// Bicubic filter
//-------------------------------------
float BicubicWeight(float d)
{
    d = abs(d);

    if (d > 2.0)
        return 0.0;

    const float a = -1.0;
    float d2 = d * d;
    float d3 = d2 * d;

    if (d > 1.0)
        return a * d3 - 5.0 * a * d2 + 8.0 * a * d - 4.0 * a;

    return (a + 2.0) * d3 - (a + 3.0) * d2 + 1.0;
}

float3 Bicubic(float2 uv)
{
    float2 InvRes = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    float2 center = uv - (fmod(uv / InvRes, 1.0) - 0.5) * InvRes;
    float2 offset = (uv - center) / InvRes;

    float3 col = float3(0,0,0);
    float weight = 0.0;

    float borderX1 = max((BUFFER_WIDTH - BUFFER_WIDTH) / BUFFER_WIDTH / 2.0, 0.0);
    float borderX2 = 1.0 - borderX1;
    float borderY1 = max((BUFFER_HEIGHT - BUFFER_WIDTH) / BUFFER_HEIGHT / 2.0, 0.0);
    float borderY2 = 1.0 - borderY1;

    for (int x = -2; x <= 2; x++)
    {
        for (int y = -2; y <= 2; y++)
        {
            float wx = BicubicWeight(float(x) - offset.x);
            float wy = BicubicWeight(float(y) - offset.y);
            float w = wx * wy;

            float2 coord = center + float2(x, y) * InvRes;

            if (coord.x >= borderX1 && coord.x <= borderX2 &&
                coord.y >= borderY1 && coord.y <= borderY2)
            {
                col += w * tex2D(ReShade::BackBuffer, coord).rgb;
            }

            weight += w;
        }
    }

    return col / weight;
}

//-------------------------------------
// Main pass
//-------------------------------------
float4 PS_Warping(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
    float zoom = BUFFER_WIDTH / BUFFER_WIDTH;

    float xZoomed = (uv.x - 0.5) * zoom + 0.5;
    float yZoomed = (uv.y - 0.5) * zoom + 0.5;

    // Curved distortion
    uv.x += distortionFactorX * (-2.0 * xZoomed + distortionCenterX) * yZoomed * (yZoomed - 1.0);
    uv.y += distortionFactorY * (-2.0 * pow(yZoomed, distortionBowY) + distortionCenterY) * xZoomed * (xZoomed - 1.0);

    // Barrel correction
    if (distortionFactorX < 0)
    {
        float xZ = 0.5 * zoom + 0.5;
        float corr = 1.0 - 0.5 * distortionFactorX * (-2.0 * xZ + distortionCenterX);
        uv.x = (uv.x - 0.5) / corr + 0.5;
    }

    if (distortionFactorY < 0)
    {
        float yZ = 0.5 * zoom + 0.5;
        float corr = 1.0 - 0.5 * distortionFactorY * (-2.0 * pow(yZ, distortionBowY) + distortionCenterY);
        uv.y = (uv.y - 0.5) / corr + 0.5;
    }

    // Trapezoid
    if (trapezTop != 1.0 || trapezBottom != 1.0)
    {
        float size = lerp(trapezTop, trapezBottom, yZoomed);
        float reciprocal = 1.0 / size;
        uv.x = uv.x * reciprocal + (1.0 - reciprocal) / 2.0;
    }

    // Linearity
    if (linearityCorrectionX != 1.0)
    {
        float x = xZoomed - 0.5;
        uv.x = lerp(x * abs(x) * 2.000001, uv.x - 0.5, linearityCorrectionX) + 0.5;
    }

    if (linearityCorrectionY != 1.0)
    {
        float y = yZoomed - 0.5;
        uv.y = lerp(y * abs(y) * 2.00001, uv.y - 0.5, linearityCorrectionY) + 0.5;
    }

    float3 result = Bicubic(uv);
    return float4(result, 1.0);
}

//-------------------------------------
// Technique
//-------------------------------------
technique Warping
{
    pass
    {
		VertexShader = PostProcessVS;
        PixelShader = PS_Warping;
    }
}
