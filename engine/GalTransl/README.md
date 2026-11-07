# 内置 GalTransl

源码基于 [GalTransl/GalTransl 8.4.2 正式版](https://github.com/GalTransl/GalTransl/releases/tag/8.4.2)，
固定提交 `70e0d92eabc1754660b3e026fbfc06a411b2d6be`，于 2026-11-03 从 7.4.0 升级。
沿用 [GPL-3.0](LICENSE)。完整使用说明和其他格式插件请查看上游仓库。

## 保留范围

- `GalTransl/`：翻译后端、缓存、字典处理、质量检查、插件加载及内部依赖。
  `Service.py` 和翻译进度代码引用 `server.py`，后者引用 `Agent/`，因此暂时保留这条依赖链；
  Kikoeta Transl 通过进程内 `JobSpec` / `run_job_async` 调用，不会启动上游桌面端或 Agent 服务。
- `Dict/`、`translation_guidelines/`：内置字典和翻译规范。
- `res/bccwj-suw+unidic_pos+pron.model.xz`：GenDic 可选分词模型，保留以便后续使用。
- `plugins/`：GalTransl JSON、SRT/LRC/VTT、纯文本、常用文本修复和默认问题检测插件。
- `requirements.txt`、`LICENSE`：依赖和许可证。

移除了上游桌面端、图片、示例工程、独立启动/打包脚本、插件示例、通知插件及音效、
EPUB/MTool JSON/Translator++/MTBench 等当前音视频字幕流程不用的格式插件。
未引入上游 MSG/BGI 脚本插件及其约 10 MB 的 `msg_tool.exe`。
同时移除仅用于已删除插件的 `beautifulsoup4`、`lxml`、`playsound3` 依赖，
以及当前源码未引用的 `fasttext-predict`。

## 集成差异

- 保留 Index-Translate 的自定义请求头、隐藏 Authorization、`chat_template_kwargs`，
  以及在线模型 `thinking` 配置；可用性检测、普通请求和连接重建使用一致配置。
- 保留追加/覆盖提示词及 Sakura 提示词适配；上游 8.4.2 已不再生成旧提示词配置，
  Kikoeta Transl 仍使用这些字段。
- 上游已删除 `ForGal-tsv`；为兼容本项目已有设置，保留 7.4.0 的 TSV 后端及其两段提示词，
  并注册到新版引擎选择和令牌池。
- 保留旧 OpenAI SDK 的 HTTP 客户端回退、缓存回调兼容和安全的项目目录读取。
- 移除内置引擎的联网版本检测、后台更新线程、更新日志提示和 `/api/version/check` 接口；保留当前版本信息。
- 任务结束关闭日志句柄。

更新时应对照固定提交重新应用上述差异，并运行 `python engine/checks/galtransl_integration_check.py`。
该测试使用本机模拟 OpenAI 接口检查完整翻译、时间轴、缓存续翻、请求参数、旧 TSV 和取消任务，
无需访问付费模型。

## 本次验证

- 本机模拟 HTTP 接口的 4 项集成检查通过，覆盖 6 个翻译后端/接口组合。
- 选取上游缓存、问题插件、令牌切换、多轮上下文、代理及项目规范相关的 96 项检查通过；
  其中 8 项可用性检查为上游配置桩补充了空 `pj_config`，以适配本项目读取自定义请求配置的路径。
- 项目原有 82 项测试在升级前后均为 80 项通过、2 项失败：
  `test_pipeline_marks_cancellation_as_cancelled`、`test_media_requires_asr`，本次未扩大范围修复。
- Python 语法检查和 `git diff --check` 通过。未使用真实付费模型验证翻译质量，未重新打包发行版。
