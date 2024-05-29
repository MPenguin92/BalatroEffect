Shader"Balatro/6"
{
    Properties
    {
        _Tex1 ("Texture1", 2D) = "white" {}
        _Threshold("_Threshold", Range(1,20)) = 4
        _Color("_Color", Color) = (1,1,1,1)
        _Dissolve("_Dissolve", Range(0,1)) = 0
        _ImageDetails("_ImageDetails",Vector) = (284.00, 855.00,1,1)
        _TextureDetails("_TextureDetails",Vector) = (1.00, 8.00, 71.00, 95.00)
        _Foil("_Foil",Vector) = (1,1,1,1)
    }
    SubShader
    {
        Pass
        {
            Tags
            {
                "RenderPipeline"="UniversalRenderPipeline" "RenderType"="Opaque"
            }
            LOD 100

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "BalatroEffectLib.hlsl"


            struct a2v
            {
                float3 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertexHC : SV_POSITION;
                float3 normalW : NORMAL;
                float2 uv : TEXCOORD0;
                float3 vertexWs : TEXCOORD1;
            };


            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.vertexWs = TransformObjectToWorld(i.vertex);
                o.vertexHC = TransformWorldToHClip(o.vertexWs);
                o.uv = i.uv;
                o.normalW = TransformObjectToWorldNormal(i.normal.xyz, true);
                return o;
            }

            float4 blend(float4 top, float4 down)
            {
                float4 c;
                c.rgb = top.rgb * top.a + down.rgb * down.a * (1 - top.a);
                c.a = top.a + down.a;
                return c;
            }



            float4 frag(v2f i) : SV_TARGET
            {
                const float camDNom = dot(normalize(GetWorldSpaceViewDir(i.vertexWs)), i.normalW) * _Threshold;

                float4 rawTex = SAMPLE_TEXTURE2D(_Tex1, sampler_Tex1, TRANSFORM_TEX(i.uv,_Tex1));

                const float4 addEffect = effect6(_Color, rawTex, i.uv, camDNom);

                //拆开做更好,可以自由组装
                float4 finalCol = addEffect; //blend(addEffect,rawTex);
                return finalCol;
            }
            ENDHLSL
        }

    }
}