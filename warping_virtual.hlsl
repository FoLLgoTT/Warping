static const float distortionFactorX = 0.0; 		// higher = more curved distortion
static const float distortionFactorY = 0.0; 		// higher = more curved distortion
static const float distortionCenterX = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionCenterY = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionBowY = 1.0;			// 1 = none. >1 bow to bottom. <1 bow to top

static const float trapezTop = 1.0;				// trapezoid distortion factor for the top of the picture
static const float trapezBottom = 1.0;			// trapezoid distortion factor for the bottom of the picture

static const float linearityCorrectionX = 1.0;	// corrects horizontal linearity for anamorphic lens
static const float linearityCorrectionY = 1.0;	// corrects vertical linearity for anamorphic lens

#define widthNative 	3840 // set native x resolution here
#define heightNative 	2160 // set native y resolution here

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
	for(int x = -2; x <= 2; x++)
	{
		for(int y = -2; y <= 2; y++)
		{        
			float wx = BicubicWeight(float(x) - offset.x);
			float wy = BicubicWeight(float(y) - offset.y);
			float w = wx * wy;
			float2 coord = center + float2(x, y) * InvResolution;
			
			if(coord.x >= 0.0 && coord.x <= 1.0 && coord.y >= 0.0 && coord.y <= 1.0) // ignore pixels outside the picture
				col += w * tex2D(samp, coord).rgb;
				
			weight += w;
		}
	}
	col /= weight;
	
	return col;
}

float ConvertToVirtual(float f)
{
	return width / widthNative * f + (widthNative - width) / widthNative / 2;
}

float ConvertToNative(float f)
{
	return (f - (widthNative - width) / widthNative / 2) / width * widthNative;
}

float4 main(float2 uv : TEXCOORD0) : COLOR
{
	// scale to virtual resolution
	float xVirtual = ConvertToVirtual(uv.x);
	float yVirtual = ConvertToVirtual(uv.y);
	
	// perform distortion for curved screen (follows a parabola)
	uv.x += distortionFactorX * (-2.0 * xVirtual + distortionCenterX) * yVirtual * (yVirtual - 1.0);	
	uv.y += distortionFactorY * (-2.0 * pow(yVirtual, distortionBowY) + distortionCenterY) * xVirtual * (xVirtual - 1.0);
	
	// trapezoid
	if(trapezTop != 1.0 || trapezBottom != 1.0)
	{
		float size = lerp(ConvertToNative(trapezTop), ConvertToNative(trapezBottom), yVirtual);
		float reciprocal = 1.0 / size;
		float xTrapez = xVirtual * reciprocal + (1.0 - reciprocal) / 2.0;
		uv.x = ConvertToNative(xTrapez);
	}
	
	// linearity
	if(linearityCorrectionX != 1.0)
	{
		float x = xVirtual - 0.5;
		uv.x = ConvertToNative(lerp(x * abs(x) * 2.000001, x, ConvertToVirtual(linearityCorrectionX)) + 0.5);
	}
	if(linearityCorrectionY != 1.0)
	{
		float y = yVirtual - 0.5;
		uv.y = ConvertToNative(lerp(y * abs(y) * 2.00001, y, ConvertToVirtual(linearityCorrectionY)) + 0.5);
	}

	float3 result = Bicubic(uv, 1.0 / float2(width, height));
	
	return float4(result, 1.0);
}