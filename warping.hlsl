static const float distortionFactorX = 0.0; 		// higher = more curved distortion
static const float distortionFactorY = 0.0; 		// higher = more curved distortion
static const float distortionCenterX = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionCenterY = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
static const float distortionBowY = 1.0;		// 1 = none. >1 bow to bottom. <1 bow to top

static const float trapezTop = 1.0;			// trapezoid distortion factor for the top of the picture
static const float trapezBottom = 1.0;			// trapezoid distortion factor for the bottom of the picture

static const float linearityCorrectionX = 1.0;		// corrects horizontal linearity for anamorphic lens
static const float linearityCorrectionY = 1.0;		// corrects vertical linearity for anamorphic lens



SamplerState samp : register(s0);

float4 p0 :  register(c0);
#define width  (p0[0])
#define height (p0[1])


float3 Bicubic_fast(in float2 uv, in float2 InvResolution)
{
	if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) // ignore pixels outside the picture
		return float3(0, 0, 0);

	// the following code is adapted from here: https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1
	// We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
	// down the sample location to get the exact center of our "starting" texel. The starting texel will be at
	// location [1, 1] in the grid, where [0, 0] is the top left corner.
	float2 samplePos = uv / InvResolution;
	float2 texPos1 = floor(samplePos - 0.5) + 0.5;

	// Compute the fractional offset from our starting texel to our original sample location, which we'll
	// feed into the Catmull-Rom spline function to get our filter weights.
	float2 f = samplePos - texPos1;

	// Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
	// These equations are pre-expanded based on our knowledge of where the texels will be located,
	// which lets us avoid having to evaluate a piece-wise function.
	float2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
	float2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
	float2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
	float2 w3 = f * f * (-0.5 + 0.5 * f);

	// Work out weighting factors and sampling offsets that will let us use bilinear filtering to
	// simultaneously evaluate the middle 2 samples from the 4x4 grid.
	float2 w12 = w1 + w2;
	float2 offset12 = w2 / (w1 + w2);

	// Compute the final UV coordinates we'll use for sampling the texture
	float2 texPos0 = texPos1 - 1;
	float2 texPos3 = texPos1 + 2;
	float2 texPos12 = texPos1 + offset12;

	texPos0 *= InvResolution;
	texPos3 *= InvResolution;
	texPos12 *= InvResolution;

	float4 result = float4(0, 0, 0, 0);
	result += tex2D(samp, float2(texPos0.x, texPos0.y)) * w0.x * w0.y;
	result += tex2D(samp, float2(texPos12.x, texPos0.y)) * w12.x * w0.y;
	result += tex2D(samp, float2(texPos3.x, texPos0.y)) * w3.x * w0.y;

	result += tex2D(samp, float2(texPos0.x, texPos12.y)) * w0.x * w12.y;
	result += tex2D(samp, float2(texPos12.x, texPos12.y)) * w12.x * w12.y;
	result += tex2D(samp, float2(texPos3.x, texPos12.y)) * w3.x * w12.y;

	result += tex2D(samp, float2(texPos0.x, texPos3.y)) * w0.x * w3.y;
	result += tex2D(samp, float2(texPos12.x, texPos3.y)) * w12.x * w3.y;
	result += tex2D(samp, float2(texPos3.x, texPos3.y)) * w3.x * w3.y;

	return result.rgb;
}

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

float4 main(float2 uv : TEXCOORD0) : COLOR
{
	// perform distortion for curved screen (follows a parabola)
	uv.x += distortionFactorX * (-2.0 * uv.x + distortionCenterX) * uv.y * (uv.y - 1.0);	
	uv.y += distortionFactorY * (-2.0 * pow(uv.y, distortionBowY) + distortionCenterY) * uv.x * (uv.x - 1.0);
	
	// trapezoid
	float size = lerp(trapezTop, trapezBottom, uv.y);
    	float reciprocal = 1.0 / size;
    	uv.x = uv.x * reciprocal + (1.0 - reciprocal) / 2.0;
	
	// linearity
	if(linearityCorrectionX != 1.0)
	{
		float x = uv.x - 0.5;
		uv.x = lerp(x * abs(x) * 2.000001, x, linearityCorrectionX) + 0.5;
	}
	if(linearityCorrectionY != 1.0)
	{
		float y = uv.y - 0.5;
		uv.y = lerp(y * abs(y) * 2.00001, uv.y - 0.5, linearityCorrectionY) + 0.5;
	}

	float3 result = Bicubic_fast(uv, 1.0 / float2(width, height));
	
	return float4(result, 1.0);
}
