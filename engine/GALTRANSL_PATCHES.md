# GalTransl 集成维护说明

## 上游基线

内置源码取自 GalTransl 8.4.2，发布标签指向 `70e0d92eabc1754660b3e026fbfc06a411b2d6be`。Kikoeta Transl 在 `3a94b8ef56818a62247c8d763a9e255ef9ef8cbf` 从 7.4.0 升级。 [8.4.2 Release](https://github.com/GalTransl/GalTransl/releases/tag/8.4.2) · [8.4.2 源码树](https://github.com/GalTransl/GalTransl/tree/70e0d92eabc1754660b3e026fbfc06a411b2d6be) · [GPL-3.0 许可证](GalTransl/LICENSE)

[KT 翻译阶段](kt/stages/translate.py) 在引擎进程内通过 `GalTransl.Service.JobSpec` 和 `run_job_async` 提交翻译，传入工作目录和任务取消信号。桌面界面、CLI 和本地 HTTP API 由 KT 提供。保留的 GalTransl `Service.py` 及翻译进度代码引用上游 `server.py`，该模块又引用 `Agent/`。KT 的翻译入口只使用这条依赖链中的进程内功能。

## 保留范围

- 保留 `GalTransl/` Python 包、`Dict/`、`translation_guidelines/` 和 GenDic 可选模型 `res/bccwj-suw+unidic_pos+pron.model.xz`。
- 保留 GalTransl JSON、SRT/LRC/VTT、纯文本、常用文本修复及默认问题检测插件。
- 省略上游桌面端、构建和启动脚本、图片、示例项目、通知插件及音效，以及 EPUB、MTool JSON、Translator++、MTBench、MSG 和 BGI 等其他格式插件。上游测试套件独立维护。
- 裁剪后的 [GalTransl/requirements.txt](GalTransl/requirements.txt) 去掉已省略插件使用的 `beautifulsoup4`、`lxml`、`playsound3`，以及当前源码未引用的 `fasttext-predict`。通过 [engine/requirements.txt](requirements.txt) 安装完整引擎依赖。

## 本地补丁

下表路径相对于 [engine/GalTransl/](GalTransl/)。

| 文件 | Kikoeta Transl 修改 |
| --- | --- |
| `GalTransl/Backend/BaseTranslate.py`、`GalTransl/COpenAI.py` | 将 Index-Translate 的自定义请求头、按配置省略 `Authorization` 和 OpenAI 兼容 `extra_body` 用于可用性检测、正式请求及连接重建。KT 在 `extra_body` 中传递 `chat_template_kwargs` 或在线模型 `thinking` 配置。 |
| `GalTransl/Backend/BaseTranslate.py`、`GalTransl/Backend/SakuraTranslate.py` | 保留旧工程提示词的前置、追加和覆盖选项，并接入 Sakura 后端。8.4.2 已停止在新工程中生成旧提示词字段。 |
| `GalTransl/Backend/ForGalTsvTranslate.py`、`GalTransl/Backend/Prompts.py`、`GalTransl/Frontend/LLMTranslate.py`、`GalTransl/__init__.py` | 8.4.2 上游树已移除 `ForGal-tsv`。复用 7.4.0 的 TSV 后端和两段提示词，继续支持 KT 已保存的引擎设置，并接入新版后端选择、默认模型和令牌池。 [7.4.0 源码树](https://github.com/GalTransl/GalTransl/tree/fd911be87efea4a333eab3e58860c80e18eb6104) |
| `GalTransl/Backend/BaseTranslate.py`、`GalTransl/Backend/ForGalJsonTranslate.py`、`GalTransl/COpenAI.py` | 当旧 OpenAI SDK 缺少 `DefaultAioHttpClient` 时使用 `httpx.AsyncClient`。兼容旧缓存回调签名和缺少新版批量策略的调用，优先读取运行时项目路径，并为旧调用保留 JSON 请求重试默认值。 |
| `GalTransl/__init__.py`、`GalTransl/Utils.py`、`GalTransl/Runner.py`、`GalTransl/server.py`、`GalTransl/server_runtime.py` | 移除联网版本检测、后台检查线程、更新日志提示和 `/api/version/check`。保留本地版本号，任务结束时关闭日志句柄。 |
| `.gitignore`、`README.md`、`plugins/readme.md`、`requirements.txt` | 按保留范围调整忽略规则、说明和依赖。 |

## 更新时的核对

1. 在上游 Release 页面确认标签指向的提交，对照该提交的源码树和当前内置目录，保留 KT 所需资源并重新核对上表补丁。
2. 用本机模拟的 OpenAI 兼容服务检查翻译入口。覆盖可用性检测、正常请求和重试所用的头及请求体，检查旧 TSV、字幕时间轴、缓存续翻和任务取消。
3. 检查字幕解析、ASR 清理、翻译结果映射及任务暂存恢复。在本地运行最小验证，按仓库约定清理临时脚本和产物。
