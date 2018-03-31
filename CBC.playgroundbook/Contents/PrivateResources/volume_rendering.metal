//
//  MyShader.metal
//  TestingShaders
//
//  Created by Nils Fischer on 23.03.18.
//  Copyright © 2018 Nils Leif Fischer. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

constexpr sampler s = sampler(coord::normalized, address::repeat, filter::linear);


/*

 # Binary black hole coalescence shaders
 
 */

float3 cartesianToPolar(float3 x) {
    return float3(length(x), atan2(length(x.xz), x.y) + M_PI_F, atan2(-x.z, x.x) + M_PI_F);
    //    return float3(length(x), atan2(length(x.xy), x.z) + M_PI_F, atan2(x.y, x.x) + M_PI_F);
}
float3 polarToCartesian(float3 x) {
    return x.x * float3(cos(x.z) * sin(x.y), cos(x.y), -sin(x.z) * sin(x.y));
}

/// Gravitational wave emission and orbital rotation frequency
float frequency(float t_ret, float chirpMass) {
    return pow(chirpMass, -5.0 / 8.0) * pow(abs(t_ret), -3.0 / 8.0);
}

/// Position of the black holes in inspiraling orbit around each other
float3 objectPosition(float t, float chirpMass, float initialOrbitalAngle, float orbitalSeparationScale, float orbitalSeparationFraction) {
    float f = frequency(t, chirpMass);
    float orbitalAngle = M_PI_F * pow(f * chirpMass, -5.0 / 3.0) + initialOrbitalAngle;
    float orbitalSeparation = orbitalSeparationScale * pow(chirpMass / 4.0, 1.0 / 3.0) * pow(M_PI_F * f, -2.0 / 3.0);
    return polarToCartesian(float3(orbitalSeparationFraction * orbitalSeparation, M_PI_2_F, orbitalAngle));
}

/// Field to be visualized, corresponding to the gauge-invariant spacetime curvature perturbation
float psi4(float t_ret, float r, float theta, float phi, float f, float chirpMass, float hcrossFraction) {
    return ((1.0 - hcrossFraction) * (1.0 + pow(cos(theta), 2.0)) / 2.0 + hcrossFraction * cos(theta)) * sin(2 * M_PI_F * f * t_ret + 2 * phi);
}


/*
 
 ## Volume rendering
 
 */

struct ScreenNodeBuffer {
    float4x4 inverseModelViewProjectionTransform;
};

typedef struct {
    float4 position [[ attribute(SCNVertexSemanticPosition) ]];
} ScreenVertexInput;

struct VolumeRenderingVertexIO {
    float4 position [[position]];
    float2 uv;
    
    float time;
    
    float3 rayOrigin;
    float3 screenCenter;
    float3 screenNormal;
    float halfScreenWidth;
};


vertex VolumeRenderingVertexIO prepareRenderVolume(ScreenVertexInput in [[ stage_in ]],
                                                   constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                                                   constant ScreenNodeBuffer& scn_node [[buffer(1)]])
{
    VolumeRenderingVertexIO out;
    
    // Pass through vertex position
    out.position = in.position;
    // Compute screen color sampler coordinates
    out.uv = float2((in.position.x + 1.0) * 0.5 , (in.position.y + 1.0) * -0.5);
    
    // Collect frame variables for fragment shader
    out.time = scn_frame.time;
    
    // Collect geometry for ray construction
    out.rayOrigin = (scn_node.inverseModelViewProjectionTransform * in.position).xyz;
    out.screenCenter = (scn_node.inverseModelViewProjectionTransform * float4(0.0, 0.0, 0.0, 1.0)).xyz;
    float3 screenVerticalEdge = (scn_node.inverseModelViewProjectionTransform * float4(1.0, 0.0, 0.0, 1.0)).xyz;
    float3 screenHorizontalEdge = (scn_node.inverseModelViewProjectionTransform * float4(0.0, 1.0, 0.0, 1.0)).xyz;
    out.screenNormal = normalize(cross(screenHorizontalEdge - out.screenCenter, screenVerticalEdge - out.screenCenter));
    out.halfScreenWidth = distance(screenVerticalEdge, out.screenCenter);
    return out;
}


