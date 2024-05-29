#ifndef BalatroEffectLib
#define BalatroEffectLib

//小丑牌中,有意思的效果都放在这里了
//如果不需要溶解效果,去掉dissolve_mask,直接返回tex * colour
//如果项目就是gamma space,去掉GammaToLinearSpace,直接返回col

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _Tex1_ST;
float _Threshold;
float4 _Color;
float4 burn_colour_1;
float4 burn_colour_2;
float _Speed;
float _Dissolve;
float2 _ImageDetails;
float4 _TextureDetails;
float2 _Foil;
CBUFFER_END

TEXTURE2D(_Tex1);
SAMPLER(sampler_Tex1);

float4 dissolve_mask(float4 tex, float2 texture_coords, float2 uv)
{
    float dissolve = _Dissolve;
    float shadow = 0;
    float4 texture_details = float4(1.00, 8.00, 71.00, 95.00);
    float time = _Time.y;

    if (dissolve < 0.001)
    {
        return float4(shadow ? float3(0., 0., 0.) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }


    float adjusted_dissolve = (dissolve * dissolve * (3. - 2. * dissolve)) * 1.02 - 0.01;
    //Adjusting 0.0-1.0 to fall to -0.1 - 1.1 scale so the mask does not pause at extreme values


    float t = time * 10.0 + 2003.;
    float2 floored_uv = (floor((uv * texture_details.ba))) / max(
        texture_details.b, texture_details.a);
    float2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(
        texture_details.b, texture_details.a);

    float2 field_part1 = uv_scaled_centered + 50. * float2(
        sin(-t / 143.6340), cos(-t / 99.4324));
    float2 field_part2 = uv_scaled_centered + 50. * float2(
        cos(t / 53.1532), cos(t / 61.4532));
    float2 field_part3 = uv_scaled_centered + 50. * float2(
        sin(-t / 87.53218), sin(-t / 49.0000));


    float field = (1. + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.;
    float2 borders = float2(0.2, 0.8);


    float res = (.5 + .5 * cos((adjusted_dissolve) / 82.612 + (field + -.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5. + 5. * dissolve) : 0.) * (dissolve)
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5. + 5. * dissolve) : 0.) * (dissolve)
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5. + 5. * dissolve) : 0.) * (dissolve)
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5. + 5. * dissolve) : 0.) * (dissolve);

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8 * (0.5 -
        abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve)
    {
        if (!shadow && res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) && res >
            adjusted_dissolve)
        {
            tex.rgba = burn_colour_1.rgba;
        }
        else if (burn_colour_2.a > 0.01)
        {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return float4(shadow ? float3(0., 0., 0.) : tex.xyz,
                  res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : .0);
}


float hue(float s, float t, float h)
{
    float hs = fmod(h, 1.) * 6.;
    if (hs < 1.) return (t - s) * hs + s;
    if (hs < 3.) return t;
    if (hs < 4.) return (t - s) * (4. - hs) + s;
    return s;
}

float4 RGB(float4 c)
{
    if (c.y < 0.0001)
        return float4(float3(c.z, c.z, c.z), c.a);

    float t = (c.z < .5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return float4(hue(s, t, c.x + 1. / 3.), hue(s, t, c.x), hue(s, t, c.x - 1. / 3.), c.w);
}

float4 HSL(float4 c)
{
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;

    float4 hsl = float4(.0, .0, .5 * sum, c.a);
    if (delta == .0)
        return hsl;

    hsl.y = (hsl.z < .5) ? delta / sum : delta / (2.0 - sum);

    if (high == c.r)
        hsl.x = (c.g - c.b) / delta;
    else if (high == c.g)
        hsl.x = (c.b - c.r) / delta + 2.0;
    else
        hsl.x = (c.r - c.g) / delta + 4.0;

    hsl.x = fmod(hsl.x / 6., 1.);
    return hsl;
}


inline half4 GammaToLinearSpace(half4 col)
{
    half3 sRGB = col.rgb;
    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return half4(sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h), col.a);

    // Precise version, useful for debugging.
    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
}

