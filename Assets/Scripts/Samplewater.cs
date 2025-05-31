using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting.Antlr3.Runtime;
using UnityEngine;

public class Samplewater
{
    public readonly int width;
    public readonly int height;

    private readonly float springConstant;
    private readonly float damping;
    private readonly float spread;

    private Spring[,] springs;

    //spring 
    private struct Spring
    {
        public float acceleration;
        public float speed;
        public float offset;
        public void Update(float springConstant, float damping)
        {
            acceleration = -springConstant * offset - speed * damping;
            speed += acceleration;
            offset += speed;
        }
    }

    public Samplewater(int width, int height, float springConst, float damping, float spread) 
    { 
        this.width = width;
        this.height = height;
        this.springConstant = springConst;
        this.damping = damping;
        this.spread = spread;
        this.springs = new Spring[width, height];
        for (int i = 0; i < width; i++)
        {
            for (int j = 0; j < height; j++)
            { 
                springs[i, j] = new Spring();
            }
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    public void Update1(float dt)
    {
        //水面自然衰减
        for(int i = 0; i < width;  ++i) 
            for(int j = 0; j < height; ++j)
                springs[i, j].Update(springConstant, damping);
        
        //周围水面传播
        for (int x = 0; x < width; ++x)
        {
            for (int y = 0; y < height; ++y)
            {
                float force = 0;
                for (int dx = -1; dx <= 1; ++dx)
                {
                    for (int dy = -1; dy <= 1; ++dy)
                    {
                        int nx = x + dx;
                        int ny = y + dy;
                        if (nx < width && nx >= 0 && ny < height && ny >= 0)
                        {
                            force += springs[nx, ny].offset - springs[x, y].offset;
                        }
                    }
                }

                springs[x,y].speed += force * spread * dt;
            }

        }
    }

    public float Getoffset(int x, int y)
    {
        return springs[x, y].offset;    
    }

    public void Setoffset(int x, int y, float offset)
    {
        springs[x, y].offset = offset;
        return;
    }
}
