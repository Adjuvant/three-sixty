using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ZoomControl : MonoBehaviour {
    
    public GameObject sphere1;
    public Camera cam;

    float zoomAmount = 0.01f;
    
    float antipodex(float inx, float iny)
    {
        // -(1/conj(x,y))
        var x = inx;
        var y = -iny; // conjugate
        var denom = x * x + y * y;
        return -x / denom;
    }

    float antipodey(float inx, float iny)
    {
        // -(1/conj(x,y))
        var x = inx;
        var y = -iny; // conjugate
        var denom = x * x + y * y;
        return y / denom;
    }

    // Use this for initialization
    void Start () {
		
	}
	
	// Update is called once per frame
	void Update () {

        if (Input.GetKey("i"))
        {
            // zoom in more
            var renderer = sphere1.GetComponent<Renderer>();
            float currentZoom = renderer.material.GetFloat("_LoxodromicX");
            setValueOnSperes("_LoxodromicX", currentZoom + zoomAmount);
        }

        if (Input.GetKey("o"))
        {
            // zoom out more
            var renderer = sphere1.GetComponent<Renderer>();
            float currentZoom = renderer.material.GetFloat("_LoxodromicX");
            setValueOnSperes("_LoxodromicX", currentZoom - zoomAmount);
        }

        if (Input.GetKeyDown("p"))
        {
            // set current look direction at zoom point
            var lookat = cam.transform.forward;

            var y = lookat.z;
            var x = lookat.x;  // assign z to x.
            var z = lookat.y;   // assign y to z.
            
            var newX = -x / 1 - z;
            var newY = y / 1 - z;

            setValueOnSperes("_E1x", newX);
            setValueOnSperes("_E1y", newY);
            setValueOnSperes("_E2x", antipodex(newX, newY));
            setValueOnSperes("_E2y", antipodey(newX, newY));
        }
    }


    void setValueOnSperes(string name, float value)
    {
        var renderer = sphere1.GetComponent<Renderer>();
        renderer.material.SetFloat(name, value);
    }
}
