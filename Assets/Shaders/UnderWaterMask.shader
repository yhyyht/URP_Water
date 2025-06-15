Shader "Custom/UnderWaterMask"
{
    Properties
    {
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        // 基础纹理
        _MainTex ("Base (RGB)", 2D) = "white" { }
        _WaterAbsorption("_WaterAbsorption", Range(0.01, 5.0)) = 1.4
        _WaterDepth("Water Depth", Float ) = 10
        _FogStartHeight("Fog Start Height", Range(-100.0,100.0)) = 1.0
        _HeightFogDensity("Height Fog Density", Range(0.0, 1.0)) = 0.01
        _DistanceFogDensity("Distance Fog Density", Range(0.0, 1.0)) = 0.01
        _WaterShallowColor("Water Shallow Color", Color) = (1,1,1,1)
        _WaterDeepColor("Water Deep Color", Color) = (1,1,1,1)
        _HeightFogBrightness("Height Fog Brightness", Range(0.0,2.0)) = 1.0
        _WaterCausticsSpeed("Water Caustics Speed", Range(0., 1.)) = 0.03
        [MainTexture] _WaterCaustics("Water Caustics", 2D) = "white" {}
        _CausticsStrength("Caustics Strength", Range(0., 10.)) = 5.
        _CausticsRGBOffset("Caustics RGB Offset", Vector) = (0.005,0.005,0., 0.)
        _CausticAbsorption("Caustic Absorption", Range(0.0, 2.0)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 shadowCoords : TEXCOORD1;
                float2 uvSobel      : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _CameraCorners[4];
            float _Size;
            float4 _WaterPosition;
            float _WaterAbsorption;
            float _FogStartHeight;
            float _HeightFogDensity;
            float _DistanceFogDensity;
            half4 _WaterShallowColor;
            half4 _WaterDeepColor;
            float _HeightFogBrightness;
            float _WaterDepth;
            float4x4 _SunMatrix;
            float _WaterCausticsSpeed;
            float4 _WaterCaustics_ST;
            float _CausticsStrength;
            float4 _CausticsRGBOffset;
            float _CausticAbsorption;

            TEXTURE2D(_WaterWorldPosition);
            SAMPLER(sampler_WaterWorldPosition);
            TEXTURE2D(_WaterCaustics);
            SAMPLER(sampler_WaterCaustics);

            sampler2D _MainTex;

            CBUFFER_END

            float3 GetWorldPositionFromDepth(float3 positionHCS)
            {
                /* get world space position */

                float2 UV = positionHCS.xy / _ScaledScreenParams.xy;
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                return ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
            }

            float SampleShadows(float3 positionWS)
			{
			    //Fetch shadow coordinates for cascade.
			    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
				float attenuation = MainLightRealtimeShadow(shadowCoord);
			
				return attenuation; 
			}

            float GetDepth(float3 positionHCS)
            {
                float2 UV = positionHCS.xy / _ScaledScreenParams.xy;
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                return depth;
            }

            float ComputeUnderwaterFogHeight(float3 positionWS)
            {
                float start = _FogStartHeight;
	
                float3 wsDir = _WorldSpaceCameraPos.xyz - positionWS;
                float FH = start; //Height
                float3 P = positionWS;
                float FdotC = _WorldSpaceCameraPos.y - start; //Camera/fog plane height difference
                float k = (FdotC <= 0.0f ? 1.0f : 0.0f); //Is camera below height fog
                float FdotP = P.y - FH;
                float FdotV = wsDir.y;
                float c1 = k * (FdotP + FdotC);
                float c2 = (1 - 2 * k) * FdotP;
                float g = min(c2, 0.0);
                g = -_HeightFogDensity * (c1 - g * g / abs(FdotV + 1.0e-5f));
                return 1-exp(-g);
            }

            float3 GetUnderwaterFogColor(float3 shallow, float3 deep, float distanceDensity, float heightDensity)
            {
                float3 waterColor = lerp(shallow.rgb, deep.rgb, distanceDensity) * _HeightFogBrightness;
                
                waterColor = lerp(waterColor, deep.rgb * _HeightFogBrightness, heightDensity);
                
                return waterColor;
            }

            // half luminance(half4 color) {
			// 	return  0.299 * color.r + 0.587 * color.g + 0.114 * color.b; 
			// }
			
			// // sobel算子
			// half Sobel(float2  uv[9]) {
			// 	const half Gx[9] = {-1,  0,  1,
			// 						-2,  0,  2,
			// 						-1,  0,  1};
			// 	const half Gy[9] = {-1, -2, -1,
			// 						0,  0,  0,
			// 						1,  2,  1};		
				
			// 	half texColor;
			// 	half edgeX = 0;
			// 	half edgeY = 0;
			// 	for (int it = 0; it < 9; it++) {
			// 		// 转换为灰度值
			// 		texColor = luminance(tex2D(_MainTex, uv[it]));

			// 		edgeX += texColor * Gx[it];
			// 		edgeY += texColor * Gy[it];
			// 	}
			// 	// 合并横向和纵向
			// 	half edge = 1 - (abs(edgeX) + abs(edgeY));
			// 	return edge;
			// }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                // Get the VertexPositionInputs for the vertex position  
                VertexPositionInputs positions = GetVertexPositionInputs(IN.positionOS.xyz);
                // Convert the vertex position to a position on the shadow map
                float4 shadowCoordinates = GetShadowCoord(positions);
                // Pass the shadow coordinates to the fragment shader
                OUT.shadowCoords = shadowCoordinates;

                // //计算周围像素的纹理坐标位置，其中4为原始点，
				// OUT.uvSobel[0] = IN.uv + _ScreenParams.zw * half2(-1, -1);
				// OUT.uvSobel[1] = IN.uv + _ScreenParams.zw * half2(0, -1);
				// OUT.uvSobel[2] = IN.uv + _ScreenParams.zw * half2(1, -1);
				// OUT.uvSobel[3] = IN.uv + _ScreenParams.zw * half2(-1, 0);
				// OUT.uvSobel[4] = IN.uv + _ScreenParams.zw * half2(0, 0);		//原点
				// OUT.uvSobel[5] = IN.uv + _ScreenParams.zw * half2(1, 0);
				// OUT.uvSobel[6] = IN.uv + _ScreenParams.zw * half2(-1, 1);
				// OUT.uvSobel[7] = IN.uv + _ScreenParams.zw * half2(0, 1);
				// OUT.uvSobel[8] = IN.uv + _ScreenParams.zw * half2(1, 1);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //屏幕空间后处理，screenUV等于uv
                float2 screenUV = IN.uv;
                float4 screenWorldPosition = lerp(
                    lerp(_CameraCorners[0], _CameraCorners[1], screenUV.x),
                    lerp(_CameraCorners[2], _CameraCorners[3], screenUV.x), screenUV.y);
                //读取水面世界坐标图的纹理信息
                float2 waterUV = float2(( screenWorldPosition.x - _WaterPosition.x), (screenWorldPosition.z - _WaterPosition.z)) / (_Size*2);
                float4 waterHeight =  SAMPLE_TEXTURE2D(_WaterWorldPosition, sampler_WaterWorldPosition, waterUV);
                float underWaterMask = step(screenWorldPosition.y, waterHeight.y);
                return half4(underWaterMask,0,0,1);

                //-------------------------under Water shading-----------------------------
                
            }
            ENDHLSL
        }
    }
}