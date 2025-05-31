/*
��������ú�Phong(����)��ɫ���Ƶ�Ч�����ͱ�����ʹ��Blinn-Phongģ��ʱ�����淴������ø���һ�㡣ͨ�����ǻ�ѡ�������ɫʱ����ȷ�����2��4����
��������Ϊ����Smoothness�������԰��ճ���� 2��4������׼ȷ�������Լ�ȥ��Smoothness�ļ��㣬����һ�¡�
*/

/*
�ο���
https://zhuanlan.zhihu.com/p/20851137096
https://github.com/AnCG7/URPShaderCodeSample
*/

/*
ˮ����Ⱦ��Ҫ��������Ϊ͸�����壬��֤���Ի��_CameraOpaqueTexture����͸���������Ⱦ�����
*/
Shader "Custom/BlinnPhong"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _WaterAbsorption("_WaterAbsorption", Range(0.5, 5.0)) = 1.4
        _ScatteringCofficient("Scattering Cofficient", Vector) = (3.07,1.68,1.4, 0.1)
        _RefractionIndex("Refraction Index", Range(0, 0.1)) = 0.02
        _CausticsStrength("Caustics Strength", Range(0., 10.)) = 5.
        _WaterCausticsSpeed("Water Caustics Speed", Range(0., 1.)) = 0.03
        _CausticsRGBOffset("Caustics RGB Offset", Vector) = (0.005,0.005,0., 0.)
        [MainTexture] _WaterCaustics("Water Caustics", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Transparent"}

        Pass
        {
            

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 viewWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half3 _BaseColor;
            half4 _SpecularColor;
            half _Smoothness;

            float3 _BoundsMin;
            float3 _BoundsMax;
            float _WaterAbsorption;
            float3 _ScatteringCofficient;
            float _RefractionIndex;
            float4x4 _SunMatrix;
            float4 _WaterCaustics_ST;
            float _CausticsStrength;
            float _WaterCausticsSpeed;
            float4 _CausticsRGBOffset;

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_WaterCaustics);
            SAMPLER(sampler_WaterCaustics);

            CBUFFER_END

            /*  ͨ��boundsMin��boundsMaxê��һ���������Χ��
                ��rayOrigin��rayDir����һ�����ߣ���������ߵ���Χ�еľ���
                https://jcgt.org/published/0007/03/04/ */
            float2 RayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir){

                float3 t0 = (boundsMin - rayOrigin) / rayDir;
                float3 t1 = (boundsMax - rayOrigin) / rayDir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

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

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS = positionWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * _Smoothness + 1);
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);

                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, _SpecularColor, smoothness);
                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS) * _BaseColor;
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;
                half4 totalColor = half4(diffuseColor + specularColor + ambientColor,1);

                //ͨ�������Ϣ��ȡˮ��������
                float2 rayInfo = RayBoxDst(_BoundsMin, _BoundsMax, _WorldSpaceCameraPos, -viewWS);
                float lengthToWater = length(_WorldSpaceCameraPos - IN.positionWS);
                float3 opaquePoint = GetWorldPositionFromDepth(IN.positionHCS);
                float lengthToOpaque = length(_WorldSpaceCameraPos - opaquePoint);
                //thickness��Ϊ�ʼ��е�XA����
                float thickness = min(rayInfo.y, lengthToOpaque - lengthToWater);
                float3 Tr = exp(-thickness * _WaterAbsorption);

                //������ɢ��
                float3 inScatteringLight = 0;
                int stepCount = 16;
                float stepLength = thickness / stepCount;
                float curLength = 0;
                for(int i = 0; i < stepCount; i++)
                {
                    curLength += stepLength;
                    float3 samplePoint = IN.positionWS - viewWS * curLength;
                    float2 lightInfo = RayBoxDst(_BoundsMin, _BoundsMax, samplePoint, 1 / light.direction);
                    float lightLength = lightInfo.y;
                    inScatteringLight += exp(-(lightLength + curLength) * _WaterAbsorption * _ScatteringCofficient);
                }
                //����ɢ����λ����
                float cosTheta = dot(normalWS, viewWS);
                float Pr = 0.75 * (1 + cosTheta * cosTheta);

                inScatteringLight *= lightColor * stepLength * _ScatteringCofficient * Pr;

                //��͸�������ԭ��ɫ�ʣ����ڱ�ʾˮ������Ͷ�䣩
                //refractionTwistΪ�����Ŷ�
                float2 refractionTwist = IN.normalWS.xz * _RefractionIndex;
                float2 screenUV = IN.positionHCS.xy / _ScaledScreenParams.xy + refractionTwist;
                half3 cb = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

                //ˮ�½�ɢ
                //�������ͼ������Ϊ0ʱ��˵����Ȳ�������󣬴˴���������
                float causticsMask = step(0.001, SampleSceneDepth(screenUV)) * exp(-thickness * _WaterAbsorption);
                float3 causticLightSpacePosition = mul(opaquePoint, _SunMatrix).xyz;
                float2 lightUV = causticLightSpacePosition.xy + refractionTwist;
                lightUV = TRANSFORM_TEX(lightUV, _WaterCaustics);
                float2 lightUV1 = lightUV + _Time.y * _WaterCausticsSpeed;
                float2 lightUV2 = lightUV - _Time.y * _WaterCausticsSpeed + float2(123.456, 456.789);
                
                float chromaticAberrationOffset = _CausticsRGBOffset.xy;
                half causticsColor1_R = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV1 + chromaticAberrationOffset).r;
                half causticsColor1_G = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV1).g;
                half causticsColor1_B = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV1 - chromaticAberrationOffset).b;
                half3 causticsColor1 = half3(causticsColor1_R, causticsColor1_G, causticsColor1_B);
                
                half causticsColor2_R = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV2 + chromaticAberrationOffset).r;
                half causticsColor2_G = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV2).g;
                half causticsColor2_B = SAMPLE_TEXTURE2D(_WaterCaustics, sampler_WaterCaustics, lightUV2 - chromaticAberrationOffset).b;
                half3 causticsColor2 = half3(causticsColor2_R, causticsColor2_G, causticsColor2_B);
                half3 causticsColor = min(causticsColor1, causticsColor2);
               
                half3 caustics = causticsMask * causticsColor * _CausticsStrength * pow(light.color.rgb, 2);

                // return half4(cb, 1);
                return half4((Tr + inScatteringLight) * cb + caustics, 1) + totalColor;

                return totalColor;
            }

            ENDHLSL
        }
    }
}