struct VolumeRenderingParameters {
    float fieldOfView;
    
    float3 sourcePosition;
    float chirpMass;
    float mergerTime;
    float firstObjectRadius;
    float secondObjectRadius;

    float orbitalSeparationScale;
    float timeScale;
    float waveTravelSpeedScale;
    
    float4 primaryPositiveColor;
    float4 secondaryPositiveColor;
    float4 tertiaryPositiveColor;
    float4 primaryNegativeColor;
    float4 secondaryNegativeColor;
    float4 tertiaryNegativeColor;

    float rayStride;
    // Increase in opacity for a ray passing through 1.0 units of material
    float opticalDensity;
    
    float hcrossFraction;
    int showFrequencyScaling;
};

fragment half4 renderVolume(VolumeRenderingVertexIO in [[stage_in]],
                            constant VolumeRenderingParameters& parameters [[buffer(0)]],
                            texture2d<float, access::sample> colorSampler [[texture(0)]])
{
    // Sample color of originally rendered scene
    float4 sceneColor = colorSampler.sample(s, in.uv);

    // Compute time to merger
    float t = (in.time - parameters.mergerTime) * parameters.timeScale;
    // Nothing to render when effects have propagated out of domain
    float domainOuterRadius = 6.0;
    if (t * parameters.waveTravelSpeedScale > domainOuterRadius) {
        return half4(sceneColor);
    }

    // Setup source parameters
    float3 sourcePosition = parameters.sourcePosition;

    // Construct ray geometry
    float3 rayPosition = in.rayOrigin;
    float screenDistance = in.halfScreenWidth / tan(parameters.fieldOfView / 2.0);
    float3 rayNormal = normalize(rayPosition - in.screenCenter + screenDistance * in.screenNormal);

    // Setup ray striding
    float rayLength = 0.0;
    
    // Restrict ray tracing to spherical domain
    float maximumRayLength;
    float domainInnerRadius = 1.0;
    float domainInnerFalloffDistance = 1.0;
    float domainOuterFalloffDistance = 1.0;
    // Find the intersection of ray with domain
    float pHalf = dot(rayPosition - sourcePosition, rayNormal);
    float q = distance_squared(rayPosition, sourcePosition) - pow(domainOuterRadius, 2.0);
    float pHalfSquareMinusQ = pow(pHalf, 2.0) - q;
    if (pHalfSquareMinusQ > 0) {
        // Two intersections, so trace ray in between
        rayLength = max(-pHalf - sqrt(pHalfSquareMinusQ), 0.0);
        maximumRayLength = -pHalf + sqrt(pHalfSquareMinusQ);
        rayPosition += rayLength * rayNormal;
    } else {
        // No intersection, so skip ray tracing entirely
        maximumRayLength = 0.0;
    }
    
    if (maximumRayLength > 0.0 && t < 0.0) {
        // Check occlusion by black holes
        float secondObjectRadius = parameters.secondObjectRadius;
        float firstObjectRadius = parameters.firstObjectRadius;
        float3 firstObjectPosition = objectPosition(t, parameters.chirpMass, 0.0, parameters.orbitalSeparationScale, secondObjectRadius / (firstObjectRadius + secondObjectRadius)) + sourcePosition;
        float3 secondObjectPosition = objectPosition(t, parameters.chirpMass, M_PI_F, parameters.orbitalSeparationScale, firstObjectRadius / (firstObjectRadius + secondObjectRadius)) + sourcePosition;
        // Find intersection of ray with black holes
        pHalf = dot(rayPosition - firstObjectPosition, rayNormal);
        q = distance_squared(rayPosition, firstObjectPosition) - pow(firstObjectRadius, 2.0);
        pHalfSquareMinusQ = pow(pHalf, 2.0) - q;
        if (pHalfSquareMinusQ > 0) {
            // Intersection with object, so trace only to its surface
            maximumRayLength = min(-pHalf + sqrt(pHalfSquareMinusQ), maximumRayLength);
        }
        pHalf = dot(rayPosition - secondObjectPosition, rayNormal);
        q = distance_squared(rayPosition, secondObjectPosition) - pow(secondObjectRadius, 2.0);
        pHalfSquareMinusQ = pow(pHalf, 2.0) - q;
        if (pHalfSquareMinusQ > 0) {
            // Intersection with object, so trace only to its surface
            maximumRayLength = min(-pHalf + sqrt(pHalfSquareMinusQ), maximumRayLength);
        }
        // TODO: Check occlusion by remnant
    }


    // Perform ray tracing to assemble volume color
    float integratedOpacity = 0.0;
    float3 integratedColor = float3(0.0, 0.0, 0.0);
    float referenceFrequency = parameters.showFrequencyScaling ? frequency(-5.0 * parameters.timeScale, parameters.chirpMass) : 1.0;
    while (integratedOpacity < 1.0 && rayLength < maximumRayLength) {
        
        // Stride along ray
        rayPosition += parameters.rayStride * rayNormal;
        rayLength += parameters.rayStride;
                
        // Find distance and angles to source
        float3 xPolar = cartesianToPolar(rayPosition - sourcePosition);
        // Find retarded time
        float t_ret = t - (xPolar.x - domainInnerRadius) / parameters.waveTravelSpeedScale; // `domainInnerRadius` offset removes the time delay from propagation through inner domain excision

        // Clip volume rendering after merger
        if (t_ret > 0.0) {
            continue;
        }

        // Compute field value to visualize
        float f = frequency(t_ret, parameters.chirpMass);
        float fieldValue = psi4(t_ret, xPolar.x, xPolar.y, xPolar.z, f, parameters.chirpMass, parameters.hcrossFraction);
        if (parameters.showFrequencyScaling) {
            fieldValue *= pow(f / referenceFrequency, 2.0);
        }

        // Decide for a color based on field value
        float4 color;
//        if (fieldValue <= parameters.upperThreshold && fieldValue > parameters.middleThreshold) {
        if (fieldValue > 0.7) {
            color = parameters.primaryPositiveColor;
//        } else if (fieldValue > parameters.lowerThreshold) {
        } else if (fieldValue > 0.5) {
            color = parameters.secondaryPositiveColor;
        } else if (fieldValue > 0.3) {
            color = parameters.tertiaryPositiveColor;
        } else if (fieldValue < -0.7) {
            color = parameters.primaryNegativeColor;
        } else if (fieldValue < -0.5) {
            color = parameters.secondaryNegativeColor;
        } else if (fieldValue < -0.3) {
            color = parameters.tertiaryNegativeColor;
        } else {
            continue;
        }
        
        // Smooth outer and inner domain edges
        float opacityFalloff = smoothstep(0.0, domainInnerFalloffDistance, xPolar.x - domainInnerRadius) * smoothstep(0.0, domainOuterFalloffDistance, domainOuterRadius - xPolar.x);
        
        // Blend/integrate colors
        float alpha = opacityFalloff * parameters.opticalDensity * parameters.rayStride * color.a;
        integratedColor += alpha * color.rgb;
        integratedOpacity += alpha;
    }

    // Alpha-blend colors
    float3 blendedColor = mix(sceneColor.rgb, integratedColor, integratedOpacity);
    return half4(blendedColor.r, blendedColor.g, blendedColor.b, 1.0);
}


