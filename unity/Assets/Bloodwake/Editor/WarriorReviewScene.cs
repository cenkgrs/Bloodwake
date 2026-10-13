using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Bloodwake.Editor
{
    public static class WarriorReviewScene
    {
        const string Root = "Assets/Bloodwake/";
        [MenuItem("Bloodwake/Create Warrior Source Review")]
        public static void Create()
        {
            AssetDatabase.Refresh();
            var importer = (ModelImporter)AssetImporter.GetAtPath(Root + "Art/Warrior/WarriorSource.fbx");
            importer.animationType = ModelImporterAnimationType.Generic;
            importer.importAnimation = false;
            importer.materialImportMode = ModelImporterMaterialImportMode.None;
            importer.SaveAndReimport();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var material = MaterialAsset("Warrior", new Color(.85f,.85f,.85f), .18f);
            material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "Art/Warrior/WarriorBaseColor.jpg"));
            material.SetFloat("_Metallic", 0f);
            material.SetFloat("_Cull", 0f);
            EditorUtility.SetDirty(material);
            var source = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "Art/Warrior/WarriorSource.fbx");
            if (source == null) throw new System.Exception("Warrior source FBX did not import.");
            var model = (GameObject)PrefabUtility.InstantiatePrefab(source);
            model.name = "Warrior - ORIGINAL SOURCE - no retargeting";
            var renderers = model.GetComponentsInChildren<Renderer>();
            var bounds = renderers[0].bounds;
            foreach (var r in renderers) bounds.Encapsulate(r.bounds);
            model.transform.localScale *= 1.8f / bounds.size.y;
            bounds = renderers[0].bounds;
            foreach (var r in renderers) { r.sharedMaterial = material; bounds.Encapsulate(r.bounds); }
            model.transform.position -= new Vector3(bounds.center.x,bounds.min.y,bounds.center.z);
            var floor = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            floor.name = "Review plinth";
            floor.transform.position = new Vector3(0,-.1f,0);
            floor.transform.localScale = new Vector3(3,.1f,3);
            floor.GetComponent<Renderer>().sharedMaterial = MaterialAsset("Plinth",new Color(.065f,.075f,.09f),.3f);
            var cam = new GameObject("Review Camera").AddComponent<Camera>();
            cam.tag = "MainCamera";
            cam.transform.position = new Vector3(2.7f,1.9f,-4.2f);
            cam.transform.LookAt(new Vector3(0,.95f,0));
            cam.fieldOfView = 32;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(.025f,.03f,.045f);
            cam.GetUniversalAdditionalCameraData().renderPostProcessing = true;
            Light("Key",new Vector3(35,-35,0),new Color(1,.88f,.74f),2.1f);
            Light("Rim",new Vector3(25,145,0),new Color(.55f,.7f,1),1.3f);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.2f,.22f,.27f);
            EditorSceneManager.SaveScene(scene,Root + "Scenes/WarriorReview.unity");
            AssetDatabase.SaveAssets();
            Debug.Log("BLOODWAKE_UNITY_REVIEW_READY: original mesh, no animation transfer");
        }
        static Material MaterialAsset(string name, Color color, float smoothness)
        {
            string path = Root + "Art/Warrior/" + name + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (m == null) { m = new Material(Shader.Find("Universal Render Pipeline/Lit")); AssetDatabase.CreateAsset(m,path); }
            m.SetColor("_BaseColor",color); m.SetFloat("_Smoothness",smoothness);
            return m;
        }
        static void Light(string name,Vector3 angles,Color color,float intensity)
        {
            var light = new GameObject(name).AddComponent<Light>();
            light.type = LightType.Directional; light.color = color; light.intensity = intensity;
            light.shadows = LightShadows.Soft; light.transform.rotation = Quaternion.Euler(angles);
        }
    }
}
