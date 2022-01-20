//!DESC Warping
//!HOOK POSTKERNEL   
//!BIND HOOKED
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h

float outputResolution = 3840.0;

float distortionFactorX = 0.0; 		// higher = more curved distortion
float distortionFactorY = 0.0; 		// higher = more curved distortion
float distortionCenterX = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
float distortionCenterY = 1.0; 		// 1 = symmetrical to y. 0 = only bottom. 2 = only top.
float distortionBowY = 1.0;		// 1 = none. >1 bow to bottom. <1 bow to top

float trapezTop = 1.0;			// trapezoid distortion factor for the top of the picture
float trapezBottom = 1.0;		// trapezoid distortion factor for the bottom of the picture

float linearityCorrectionX = 1.0;	// corrects horizontal linearity for anamorphic lens
float linearityCorrectionY = 1.0;	// corrects vertical linearity for anamorphic lens


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

vec3 Bicubic(vec2 uv, vec2 InvResolution)
{
    vec2 center = uv - (mod(uv / InvResolution, 1.0) - 0.5) * InvResolution; // texel center
    vec2 offset = (uv - center) / InvResolution; // relevant texel position in the range -0.5～+0.5
    
    vec3 col = vec3(0,0,0);
    float weight = 0.0;
    for(int x = -2; x <= 2; x++)
	{
		for(int y = -2; y <= 2; y++)
		{        
			float wx = BicubicWeight(float(x) - offset.x);
			float wy = BicubicWeight(float(y) - offset.y);
			float w = wx * wy;
			vec2 coord = center + vec2(x, y) * InvResolution;
			
			if(coord.x >= 0.0 && coord.x <= 1.0 && coord.y >= 0.0 && coord.y <= 1.0) // ignore pixels outside the picture
				col += w * HOOKED_tex(coord).rgb;
			weight += w;
		}
    }
    col /= weight;
    
    return col;
}

vec4 hook() 
{
	vec2 uv = HOOKED_pos;
	
	float zoom = outputResolution / target_size.x;
	float xZoomed = (uv.x - 0.5) / zoom + 0.5;
	float yZoomed = (uv.y - 0.5) / zoom + 0.5;

	// perform distortion for curved screen (follows a parabola)
	uv.x += distortionFactorX * (-2.0 * uv.x + distortionCenterX) * yZoomed * (yZoomed - 1.0);	
	uv.y += distortionFactorY * (-2.0 * pow(uv.y, distortionBowY) + distortionCenterY) * xZoomed * (xZoomed - 1.0);
	
	// trapezoid
	float size = mix(trapezTop, trapezBottom, yZoomed);
    	float reciprocal = 1.0 / size;
    	uv.x = uv.x * reciprocal + (1.0 - reciprocal) / 2.0;
	
	// linearity
	if(linearityCorrectionX != 1.0)
	{
		float x = xZoomed - 0.5;
		uv.x = mix(x * abs(x) * 2.0, uv.x - 0.5, linearityCorrectionX) + 0.5;
	}
	if(linearityCorrectionY != 1.0)
	{
		float y = yZoomed - 0.5;
		uv.y = mix(y * abs(y) * 2.0, uv.y - 0.5, linearityCorrectionY) + 0.5;
	}
	
	vec3 result = Bicubic(uv, 1.0 / HOOKED_size);
	
	return vec4(result, 0.0);
}
