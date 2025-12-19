Shader "Volumetric/Volumetric6WayLitParticles"
{
    Properties
    {
        _BaseMap("Base Color", 2DArray) = "white" {}
        _RLTLightMap("RLT LightMap", 2DArray) = "white" {}
        _BBFLightmap("BBF LightMap", 2DArray) = "white" {}
        _Color("Color Tint", Color) = (1,1,1,1)
        _Spherize("Spherize particles ratio", Range(0,3)) = 1
        _BumpA("Use alpha as Bump map", Range(-1,1)) = 1
        _BumpB("Use Back lightmap as Bump map", Range (-1,1)) = 1
        _LightMapStrength("Light map contribution", Range(0,1)) = 0.5
        _BoostShadows("Shadows boost", Range(0,1)) = 0.2
        _InvFade("Soft Particles Factor", Range(0,4)) = 1
        _AlphaCutOff("Alpha cut off", Range (0,1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
        }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
     
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_softparticle
            #pragma multi_compile _ _FLIPBOOKBLENDING_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Particles.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float4 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 uv: TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float3 positionWS : POSITION1;
                float3 normalWS : NORMAL;
                float3 tangentWS : TANGENT;
                float3 bitangentWS : BITANGENT;
                float4 uv: TEXCOORD0;
                float4 color : COLOR;
            };

            TEXTURE2D_ARRAY(_BaseMap);
            TEXTURE2D_ARRAY(_RLTLightMap);
            TEXTURE2D_ARRAY(_BBFLightmap);
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_RLTLightMap);
            SAMPLER(sampler_BBFLightmap);

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float _BoostShadows;
            float _LightMapStrength;
            float _Spherize;
            float _BumpA;
            float _BumpB;
            float _AlphaCutoff;
            float _InvFade;
            float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = normalInputs.tangentWS;
                OUT.bitangentWS = normalInputs.bitangentWS;

                OUT.color = IN.color;
                OUT.uv.xy = TRANSFORM_TEX(IN.uv.xy, _BaseMap);
                OUT.uv.z = IN.uv.z;

                return OUT;
            }

            float sample_light_map(half3 dir, half4 RLTLight, half4 BBFLight)
            {
                float light = 0;

                light += RLTLight.r * saturate(dir.x);
                light += RLTLight.g * saturate(0 - dir.x);
                light += RLTLight.b * saturate(dir.y);
                light += BBFLight.r * saturate(0 - dir.y);
                light += BBFLight.g * saturate(0 - dir.z);
                light += BBFLight.b * saturate(dir.z);
                
                return light;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D_ARRAY(_BaseMap, sampler_BaseMap, IN.uv.xy, IN.uv.z) * _Color;

                if (_InvFade > 0)
                {
                    float3 screenPos = ComputeNormalizedDeviceCoordinatesWithZ(IN.positionWS, UNITY_MATRIX_VP);
                    float sceneDepth = SampleSceneDepth(screenPos);
                    float particleDepth = screenPos.z;
                    float linearSceneDepth = LinearEyeDepth(sceneDepth, _ZBufferParams);
                    float linearParticleDepth = LinearEyeDepth(particleDepth, _ZBufferParams);
                    float depthDiff = linearSceneDepth - linearParticleDepth;
                    float fade = saturate(depthDiff * 1 / (_InvFade + 0.01));
                    baseColor.a *= fade;
                }
                
                clip(baseColor.a - _AlphaCutoff);
                
                half4 RLTLight = SAMPLE_TEXTURE2D_ARRAY(_RLTLightMap, sampler_RLTLightMap, IN.uv.xy, IN.uv.z);
                half4 BBFLight = SAMPLE_TEXTURE2D_ARRAY(_BBFLightmap, sampler_BBFLightmap, IN.uv.xy, IN.uv.z);
                float3x3 worldToTangent = float3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz);
                
                float3 pos = IN.positionWS;
                float deltaPos = 0;
                deltaPos += _Spherize * (0.5 - cos(PI * length(float2((IN.uv.x - 0.5) * INV_SQRT2, (IN.uv.y - 0.5) * INV_SQRT2))));
                deltaPos += _BumpA * (0.5 - baseColor.a);
                deltaPos += _BumpB * (- 0.5 + BBFLight.g);
                pos += deltaPos * IN.normalWS;
                    
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(pos));
                half3 mainDir = mul(mainLight.direction, worldToTangent);
                half3 lighting = mainLight.color.rgb
                            * max(mainLight.shadowAttenuation, _BoostShadows)
                            * (1 - _LightMapStrength + _LightMapStrength * sample_light_map(mainDir, RLTLight, BBFLight));

                uint pixelLightCount = GetAdditionalLightsCount();
                LIGHT_LOOP_BEGIN(pixelLightCount)
                Light additionalLight = GetAdditionalLight(lightIndex, pos);
                half3 dir = mul(additionalLight.direction, worldToTangent);
                lighting += additionalLight.color.rgb
                             * additionalLight.distanceAttenuation
                             * max(mainLight.shadowAttenuation, _BoostShadows)
                             * max(AdditionalLightRealtimeShadow(lightIndex, pos, additionalLight.direction), _BoostShadows)
                             * (1 - _LightMapStrength + _LightMapStrength * sample_light_map(dir, RLTLight, BBFLight));
                LIGHT_LOOP_END
                
                return baseColor * IN.color * half4(lighting, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

    }

}
