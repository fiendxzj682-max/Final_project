using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

// 脚本文件名必须和类名完全一致：LoadScene.cs
public class LoadScene : MonoBehaviour
{
    [Header("场景设置")]
    [Tooltip("目标场景在Build Settings里的序号（从0开始）")]
    public int sceneBuildIndex = 1;

    [Tooltip("也可以直接填场景名（优先级比序号高，填了就用这个）")]
    public string sceneName = "";

    void Awake()
    {
        // 脚本启动时打印日志，确认脚本已挂载
        Debug.Log($"[LoadScene] 脚本已挂载到物体：{gameObject.name}");
        DontDestroyOnLoad(gameObject);
        Debug.Log($"[LoadScene] 脚本已挂载到物体：{gameObject.name}");
    }

    void Start()
    {

    }

    void Update()
    {

    }

    // 给信号发射器调用的核心方法
    public void LoadNextScene()
    {
        Debug.Log("========================================");
        Debug.Log("[LoadScene] 信号已触发！LoadNextScene() 被调用");

        // 优先用场景名加载，如果没填场景名，就用序号
        if (!string.IsNullOrEmpty(sceneName))
        {
            Debug.Log($"[LoadScene] 尝试用场景名加载：{sceneName}");
            CheckAndLoadScene(sceneName);
        }
        else
        {
            Debug.Log($"[LoadScene] 尝试用Build序号加载：{sceneBuildIndex}");
            CheckAndLoadScene(sceneBuildIndex);
        }

        Debug.Log("========================================");
    }

    // 检查场景是否在Build Settings里，然后加载
    private void CheckAndLoadScene(object sceneIdentifier)
    {
        bool sceneExists = false;
        string targetName = "";

        // 检查Build Settings里的所有场景
        for (int i = 0; i < SceneManager.sceneCountInBuildSettings; i++)
        {
            string scenePath = SceneUtility.GetScenePathByBuildIndex(i);
            string checkName = System.IO.Path.GetFileNameWithoutExtension(scenePath);

            // 匹配场景名或序号
            if ((sceneIdentifier is string name && checkName == name) ||
                (sceneIdentifier is int index && i == index))
            {
                sceneExists = true;
                targetName = checkName;
                break;
            }
        }

        if (sceneExists)
        {
            Debug.Log($"[LoadScene] 场景「{targetName}」验证通过，开始加载！");
            // 执行加载
            if (sceneIdentifier is string)
                SceneManager.LoadScene((string)sceneIdentifier);
            else
                SceneManager.LoadScene((int)sceneIdentifier);
        }
        else
        {
            Debug.LogError($"[LoadScene] 错误：找不到目标场景！请检查Build Settings里是否添加了场景，以及序号/名称是否正确。");
        }
    }
}