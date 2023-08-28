static const float widthNative = 3840; 		// set native x resolution here
static const float heightNative = 2160; 	// set native y resolution here

static const float distortionFactorX = 0.0; 	// higher = more curved distortion
static const float distortionFactorY = 0.0; 	// higher = more curved distortion
static const float distortionCenterX = 1.0; 	// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionCenterY = 1.0; 	// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionBowY = 1.0;	// 1 = none. >1 bow to bottom. <1 bow to top

static const float trapezTop = 1.0;		// trapezoid distortion factor for the top of the picture (use values < 1.0 to avoid cutting the edges)
static const float trapezBottom = 1.0;		// trapezoid distortion factor for the bottom of the picture (use values < 1.0 to avoid cutting the edges)

static const float linearityCorrectionX = 1.0;	// corrects horizontal linearity for anamorphic lens
static const float linearityCorrectionY = 1.0;	// corrects vertical linearity for anamorphic lens


SamplerState samp : register(s0);

float4 p0 :  register(c0);
#define width  (p0[0])
#define height (p0[1])

float BicubicWeight(float d)
{
	d = abs(d); 
	
	if(2.0 < d){
		return 0.0;
	}
	
	const float a = -1.0;
	float d2 = d * d;
	float d3 = d * d * d;
	
	if(1.0 < d){
		return a * d3 - 5.0 * a * d2 + 8.0 * a * d - 4.0 * a;
	}
	
	return (a + 2.0) * d3 - (a+3.0) * d2 + 1.0;
}

float3 Bicubic(float2 uv, float2 InvResolution)
{
	float2 center = uv - (fmod(uv / InvResolution, 1.0) - 0.5) * InvResolution; // texel center
	float2 offset = (uv - center) / InvResolution; // relevant texel position in the range -0.5～+0.5
	float3 col = float3(0,0,0);
	float weight = 0.0;
	float borderX1 = max((width - widthNative) / width / 2.0, 0.0);
	float borderX2 = 1.0 - borderX1;
	float borderY1 = max((height - heightNative) / height / 2.0, 0.0);
	float borderY2 = 1.0 - borderY1;
	
	for(int x = -2; x <= 2; x++)
	{
		for(int y = -2; y <= 2; y++)
		{        
			float wx = BicubicWeight(float(x) - offset.x);
			float wy = BicubicWeight(float(y) - offset.y);
			float w = wx * wy;
			float2 coord = center + float2(x, y) * InvResolution;
			
			if(coord.x >= borderX1 && coord.x <= borderX2 && coord.y >= borderY1 && coord.y <= borderY2) // ignore pixels outside the picture
				col += w * tex2D(samp, coord).rgb;
				
			weight += w;
		}
	}
	col /= weight;
	
	return col;
}

float4 main(float2 uv : TEXCOORD0) : COLOR
{
	float zoom = width / widthNative;
	float xZoomed = (uv.x - 0.5) * zoom + 0.5;
	float yZoomed = (uv.y - 0.5) * zoom + 0.5;
		
	// perform distortion for curved screen (follows a parabola)
	uv.x += distortionFactorX * (-2.0 * xZoomed + distortionCenterX) * yZoomed * (yZoomed - 1.0);	
	uv.y += distortionFactorY * (-2.0 * pow(yZoomed, distortionBowY) + distortionCenterY) * xZoomed * (xZoomed - 1.0);

	// correct size if barrel distortion is requested to avoid cutting the edges
	if(distortionFactorX < 0)
	{
		float xZenithZoomed = 0.5 * zoom + 0.5;
		float correction = 1.0 - 0.5 * distortionFactorX * (-2.0 * xZenithZoomed + distortionCenterX); // zenith of parabola
		uv.x = (uv.x - 0.5) / correction + 0.5;
	}
	if(distortionFactorY < 0)
	{
		float yZenithZoomed = 0.5 * zoom + 0.5;
		float correction = 1.0 - 0.5 * distortionFactorY * (-2.0 * pow(yZenithZoomed, distortionBowY) + distortionCenterY); // zenith of parabola
		uv.y = (uv.y - 0.5) / correction + 0.5;
	}

	// trapezoid
	if(trapezTop != 1.0 || trapezBottom != 1.0)
	{
		float size = lerp(trapezTop, trapezBottom, yZoomed);
		float reciprocal = 1.0 / size;
		uv.x = uv.x * reciprocal + (1.0 - reciprocal) / 2.0;
	}
	
	// linearity
	if(linearityCorrectionX != 1.0)
	{
		float x = xZoomed - 0.5;
		uv.x = lerp(x * abs(x) * 2.000001, uv.x - 0.5, linearityCorrectionX) + 0.5;
	}
	if(linearityCorrectionY != 1.0)
	{
		float y = yZoomed - 0.5;
		uv.y = lerp(y * abs(y) * 2.00001, uv.y - 0.5, linearityCorrectionY) + 0.5;
	}

	float3 result = Bicubic(uv, 1.0 / float2(width, height));
	
	return float4(result, 1.0);
}
