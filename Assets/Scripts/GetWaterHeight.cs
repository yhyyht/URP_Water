using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GetWaterHeight : MonoBehaviour
{
    public GameObject water;
    public Material getHeight;

    private Camera orthoCamera;
    private Material oriMaterial;


    // Start is called before the first frame update
    void Start()
    {
        orthoCamera = GetComponent<Camera>();
        Debug.Log("Camera name: " + orthoCamera.name);
        Renderer renderer = water.GetComponent<Renderer>();
        oriMaterial = renderer.material;
    }

    // Update is called once per frame
    void Update()
    {
        water.GetComponent<Renderer>().material = getHeight;
        Debug.Log("Material name: " + getHeight.name);
        orthoCamera.Render();

        water.GetComponent<Renderer>().material = oriMaterial;
    }
}
