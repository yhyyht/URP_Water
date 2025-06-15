Shader "Custom/GetDepth"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="deff" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            Name "my Depth"
            Tags { "LightMode" = "UniversalGBuffer"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                half4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                half4 color : TEXCOORD0;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            { 
                return IN.color;
            }
            ENDHLSL
        }

        Pass
        {

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                half4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                half4 color : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

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


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 worldPosition = GetWorldPositionFromDepth(IN.positionHCS);
                return half4(worldPosition,1);
            }
            ENDHLSL
        }
    }
}