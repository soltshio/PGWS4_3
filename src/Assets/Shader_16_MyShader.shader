Shader "Custom/Shader_16_MyShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _AmbientRate("Ambient Rate",Range(0,1))=0.2
        _SpecularPower("Specular Power",Range(0.001,300))=80
        _SpecularIntensity("Specular Intensity",Range(0,1))=0.3
        _Metallic("Metallic",Range(0,1))=0.5
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal:NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal:NORMAL;
                float2 uv : TEXCOORD0;
                float3 position:TEXCOORDO;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                 half _AmbientRate;
                half _SpecularPower;
                half _SpecularIntensity;
                half _Metallic;
                float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal=TransformObjectToWorldNormal(IN.normal);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.position=TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half FresnelReflectanceAverageDielectric(float co,float f0,float f90)
            {
                co=min(0.9999,max(0.000001,co));

                float root_f0=sqrt(f0);
                float root_f90=sqrt(f90);
                float n=(root_f90+root_f0)/(root_f90-root_f0);
                float n2=n*n;

                float si2=1-co*co;
                float nb=sqrt(n2-si2);
                float bn=nb/n2;

                float r_s=(co-nb)/(co+nb);
                float r_p=(co-bn)/(co+bn);
                return 0.5*f90*(r_s*r_s+r_p*r_p);
            }

            half Fresnel(half f0,half f90,float co)
            {
                return f0+(f90-f0)*pow(1-co,5);//Schlick‹ßŽ—
            }

            half3 Fr_DisneyDiffuse(half3 albedo,half LdotN,half VdotN,half LdotH,half linearRoughness)
            {
                half energyBias=lerp(0.0,0.5,linearRoughness);
                half energyFactor=lerp(1.0,1.0/1.51,linearRoughness);
                half Fd90=energyBias+2.0*LdotH*LdotH*linearRoughness;
                half FL=Fresnel(1,Fd90,LdotN);
                half FV=Fresnel(1,Fd90,VdotN);
                return (albedo*FL*FV*energyFactor);
            }

            float V_SmithGGXCorrelated(float NdotL,float NdotV,float alphaG2)
            {

                float Lambda_GGXV=NdotL*sqrt((-NdotV*alphaG2+NdotV)*NdotV+alphaG2);
                float Lambda_GGXL=NdotV*sqrt((-NdotV*alphaG2+NdotL)*NdotL+alphaG2);
                return 0.5f/(Lambda_GGXV+Lambda_GGXL);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light=GetMainLight();
                half3 normal=normalize(IN.normal);
                half3 view_direction=normalize(TransformViewToWorld(float3(0,0,0))-IN.position);
                float3 reflected_direction=-light.direction+2*normal*dot(light.direction,normal);

                half3 ambient=_BaseColor.rgb;
                half3 lambert=_BaseColor.rgb*max(0,dot(IN.normal,light.direction));
                half3 specular=_SpecularIntensity*pow(max(0,dot(reflected_direction,view_direction)),_SpecularPower);




                half3 lambientColor=light.color*lerp(lambert,ambient,_AmbientRate);
                half3 specularColor=light.color*specular;

                half4 color = lerp((SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * half4(lambientColor,1)),half4(specularColor,1),_Metallic);

                return color;
            }
            ENDHLSL
        }
    }
}
