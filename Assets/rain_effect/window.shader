Shader "Unlit/Raindop"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RainAmount ("_RainAmount", float) = 1.0
        _Speed ("_Speed", float) = 1.0
        _Blur ("_Blur", Range(0, 1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull[_CullMode]
        Blend SrcAlpha OneMinusSrcAlpha
 
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
 
            #include "UnityCG.cginc"
 
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
 
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
 
            sampler2D _MainTex;
            float4 _MainTex_ST;
 
            float _RainAmount;
            float _Speed;
            float _Blur;
 
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
 
            float pingPong(float v, float t)
            {
                return smoothstep(0, v, t) * smoothstep(1, v, t);
            }
 
            //伪随机数/噪声模式 分两步
            //1.打乱2维uv,扩展成三维
            //2.算上自己的点积,最后提取小数部分
            float3 noiseGrid(float2 uv)
            {
                float pt = uv.x * 0.12234 + uv.y * 0.54321;//打乱uv
                float3 pt3 = frac(float3(pt * 0.91234, pt * 0.8723, pt * 0.7654));//将uv扩展成3维向量
                pt3 += dot(pt3, pt3.yzx);//将 dot(pt3,pt3.yzx) 的结果加到 pt3 的每个分量上：
                pt3 = frac(float3((pt3.x + pt3.y) * pt3.z, (pt3.y + pt3.z) * pt3.x, (pt3.z + pt3.x) * pt3.y));//提取每一个分量的小数部分,否则过亮导致曝光
                return pt3;
            }
            //一维噪声
            float noise(float n)
            {
                return frac(sin(n * 12345.678) * 87654.321);
            }
            //静态水滴
            float staticDrops(float2 uv, float t)
            {
                uv *= 10;
 
                float2 id = floor(uv);//取uv整数
 
                float3 n3 = noiseGrid(float2(id.x * 123.456, id.y * 456.789));
 
                uv = frac(uv) - 0.5;//改变画布亮度
 
                float2 p = (n3.xy - 0.5) * 0.7;//防止部分圆形小点被裁切,做位移和缩放
                //为了得到静态水滴需要的圆形结构
                float radius = length(uv - p);//条形结构 - 随机数网格
 
                float fade = pingPong(0.025, frac(t + n3.z));
                float c = smoothstep(0.3, 0, radius);// * frac(n3.z * 10) * fade;//让原点灰度随机变化
 
                return c;
            }
            //动态水滴
            float2 dynamicDrops(float2 uv, float t)
            {
                float2 origUV = uv;
 
                uv.y += t;
 
                float2 scale = float2(6, 1);
                float2 scale2 = scale * 2;
 
                float2 id = floor(uv * scale2);
                uv.y += noise(id.x);
 
                id = floor(uv * scale2);
                float3 n3 = noiseGrid(id);
                float2 st = frac(uv * scale2) - float2(0.5, 0);
                //float d = length(st);
 
                //计算水滴下落动画
                float x = n3.x - 0.5;
 
                //x方向添加扭曲
                float wiggle = sin(origUV.y * 20 + sin(origUV.y + 20));
                x += wiggle * (0.5 - abs(x)) * (n3.z - 0.5);
                x *= 0.7;
                //y方向添加随机速度
                float y = pingPong(0.85, frac(t + n3.z));
 
                float2 p = float2(x, y);
                float d = length((st - p) * scale.yx);
 
                //绘制水滴
                float mainDrop = smoothstep(0.4, 0, d);
 
                //绘制拖尾
                float r = sqrt(smoothstep(1, y, st.y));
                float cd = abs(st.x - x);
 
                float trail = smoothstep(0.23 * r, 0.15 * r * r, cd);
                float trailFront = smoothstep(-0.02, 0.02, st.y - y);
                trail *= trailFront * r * r;
 
                //绘制拖尾的小水珠
                y = origUV.y;
                y = frac(y * 10) + (st.y - 0.5);
 
                float dd = length(st - float2(x, y));
                float droplets = smoothstep(0.3, 0, dd) * r * trailFront;
                float m = mainDrop + droplets;
 
                return float2(m, trail);
            }
 
            //静态水滴 + 动态水滴(往下滑动的水滴,往下落,不连续的水珠)
            float2 drops(float2 uv, float t, float layer0, float layer1, float layer2)
            {
                float sd = staticDrops(uv, t) * layer0;
                float2 dd0 = dynamicDrops(uv, t) * layer1;
                float2 dd1 = dynamicDrops(uv * 1.85, t) * layer2;
 
                float c = sd + dd0.x + dd1.x;
                c = smoothstep(0.3, 1, c);
 
                float trail = max(dd0.y, dd1.y);
                return float2(c, trail);
            }
 
            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                //在长宽比为1:1上进行绘制,矫正
                uv.x *= _ScreenParams.x / _ScreenParams.y;
 
                //让圆点随时间移动而移动
                float t = _Time.x * _Speed;
 
                float layer0 = smoothstep(0, 2, _RainAmount);
                float layer1 = smoothstep(0, 0.75, _RainAmount);
                float layer2 = smoothstep(0, 0.5, _RainAmount);
 
                float2 c = drops(uv, t, layer0, layer1, layer2);
 
                float2 e = float2(0.002, 0);
 
                float cx = drops(uv + e, t, layer0, layer1, layer2).x;
                float cy = drops(uv + e.yx, t, layer0, layer1, layer2).x;
 
                float2 normal = float2(cx - c.x, cy - c.x);
                //return c.x;
                float focus = lerp(6, 0, _RainAmount);
                focus *= _Blur;
                fixed4 col = tex2Dlod(_MainTex, float4(i.uv + normal, 0, focus));
 
                return col;
            }
            ENDCG
        }
    }
}
