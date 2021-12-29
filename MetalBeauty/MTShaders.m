//
//  MTShaders.m
//  products
//
//  Created by badwin on 2021/12/14.
//

#import "MTShaders.h"

#define MTL_STRINGIFY(s) @ #s

NSString *kBeautyShaderSourceBGRA = MTL_STRINGIFY(
using namespace metal;

typedef struct {
  packed_float2 position;
  packed_float2 texcoord;
} Vertex;

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
} TextureMappingVertex;

vertex TextureMappingVertex VertexShader(uint vertex_id [[ vertex_id ]],
                                         constant Vertex *verticies[[buffer(0)]]) {
    TextureMappingVertex out;
    constant Vertex &v = verticies[vertex_id];
    out.renderedCoordinate = float4(float2(v.position), 0.0, 1.0);
    out.textureCoordinate = v.texcoord;
    return out;
}

float hardLight(float color) {
    if (color <= 0.5)
        color = color * color * 2.0;
    else
        color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
    return color;
}

fragment float4 FragmentShader(TextureMappingVertex mappingVertex [[ stage_in ]],
                               texture2d<float, access::sample> texture [[ texture(0) ]],
                               constant float *parameters[[buffer(1)]]) {
    
    constexpr sampler inputImageTexture(address::clamp_to_edge, filter::linear);
    float2 textureCoordinate = mappingVertex.textureCoordinate;

    vector_float2 singleStepOffset = *parameters;
    vector_float4 params = *(parameters + 2);
    float brightness = *(parameters + 6);
    const vector_float3 W = vector_float3(0.299, 0.587, 0.114);
    const float3x3 saturateMatrix = float3x3(
                                             float3(1.1102, -0.0598, -0.061),
                                             float3(-0.0774, 1.0826, -0.1186),
                                             float3(-0.0228, -0.0228, 1.1772)
                                             );
    vector_float2 blurCoordinates[24];
    vector_float3 centralColor = float4(texture.sample(inputImageTexture, mappingVertex.textureCoordinate)).rgb;
    
    blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vector_float2(0.0, -10.0);
    blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vector_float2(0.0, 10.0);
    blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vector_float2(-10.0, 0.0);
    blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vector_float2(10.0, 0.0);
    blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vector_float2(5.0, -8.0);
    blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vector_float2(5.0, 8.0);
    blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vector_float2(-5.0, 8.0);
    blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vector_float2(-5.0, -8.0);
    blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vector_float2(8.0, -5.0);
    blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vector_float2(8.0, 5.0);
    blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vector_float2(-8.0, 5.0);
    blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vector_float2(-8.0, -5.0);
    blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vector_float2(0.0, -6.0);
    blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vector_float2(0.0, 6.0);
    blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vector_float2(6.0, 0.0);
    blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vector_float2(-6.0, 0.0);
    blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vector_float2(-4.0, -4.0);
    blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vector_float2(-4.0, 4.0);
    blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vector_float2(4.0, -4.0);
    blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vector_float2(4.0, 4.0);
    blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vector_float2(-2.0, -2.0);
    blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vector_float2(-2.0, 2.0);
    blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vector_float2(2.0, -2.0);
    blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vector_float2(2.0, 2.0);

    float sampleColor = centralColor.g * 22.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[0])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[1])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[2])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[3])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[4])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[5])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[6])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[7])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[8])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[9])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[10])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[11])).g;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[12])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[13])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[14])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[15])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[16])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[17])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[18])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[19])).g * 2.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[20])).g * 3.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[21])).g * 3.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[22])).g * 3.0;
    sampleColor += float4(texture.sample(inputImageTexture, blurCoordinates[23])).g * 3.0;

    sampleColor = sampleColor / 62.0;

    float highPass = centralColor.g - sampleColor + 0.5;

    for (int i = 0; i < 5; i++) {
        highPass = hardLight(highPass);
    }
    float lumance = dot(centralColor, W);
    float alpha = pow(lumance, params.r);
    vector_float3 smoothColor = centralColor + (centralColor-vector_float3(highPass))*alpha*0.1;
    smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
    smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
    smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);

    vector_float3 lvse = vector_float3(1.0)-(vector_float3(1.0)-smoothColor)*(vector_float3(1.0)-centralColor);
    vector_float3 bianliang = max(smoothColor, centralColor);
    vector_float3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;

    float4 gl_FragColor = vector_float4(mix(centralColor, lvse, alpha), 1.0);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, bianliang, alpha);
    gl_FragColor.rgb = mix(gl_FragColor.rgb, rouguang, params.b);

    float3 satcolor = gl_FragColor.rgb * saturateMatrix;
    gl_FragColor.rgb = mix(gl_FragColor.rgb, satcolor, params.a);
    gl_FragColor.rgb = vector_float3(gl_FragColor.rgb + vector_float3(brightness));
    
    return gl_FragColor;
}
);

NSString *kShaderSourceNV12 = MTL_STRINGIFY(
    using namespace metal;

    typedef struct {
      packed_float2 position;
      packed_float2 texcoord;
    } Vertex;

    typedef struct {
      float4 position[[position]];
      float2 texcoord;
    } Varyings;

    vertex Varyings vertexPassthrough(constant Vertex *verticies[[buffer(0)]],
                                      unsigned int vid[[vertex_id]]) {
      Varyings out;
      constant Vertex &v = verticies[vid];
      out.position = float4(float2(v.position), 0.0, 1.0);
      out.texcoord = v.texcoord;
      return out;
    }

    // Receiving YCrCb textures.
    fragment half4 fragmentColorConversion(
        Varyings in[[stage_in]],
        texture2d<float, access::sample> textureY[[texture(0)]],
        texture2d<float, access::sample> textureCbCr[[texture(1)]]) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);
      float y;
      float2 uv;
      y = textureY.sample(s, in.texcoord).r;
      uv = textureCbCr.sample(s, in.texcoord).rg - float2(0.5, 0.5);

      // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
      float4 out = float4(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);

      return half4(out);
    }
);


NSString *kShaderSourceRGBA = MTL_STRINGIFY(
    using namespace metal;
    typedef struct {
      packed_float2 position;
      packed_float2 texcoord;
    } Vertex;

    typedef struct {
      float4 position[[position]];
      float2 texcoord;
    } VertexIO;

    vertex VertexIO vertexPassthrough(constant Vertex *verticies[[buffer(0)]],
                                      uint vid[[vertex_id]]) {
      VertexIO out;
      constant Vertex &v = verticies[vid];
      out.position = float4(float2(v.position), 0.0, 1.0);
      out.texcoord = v.texcoord;
      return out;
    }
    fragment half4 fragmentColorConversion(VertexIO in[[stage_in]],
                                           texture2d<half, access::sample> texture[[texture(0)]],
                                           constant bool &isARGB[[buffer(0)]]) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);
      half4 out = texture.sample(s, in.texcoord);
      if (isARGB) {
        out = half4(out.g, out.b, out.a, out.r);
      }
      return out;
    }
);