///*
//
// ## Binary object motion and deformation
//
// */
//
//
///// Provides per-node data required by the binary object shader
//struct BinaryObjectNodeBuffer {
//    float4x4 modelViewProjectionTransform;
//};
//
///// Vertex data required by the binary object shader
//typedef struct {
//    float4 position [[ attribute(SCNVertexSemanticPosition) ]];
//    float4 normal [[ attribute(SCNVertexSemanticNormal) ]];
//} BinaryObjectVertexInput;
//
///// Output data of the binary object vertex shader, to be passed to the fragment shader
//struct BinaryObjectVertexIO {
//    float4 position [[position]];
//    float3 normal;
//};
//
///// Parameters of the simulation
//struct BinaryObjectParameters {
//    float mergerTime;
//    float initialOrbitalAngle;
//};
//
///// The vertex shader applied to the geometries of both binary objects. Moves and deforms the black holes according to the physics of general relativity.
//vertex BinaryObjectVertexIO binaryObjectGeometry(BinaryObjectVertexInput in [[ stage_in ]],
//                                                 constant SCNSceneBuffer& scn_frame [[buffer(0)]],
//                                                 constant BinaryObjectNodeBuffer& scn_node [[buffer(1)]],
//                                                 constant BinaryObjectParameters& parameters [[buffer(2)]])
//{
//    BinaryObjectVertexIO out;
//
//    float chirpMass = 1.0;
//    float schwarzschildRadius = 0.5;
//    float timeScale = 3.0;
//
//    // Compute object position
//    float t = (scn_frame.time - parameters.mergerTime) * timeScale;
//    if (t > 0.0) {
//        out.position = scn_node.modelViewProjectionTransform * in.position;
//        return out;
//    }
//    float3 objectCenter = objectPosition(t, chirpMass, parameters.initialOrbitalAngle);
//
//    float3 objectRadialUnit = in.normal.xyz;
//    float vertexDistance = schwarzschildRadius;
////    float angleFromOrbitalCenter = acos(-1.0 * dot(normalize(objectPosition), objectRadialUnit));
////    if (angleFromOrbitalCenter < M_PI_2_F) {
////        float deformOffset = 0.2;
////        float deformExponent = 0.5;
////        float deformAmplitude = 0.2;
////        vertexDistance += schwarzschildRadius * deformOffset * deformAmplitude / (pow(angleFromOrbitalCenter / M_PI_2_F, deformExponent) + deformOffset);
////    }
//
//    out.position = scn_node.modelViewProjectionTransform * float4(objectCenter + vertexDistance * objectRadialUnit, 1.0);
//    out.normal = objectRadialUnit;
//
//    return out;
//}
//
///// The fragment shader applied to the binary objects.
//fragment half4 binaryObjectColor(BinaryObjectVertexIO in [[stage_in]]) {
//    return half4(0.0, 0.0, 0.0, 1.0);
//}
//
//
///*
//
// ## Remnant deformation
//
// */
//
///// Parameters of the simulation
//struct RemnantParameters {
//    float mergerTime;
//};
//
///// The vertex shader applied to the geometries of both binary objects. Moves and deforms the black holes according to the physics of general relativity.
//vertex BinaryObjectVertexIO remnantGeometry(BinaryObjectVertexInput in [[ stage_in ]],
//                                                 constant SCNSceneBuffer& scn_frame [[buffer(0)]],
//                                                 constant BinaryObjectNodeBuffer& scn_node [[buffer(1)]],
//                                                 constant RemnantParameters& parameters [[buffer(2)]])
//{
//    BinaryObjectVertexIO out;
//
//    float schwarzschildRadius = 0.5;
//
////    float t = (scn_frame.time - parameters.mergerTime) * timeScale;
//
//    float3 objectRadialUnit = in.normal.xyz;
////    float3 xPolar = cartesianToPolar(objectRadialUnit);
//    float vertexDistance = schwarzschildRadius;// * (1.0 + 0.5 * sin(2 * M_PI_F * 1.0 * t + 2 * xPolar.z) );
//
//    out.position = scn_node.modelViewProjectionTransform * float4(vertexDistance * objectRadialUnit, 1.0);
//    out.normal = objectRadialUnit;
//
//    return out;
//}
