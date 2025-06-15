using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class UnderWaterMask : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        //参数设置
        [System.Serializable]
        public class Settings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
            public Material blitMaterial = null;
            public Material maskMaterial = null;
            public int blitMaterialPassIndex = -1;
            public RenderTexture renderTexture = null;

        }

        public FilterMode filterMode { get; set; }
        private Settings _settings;
        private RenderTargetIdentifier _source;
        private RenderTargetIdentifier _underWaterMaskRT;
        private RenderTargetIdentifier _waterLineRT;
        private RenderTargetIdentifier _underWaterRT;
        private int _underWaterMaskRTId = Shader.PropertyToID("_UnderWaterMask");
        private int _underWaterRTId = Shader.PropertyToID("_UnderWater");
        private int _waterLineRTId = Shader.PropertyToID("_waterLine");
        private string _profilerTag;

        private Camera _camera;
        private Camera orthoCamera;
        private Transform _water;
        private Light _mainLight;

        public CustomRenderPass(string tag, Settings settings)
        {
            _profilerTag = tag;
            _settings = settings;
            renderPassEvent = _settings.renderPassEvent;
            _camera = Camera.main;

            GameObject orthoCam = GameObject.Find("Camera");
            orthoCamera = orthoCam.GetComponent<Camera>();
            Debug.Log("ortho camera name:" + orthoCamera.name);

            GameObject water = GameObject.Find("water");
            _water = water.GetComponent<Transform>();
        }

        private void GetCorners()
        { 
            Vector4[] corners = new Vector4[4];
            corners[0] = _camera.ViewportToWorldPoint(new Vector3(0.0f, 0.0f, _camera.nearClipPlane));
            corners[1] = _camera.ViewportToWorldPoint(new Vector3(1.0f, 0.0f, _camera.nearClipPlane));
            corners[2] = _camera.ViewportToWorldPoint(new Vector3(0.0f, 1.0f, _camera.nearClipPlane));
            corners[3] = _camera.ViewportToWorldPoint(new Vector3(1.0f, 1.0f, _camera.nearClipPlane));

            _settings.blitMaterial.SetVectorArray("_CameraCorners", corners);
            _settings.blitMaterial.SetFloat("_Size", orthoCamera.orthographicSize);
            _settings.blitMaterial.SetTexture("_WaterWorldPosition", _settings.renderTexture);
            _settings.blitMaterial.SetVector("_WaterPosition", _water.position);
            GameObject directionalLight = GameObject.Find("Directional Light");
            _mainLight = directionalLight.GetComponent<Light>();
            _settings.blitMaterial.SetMatrix("_SunMatrix", _mainLight.transform.localToWorldMatrix.inverse);

            _settings.maskMaterial.SetTexture("_WaterWorldPosition", _settings.renderTexture);
            _settings.maskMaterial.SetVectorArray("_CameraCorners", corners);
            _settings.maskMaterial.SetFloat("_Size", orthoCamera.orthographicSize);
            _settings.maskMaterial.SetVector("_WaterPosition", _water.position);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            blitTargetDescriptor.depthBufferBits = 0;

            var renderer = renderingData.cameraData.renderer;
            _source = renderer.cameraColorTarget;
            cmd.GetTemporaryRT(_underWaterMaskRTId, blitTargetDescriptor, filterMode);
            _underWaterMaskRT = new RenderTargetIdentifier(_underWaterMaskRTId);
            cmd.GetTemporaryRT(_underWaterRTId, blitTargetDescriptor, filterMode);
            _underWaterRT = new RenderTargetIdentifier(_underWaterRTId);
            cmd.GetTemporaryRT(_waterLineRTId, blitTargetDescriptor, filterMode);
            _waterLineRT = new RenderTargetIdentifier(_waterLineRTId);

            GetCorners();
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(_profilerTag);
            Blit(cmd, _source, _underWaterMaskRT, _settings.maskMaterial, _settings.blitMaterialPassIndex);
            Blit(cmd, _source, _underWaterRT, _settings.blitMaterial, 1);
            Blit(cmd, _underWaterRT, _waterLineRT, _settings.blitMaterial, 0);
            Blit(cmd, _waterLineRT, _source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (_underWaterMaskRTId != -1)
                cmd.ReleaseTemporaryRT(_underWaterMaskRTId);
            if (_underWaterRTId != -1)
                cmd.ReleaseTemporaryRT(_underWaterRTId);
            if (_waterLineRTId != -1)
                cmd.ReleaseTemporaryRT(_underWaterRTId);
        }
    }

    //-----------------------------------ScriptableRendererFeature--------------------------------------

    CustomRenderPass m_ScriptablePass;
    [SerializeField]
    private CustomRenderPass.Settings _edgeSettings = new CustomRenderPass.Settings();

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass("Get Under Water Mask", _edgeSettings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraTag = renderingData.cameraData.camera.tag;

        // 检查相机是否有特定的标签
        if (cameraTag == "MainCamera")
        {
            // 创建并添加自定义渲染通道
            m_ScriptablePass.renderPassEvent = _edgeSettings.renderPassEvent;
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}


