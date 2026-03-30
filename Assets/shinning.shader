Shader "Custom/URP/VolumeClouds_Simple"
{
    Properties
    {
        [Header(Cloud Settings)]
        _CloudBaseHeight ("Cloud Base Height", Float) = 5.0
        _CloudTopHeight ("Cloud Top Height", Float) = 20.0
        _CloudDensity ("Cloud Density", Range(0, 3)) = 1.5
        _CloudScale ("Cloud Scale", Float) = 0.05
        
        [Header(Lighting)]
        _LightAbsorption ("Light Absorption", Range(0, 1)) = 0.2
        _PhaseG ("Phase G", Range(-1, 1)) = 0.5
        _CloudColor ("Cloud Color", Color) = (1,1,1,1)
        _SkyColor ("Sky Debug Color", Color) = (0.3, 0.5, 0.9, 0.1)
        
        [Header(Performance)]
        _RayStepCount ("Ray Steps", Range(16, 64)) = 32
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent+100"
        }

        Pass
        {
            Name "VolumeCloudsPass"
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _CloudBaseHeight;
            float _CloudTopHeight;
            float _CloudDensity;
            float _CloudScale;
            float _LightAbsorption;
            float _PhaseG;
            float4 _CloudColor;
            float4 _SkyColor;
            int _RayStepCount;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 rayOriginWS : TEXCOORD1;
            };

            // 简化的3D噪声（更容易出效果）
            float Noise3D(float3 p)
            {
                p = frac(p * float3(12.9898, 78.233, 45.164));
                p += dot(p, p.yzx + 45.543);
                return frac((p.x + p.y) * p.z);
            }

            // 采样云密度
            float SampleDensity(float3 p)
            {
                float3 samplePos = p * _CloudScale;
                float noise = Noise3D(samplePos);
                
                // 高度梯度：中间厚，上下薄
                float heightMid = (_CloudBaseHeight + _CloudTopHeight) * 0.5;
                float heightRange = _CloudTopHeight - _CloudBaseHeight;
                float heightFactor = 1.0 - abs(p.y - heightMid) / (heightRange * 0.5);
                heightFactor = saturate(heightFactor);
                
                return noise * heightFactor * _CloudDensity;
            }

            // Henvey-Greenstein相位函数
            float HG(float cosTheta, float g)
            {
                float g2 = g * g;
                return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.rayOriginWS = _WorldSpaceCameraPos;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float3 rayOrigin = input.rayOriginWS;
                float3 rayDir = normalize(input.positionWS - rayOrigin);

                // 1. 计算射线与云层的交点（简化版AABB）
                float tEnter = 0.0;
                float tExit = 10000.0;
                
                // Y轴相交
                if (rayDir.y != 0.0)
                {
                    float t1 = (_CloudBaseHeight - rayOrigin.y) / rayDir.y;
                    float t2 = (_CloudTopHeight - rayOrigin.y) / rayDir.y;
                    tEnter = max(tEnter, min(t1, t2));
                    tExit = min(tExit, max(t1, t2));
                }
                
                // 如果不相交，返回调试天空色
                if (tExit <= tEnter || tExit < 0.0)
                    return _SkyColor;

                tEnter = max(tEnter, 0.0);
                float stepSize = (tExit - tEnter) / (float)_RayStepCount;
                float t = tEnter;

                // 2. 光线步进
                float3 finalColor = 0.0;
                float transmittance = 1.0;
                Light mainLight = GetMainLight();

                for (int i = 0; i < _RayStepCount; i++)
                {
                    if (transmittance < 0.01) break;

                    float3 pos = rayOrigin + rayDir * t;
                    float density = SampleDensity(pos);

                    if (density > 0.01)
                    {
                        // 光照计算
                        float cosTheta = dot(rayDir, mainLight.direction);
                        float phase = HG(cosTheta, _PhaseG);
                        
                        float3 luminance = mainLight.color * _CloudColor.rgb * phase;
                        finalColor += luminance * density * stepSize * transmittance;
                        transmittance *= exp(-density * stepSize * _LightAbsorption);
                    }

                    t += stepSize;
                }

                // 3. 返回结果（如果没云，还是显示调试色）
                float alpha = 1.0 - transmittance;
                if (alpha < 0.01)
                    return _SkyColor;
                
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}