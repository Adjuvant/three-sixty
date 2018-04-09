// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/MobiusShader" {
	Properties{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_ZoomFactor("zoom Factor", Float) = 1.0

		_MobiusEffectsOnOff("mobiusEffectsOnOff", Int) = 1
		_ComplexEffect1OnOff("complexEffect1OnOff", Int) = 1

		_E1x("e1x", Float) = -0.00000000000000006123233995736766
		_E1y("e1y", Float) = 1.0
		_E2x("e2x", Float) = -0.00000000000000006123233995736766
		_E2y("e2y", Float) = -1.0

		_LoxodromicX("loxodromicX", Float) = 0.0
		_LoxodromicY("loxodromicY", Float) = 0.0

		_ShowFixedPoints("showFixedPoints", Int) = 0
	}

	SubShader{
		Tags{ "Queue" = "Geometry" }

		Pass{
			CGPROGRAM

			#pragma vertex vert             
			#pragma fragment frag2
			#include "UnityCG.cginc"

			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;

			struct vertInput
			{
				float4 pos : POSITION;
				float4 texcoord : TEXCOORD0;
			};

			struct vertOutput {
				float4 pos : SV_POSITION;
				half2 vUv : TEXCOORD0;
			};

			vertOutput vert(vertInput input) {
				vertOutput o;
				o.pos = UnityObjectToClipPos(input.pos);
				o.vUv = TRANSFORM_TEX(input.texcoord, _MainTex);
				return o;
			}

			// ====== Math Utils =======
			#define PI 3.1415926535897932384626433832795f
			#define cx_product(a, b) float2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x)
			#define cx_conjugate(a) float2(a.x,-a.y)
			#define cx_divide(a, b) float2(((a.x*b.x+a.y*b.y)/(b.x*b.x+b.y*b.y)),((a.y*b.x-a.x*b.y)/(b.x*b.x+b.y*b.y)))

			// https://github.com/julesb/glsl-util/blob/master/complexvisual.glsl
			float2 cx_sqrt(float2 a) {
				float r = sqrt(a.x*a.x + a.y*a.y);
				float rpart = sqrt(0.5f*(r + a.x));
				float ipart = sqrt(0.5f*(r - a.x));
				if (a.y < 0.0f) ipart = -ipart;
				return float2(rpart,ipart);
			}

			float2 cx_log(float2 a) {
				float rpart = sqrt((a.x*a.x) + (a.y*a.y));
				float ipart = atan2(a.y,a.x);
				if (ipart > PI) ipart = ipart - (2.0f*PI);
				return float2(log(rpart),ipart);
			}

			float2 cx_exp(float2 z) {
				return float2(exp(z.x) * cos(z.y), exp(z.x) * sin(z.y));
			}

			float2 cx_pow(float2 z, float2 y) {
				return  cx_exp(cx_product(y, cx_log(z)));

			}

			float3 complexToCartesian(float2 c) {
				float denom = 1.0f + c.x*c.x + c.y*c.y;
				float x = 2.0f*c.x / denom;
				float y = 2.0f*c.y / denom;
				float z = (c.x*c.x + c.y*c.y - 1.0) / denom;
				return float3(x,y,z);
			}

			// ===== shader control variables
			uniform float _ZoomFactor;
			uniform float _LoxodromicX;
			uniform float _LoxodromicY;
			uniform float _E1x;
			uniform float _E1y;
			uniform float _E2x;
			uniform float _E2y;
			uniform int _MobiusEffectsOnOff;
			uniform int _ComplexEffect1OnOff;
			uniform int _ShowFixedPoints;

			// ====== Transformation Code
			float2 applyMobiusTransformation(in float2 z, in float2 a, in float2 b, in float2 c, in float2 d) {
				float2 top = cx_product(z,a) + b;
				float2 bottom = cx_product(z,c) + d;
				return cx_divide(top,bottom);
			}
			float2 applyInverseMobiusTransform(in float2 z, in float2 a, in float2 b, in float2 c, in float2 d) {
				// inverse is (dz-b)/(-cz+a).
				return applyMobiusTransformation(z,d,-b,-c,a);
			}
			float2 transformForFixedPoints(in float2 z, in float2 e1, in float2 e2) {
				float2 one = float2(1.0f, 0.0f);
				return applyMobiusTransformation(z,one,-e1,one,-e2);
			}
			float2 inverseTransformForFixedPoints(in float2 z, in float2 e1, in float2 e2) {
				// inverse is (dz-b)/(-cz+a). a and c are 1.

				float2 one = float2(1.0f, 0.0f);
				return applyInverseMobiusTransform(z,one,-e1,one,-e2);
			}
			float2 applyRotation(in float2 z, in float radians) {
				// vec2 exp = cx_exp(vec2(0.,radians));
				float2 exp = float2(cos(radians), sin(radians));
				float2 ans = cx_product(z, exp);
				return ans;
			}
			float2 zoom(in float2 z, in float2 zoomDegree) {
				// a real zoomDegree is a streight zoom without twist.
				// a complex zoomDegree has a twist!
				float2 ans = cx_product(zoomDegree,z);
				return ans;
			}

			half4 frag2(vertOutput input) : COLOR {
				float theta;
				float phi;
				float x;
				float y;
				float z;

				float2 uv = input.vUv;
				uv.x = clamp(uv.x,0.001f,.999f);

				// convert from uv to polar coords
				float2 tempuv = uv;
				theta = (1.0f - tempuv[1]) * PI;
				phi = PI * 2.0f * tempuv[0] + PI;

				// convert polar to cartesian. Theta is polar, phi is azimuth.
				x = sin(theta)*cos(phi);
				y = sin(theta)*sin(phi);
				z = cos(theta);

				// x,y,z are on the unit sphere.
				// if we pretend that sphere is a riemann sphere, then we
				// can get the corresponding complex point, a.
				// http://math.stackexchange.com/questions/1219406/how-do-i-convert-a-complex-number-to-a-point-on-the-riemann-sphere

				// we added the PI to phi above to make the Y axis correspond with
				// the positive imaginary axis and the X axis correspond with
				//  the positive real axis. So flip y and x around in this next equation.
				float2 a = float2(y / (1.0f - z), x / (1.0f - z));

				float2 result = a;
				if (_MobiusEffectsOnOff == 1) {
					float2 e1 = float2(_E1x,_E1y);
					float2 e2 = float2(_E2x,_E2y);
					float2 lox = float2(_LoxodromicX, _LoxodromicY);




					if (_ShowFixedPoints) { // should check if should show fixed points
						float3 e1InCartesian = complexToCartesian(e1);
						float3 e2InCartesian = complexToCartesian(e2);
						float3 aInCartesian = complexToCartesian(a);

						if (distance(aInCartesian, e1InCartesian) < .05) {
							return half4(1.0f, 0.0f, 0.0f, 1.0f);
						}
						if (distance(aInCartesian, e2InCartesian) < .05) {
							return half4(1.0f, 1.0f, 0.0f, 1.0f);
						}
						if (distance(aInCartesian, complexToCartesian(lox)) < .05) {
							return half4(1.0f, 0.0f, 0.0f, 1.0f);
						}
					}




					float2 b = transformForFixedPoints(a, e1, e2);
			
					float2 c;
					//float2 b1 = applyRotation(b, _Time.y / 10.0f);
					float2 b1 = applyRotation(b, 0 / 10.0f);
					c = zoom(b1, float2(_LoxodromicX, _LoxodromicY));
					result = inverseTransformForFixedPoints(c, e1, e2);
				}
				float2 realNumber = float2(_ComplexEffect1OnOff, 0.0f);
				result = cx_pow(result, realNumber);

				// // // // now c back to sphere.
				float denom = 1.0f + result.x*result.x + result.y *result.y;
				x = 2.0f * result.x / denom;
				y = 2.0f * result.y / denom;
				z = (result.x*result.x + result.y*result.y - 1.0f) / denom;

				// convert to polar
				phi = atan2(y, x);
				phi -= (PI / 2.0);    // this correction lines up the UV texture nicely.
				if (phi <= 0.0f) {
					phi = phi + PI*2.0f;
				}
				if (phi >= (2.0f * PI)) {    // allow 2PI since we gen uv over [0,1]
					phi = phi - 2.0f * PI;
				}
				phi = 2.0f * PI - phi;        // flip the texture around.
				theta = acos(z);

				// now get uv in new chart.
				float newv = 1.0f - theta / PI;
				float newu = phi / (2.0f * PI);
				float2 newuv = float2(1 - newu, newv); // Drew: use 1- to flip texture

				return half4(tex2D(_MainTex, newuv).rgb, 1.0f);
			}

			ENDCG
		}
	}

}