//波纹
float4 effect(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 booster = _Speed * _Time.y; //float2(1.54073, 41.24161);
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails + camDNom;


    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy *
        texture_details.ba) / texture_details.ba;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = max(high - low, low * 0.7);

    float fac = 0.8 + 0.9 * sin(
        13. * uv.x + 5.32 * uv.y + booster.r * 12. + cos(booster.r * 5.3 + uv.y * 4.2 - uv.x * 4.));
    float fac2 = 0.5 + 0.5 * sin(
        10. * uv.x + 2.32 * uv.y + booster.r * 5. - cos(booster.r * 2.3 + uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(
        12. * uv.x + 6.32 * uv.y + booster.r * 6.111 + sin(booster.r * 5.3 + uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(
        4. * uv.x + 2.32 * uv.y + booster.r * 8.111 + sin(booster.r * 1.3 + uv.y * 13.2));
    float fac5 = sin(
        0.5 * 16. * uv.x + 5.32 * uv.y + booster.r * 12. + cos(booster.r * 5.3 + uv.y * 4.2 - uv.x * 4.));

    float maxfac = 0.6 * max(
        max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.);

    tex.rgb = tex.rgb * 0.5 + float3(0.4, 0.4, 0.8);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.07) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.17) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7 - 0.1;
    tex.a = tex.a * (0.8 * max(
            min(1., max(0., 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.), 0.4))),
            0.) + 0.15 * maxfac
        * (0.1 + delta));

    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//闪箔
