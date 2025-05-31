using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;


[RequireComponent(typeof(MeshFilter))]
public class SamplewaterDebug : MonoBehaviour
{
    private Mesh mesh;
    private Vector3[] vertices;
    private Samplewater water;
    private Material material;
    private Bounds bounds;
    private Camera mainCamera;
    [SerializeField] private Light mainLight;

    [SerializeField] private float springConst = 0.023f;
    [SerializeField] private float damping = 0.005f;
    [SerializeField] private float spread = 0.1f;
    [SerializeField] private int width = 32;
    [SerializeField] private int height = 32;
    [SerializeField] private float latticeSize = 0.5f;
    [SerializeField] private float waveScale = 1.0f;
    [SerializeField] private Color visualColor = Color.white;
    [SerializeField] private int depth = 10;


    // Start is called before the first frame update
    void Start()
    {
        water =new  Samplewater(width, height, springConst, damping, spread);
        mainCamera = Camera.main;
        mesh = CreateMeshFromWater(width, height, latticeSize);
        material = GetComponent<Renderer>().material;

        //设置水面包围盒
        BoxCollider boxCollider = gameObject.AddComponent<BoxCollider>();
        boxCollider.size = new Vector3(width * latticeSize, depth, height * latticeSize);
        boxCollider.center = new Vector3(width * latticeSize / 2, -depth / 2, height * latticeSize / 2);
        bounds = boxCollider.bounds;

        GetComponent<MeshFilter>().mesh = mesh;
    }

    // Update is called once per frame
    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            int randomX = Random.Range(0, width);
            int randomY = Random.Range(0, height);
            water.Setoffset(randomX, randomY, -2);
        }

        //传入包围盒参数
        material.SetVector("_BoundsMin", bounds.min);
        material.SetVector("_BoundsMax", bounds.max);

        if(mainLight != null)
            material.SetMatrix("_SunMatrix", mainLight.transform.localToWorldMatrix.inverse);
    }

    private void FixedUpdate()
    {
        water.Update1(Time.fixedDeltaTime);
        mesh.vertices = UpdateWaterMesh(water);
        mesh.RecalculateNormals();
        
    }

    private void OnDrawGizmos()
    {
        if (water is null) return;
        /* 绘制水面网格 */
        Gizmos.color = visualColor;
        for (int i = 0; i < water.width - 1; i++)
        {
            for (int j = 0; j < water.height - 1; j++)
            {
                Vector3 p0 = new Vector3(i, water.Getoffset(i, j), j);
                Vector3 p1 = new Vector3(i + 1, water.Getoffset(i + 1, j), j);
                Vector3 p2 = new Vector3(i, water.Getoffset(i, j + 1), j + 1);
                Vector3 p3 = new Vector3(i + 1, water.Getoffset(i + 1, j + 1), j + 1);
                Gizmos.DrawLine(p0, p1);
                Gizmos.DrawLine(p0, p2);
                Gizmos.DrawLine(p1, p3);
                Gizmos.DrawLine(p2, p3);
            }
        }
    }

    //创建一个平面mesh
    //平面mesh中的vertex是相对于原点的
    private Mesh CreateMeshFromWater(int width, int height, float latticeSize = 1f)
    {
        var vertexes = new List<Vector3>();
        var triangles = new List<int>();

        for (int i = 0; i < height; i++)
        {
            for (int j = 0; j < width; j++)
            {
                var vtx = new Vector3(i * latticeSize, 0, j * latticeSize);
                vertexes.Add(vtx);
            }
        }

        for (int x = 0; x < height - 1; x++)
        {
            for (int y = 0; y < width - 1; y++)
            {
                int LB = x * water.height + y;
                int LT = LB + 1;
                int RB = (x + 1) * water.height + y;
                int RT = RB + 1;

                triangles.Add(LB);
                triangles.Add(LT);
                triangles.Add(RT);

                triangles.Add(LB);
                triangles.Add(RT);
                triangles.Add(RB);
            }
        }

        var mesh = new Mesh()
        {
            vertices = vertexes.ToArray(),
            triangles = triangles.ToArray()
        };
        return mesh;
    }

    private Vector3[] UpdateWaterMesh(Samplewater water)
    {
        vertices ??= mesh.vertices;
        for (int x = 0; x < water.width; x++)
        {
            for (int y = 0; y < water.height; y++)
            {
                var idx = x * water.height + y;         //根据x，y在mesh中查找顶点
                var source = vertices[idx];
                source.y = water.Getoffset(x, y) * waveScale;
                vertices[idx] = source;
            }
        }

        return vertices;
    }

}