float4 effect2(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 foil = _Foil + camDNom;
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;

    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;
    float2 adjusted_uv = uv - float2(0.5, 0.5);
    adjusted_uv.x = adjusted_uv.x * texture_details.b / texture_details.a;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = min(high, max(0.5, 1. - low));

    float fac = max(
        min(2. * sin((length(90. * adjusted_uv) + foil.r * 2.) + 3. * (1. + 0.8 * cos(
                length(113.1121 * adjusted_uv) - foil.r * 3.121))) - 1. - max(5. - length(90. * adjusted_uv), 0.), 1.),
        0.);
    float2 rotater = float2(cos(foil.r * 0.1221), sin(foil.r * 0.3512));
    float angle = dot(rotater, adjusted_uv) / (length(rotater) * length(adjusted_uv));
    float fac2 = max(
        min(5. * cos(foil.g * 0.3 + angle * 3.14 * (2.2 + 0.9 * sin(foil.r * 1.65 + 0.2 * foil.g))) - 4. - max(
                2. - length(20. * adjusted_uv), 0.), 1.), 0.);
    float fac3 = 0.3 * max(min(2. * sin(foil.r * 5. + uv.x * 3. + 3. * (1. + 0.5 * cos(foil.r * 7.))) - 1., 1.), -1.);
    float fac4 = 0.3 * max(min(2. * sin(foil.r * 6.66 + uv.y * 3.8 + 3. * (1. + 0.5 * cos(foil.r * 3.414))) - 1., 1.),
                           -1.);

    float maxfac = max(max(fac, max(fac2, max(fac3, max(fac4, 0.0)))) + 2.2 * (fac + fac2 + fac3 + fac4), 0.);

    tex.r = tex.r - delta + delta * maxfac * 0.3;
    tex.g = tex.g - delta + delta * maxfac * 0.3;
    tex.b = tex.b + delta * maxfac * 1.9;
    tex.a = min(tex.a, 0.3 * tex.a + 0.9 * min(0.5, maxfac * 0.1));

    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//镭射
float4 effect3(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 holo = _Foil + camDNom;

    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;
    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;
    float4 hsl = HSL(0.5 * tex + 0.5 * float4(0., 0., 1., tex.a));

    float t = holo.y * 7.221 + _Time.y;
    float2 floored_uv = (floor((uv * texture_details.ba))) / texture_details.ba;
    float2 uv_scaled_centered = (floored_uv - 0.5) * 250.;

    float2 field_part1 = uv_scaled_centered + 50. * float2(sin(-t / 143.6340), cos(-t / 99.4324));
    float2 field_part2 = uv_scaled_centered + 50. * float2(cos(t / 53.1532), cos(t / 61.4532));
    float2 field_part3 = uv_scaled_centered + 50. * float2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1. + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.;

    float res = (.5 + .5 * cos((holo.x) * 2.612 + (field + -.5) * 3.14));

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = 0.2 + 0.3 * (high - low) + 0.1 * high;

    float gridsize = 0.79;
    float fac = 0.5 * max(
        max(max(0., 7. * abs(cos(uv.x * gridsize * 20.)) - 6.),
            max(0., 7. * cos(uv.y * gridsize * 45. + uv.x * gridsize * 20.) - 6.)),
        max(0., 7. * cos(uv.y * gridsize * 45. - uv.x * gridsize * 20.) - 6.));

    hsl.x = hsl.x + res + fac;
    hsl.y = hsl.y * 1.3;
    hsl.z = hsl.z * 0.6 + 0.4;

    tex = (1. - delta) * tex + delta * RGB(hsl) * float4(0.9, 0.8, 1.2, tex.a);

    if (tex[3] < 0.7)
        tex[3] = tex[3] / 3.;
    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//多彩
float4 effect4(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 polychrome = _Foil + camDNom;
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;


    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = high - low;

    float saturation_fac = 1. - max(0., 0.05 * (1.1 - delta));

    float4 hsl = HSL(float4(tex.r * saturation_fac, tex.g * saturation_fac, tex.b, tex.a));

    float t = polychrome.y * 2.221 + _Time.y;
    float2 floored_uv = (floor((uv * texture_details.ba))) / texture_details.ba;
    float2 uv_scaled_centered = (floored_uv - 0.5) * 50.;

    float2 field_part1 = uv_scaled_centered + 50. * float2(sin(-t / 143.6340), cos(-t / 99.4324));
    float2 field_part2 = uv_scaled_centered + 50. * float2(cos(t / 53.1532), cos(t / 61.4532));
    float2 field_part3 = uv_scaled_centered + 50. * float2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1. + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.;

    float res = (.5 + .5 * cos((polychrome.x) * 2.612 + (field + -.5) * 3.14));
    hsl.x = hsl.x + res + polychrome.y * 0.04;
    hsl.y = min(0.6, hsl.y + 0.5);

    tex.rgb = RGB(hsl).rgb;

    if (tex[3] < 0.7)
        tex[3] = tex[3] / 3.;

    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//负片
float4 effect5(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 negative = _Foil;
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;

    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float4 SAT = HSL(tex);

    if (negative.g > 0.0 || negative.g < 0.0)
    {
        SAT.b = (1. - SAT.b);
    }
    SAT.r = -SAT.r + 0.2;

    tex = RGB(SAT) + 0.8 * float4(79. / 255., 99. / 255., 103. / 255., 0.);

    if (tex[3] < 0.7)
        tex[3] = tex[3] / 3.;
    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//负片 - 闪光
float4 effect6(float4 colour, float4 tex, float2 texture_coords, float camDNom)
{
    float2 negative_shine = _Foil + camDNom;
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;

    float2 uv = (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = high - low - 0.1;

    float fac = 0.8 + 0.9 * sin(
        11. * uv.x + 4.32 * uv.y + negative_shine.r * 12. + cos(negative_shine.r * 5.3 + uv.y * 4.2 - uv.x * 4.));
    float fac2 = 0.5 + 0.5 * sin(
        8. * uv.x + 2.32 * uv.y + negative_shine.r * 5. - cos(negative_shine.r * 2.3 + uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(
        10. * uv.x + 5.32 * uv.y + negative_shine.r * 6.111 + sin(negative_shine.r * 5.3 + uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(
        3. * uv.x + 2.32 * uv.y + negative_shine.r * 8.111 + sin(negative_shine.r * 1.3 + uv.y * 11.2));
    float fac5 = sin(
        0.9 * 16. * uv.x + 5.32 * uv.y + negative_shine.r * 12. + cos(negative_shine.r * 5.3 + uv.y * 4.2 - uv.x * 4.));

    float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.);

    tex.rgb = tex.rgb * 0.5 + float3(0.4, 0.4, 0.8);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.27) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.27) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7 - 0.1;
    tex.a = tex.a * (0.5 * max(min(1., max(0., 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.), 0.4))), 0.) +
        0.15 * maxfac * (0.1 + delta));
    float4 col = dissolve_mask(tex * colour, texture_coords, uv);
    return GammaToLinearSpace(col);
}

//扫描
float4 effect7(float4 colour, float2 texture_coords, float camDNom)
{
    float2 hologram = _Foil + _Time.z;
    float2 image_details = _ImageDetails;
    float4 texture_details = _TextureDetails;
    
    //Glow effect
    float glow = 0.;
    int glow_samples = 4;
    int actual_glow_samples = 0;
    float glow_dist = 0.0015;
    float _a = 0.;

     for (int i = -glow_samples; i <= glow_samples; ++i){
            for (int j = -glow_samples; j <= glow_samples; ++j){
                _a = SAMPLE_TEXTURE2D(_Tex1,sampler_Tex1,texture_coords+ (glow_dist)*float2(float(i), float(j))).a;
                if (_a < 0.9){
                    actual_glow_samples += 1;
                    glow = glow + _a;
                }
            }
     }
     glow /= 0.7*float(actual_glow_samples);
    
    //Create the horizontal glitch offset effects
    float offset_l = 0.;
    float offset_r = 0.;
    float timefac = 1.0*hologram.g;
    offset_l = -10.0*(-0.5+sin(timefac*0.512 + texture_coords.y*14.0)
            + sin(-timefac*0.8233 + texture_coords.y*11.532)
            + sin(timefac*0.333 + texture_coords.y*13.3)
            + sin(-timefac*0.1112331 + texture_coords.y*4.044343));
    offset_r = -10.0*(-0.5+sin(timefac*0.6924 + texture_coords.y*19.0)
        + sin(-timefac*0.9661 + texture_coords.y*21.532)
        + sin(timefac*0.4423 + texture_coords.y*30.3)
        + sin(-timefac*0.13321312 + texture_coords.y*3.011));
    if (offset_r >= 1.5 || offset_r <= 0.){offset_r = 0.;}
    if (offset_l >= 1.5 || offset_l <= 0.){offset_l = 0.;}
    texture_coords.x = texture_coords.x + 0.002*(-offset_l + offset_r);

    float4 tex = SAMPLE_TEXTURE2D(_Tex1,sampler_Tex1,texture_coords);
    if (tex.a > 0.999){tex = float4(0.,0.,0.,0.);}
    if (tex.a < 0.001){tex.rgb = float3(0.,1.,1.);}
    float2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    if (uv.x >0.95 || uv.x < 0.05 || uv.y > 0.95 || uv.y < 0.05){
        return float4(0.,0.,0.,0.);
    }

    float light_strength = 0.4*(0.3*sin(2.*hologram.g) + 0.6 + 0.3*sin(hologram.r*3.) + 0.9);
    float4 final_col;
    if (tex.a < 0.001){
        final_col = tex*colour + float4(0., 1., .5,0.6)*light_strength*(1.+abs(offset_l)+abs(offset_r))*glow;
    }
    else{
        final_col = tex*colour + float4(0., 0.3, 0.2,0.3)*light_strength*(1.+abs(offset_l)+abs(offset_r))*glow;
    }
    

    float4 col = dissolve_mask(final_col, texture_coords, uv);
    return GammaToLinearSpace(col);
}

#endif
