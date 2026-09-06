<<<<<<< HEAD
# kikoeta-transl
=======
# Kikoeta Transl

面向 [kikoeta](https://github.com/chenflxs/kikoeta) 的 Windows 桌面翻译伴侣。它将音视频或未翻译的字幕/歌词处理为可供 kikoeta 歌词库使用的时间轴字幕，支持 `.lrc`、`.srt` 与 `.vtt`。

![Kikoeta Transl logo](logo/logo.png)

## 功能

- 导入音频、视频、SRT、LRC、VTT、ASS 与 SSA 文件。
- 对媒体执行 ffmpeg 转码和 CrispASR 听写；字幕输入会跳过这两步。
- 可选 UVR 人声分离、OpenAI 兼容模型听写矫正，以及内置 GalTransl 翻译。
- 导出目标语言或双语 LRC/SRT，并可写入 kikoeta 歌词库。
- Flutter Windows 界面通过本地 HTTP API 驱动 Python engine；同时提供供 kikoeta 或局域网客户端调用的任务 API。

## 工作流

```text
媒体 -> 转码 -> (UVR) -> ASR -> (矫正) -> (翻译) -> LRC / SRT / VTT
字幕 -> 解析 ----------------> (矫正) -> (翻译) -> LRC / SRT / VTT
```

媒体任务的转码与 ASR 为必经步骤；UVR、矫正和翻译均可在任务页关闭。提交已有字幕或歌词时，程序保留原有时间轴并从解析阶段继续。

## 前置条件

- Windows 10/11 x64。
- Python 3.10 或更高版本，并已加入 `PATH`。
- Flutter SDK（仅开发 UI 或构建发布包需要），启用 Windows desktop 支持。
- 以下运行资源放入 `bin/`。它们体积较大，不纳入 Git：

| 资源 | 目录 | 用途 |
| --- | --- | --- |
| ffmpeg 与 ffprobe | `bin/ffmpeg/` | 媒体转码与探测 |
| CrispASR、主模型与 aligner | `bin/crispasr/` | 日语听写与时间轴对齐 |
| UVR ONNX 模型 | `bin/separate/` | 可选人声分离 |
| llama-server | `bin/llama/` | 可选本地翻译后端 |

目录内的 `README.md` 说明了各资源的位置。若未随包提供 ffmpeg，engine 会回退使用系统 `PATH` 中的 `ffmpeg` 与 `ffprobe`。

## 本地运行

安装 Python 依赖并启动 engine：

```powershell
cd engine
python -m pip install -r requirements.txt
python server.py
```

默认端点：

| 服务 | 地址 | 用途 |
| --- | --- | --- |
| 本地 engine | `http://127.0.0.1:18765` | Flutter 桌面端调用 |
| kikoeta/远程服务 | `http://127.0.0.1:2370` | 创建任务、查询状态与下载结果 |

在设置页启用远程访问后，第二个服务会监听 `0.0.0.0:2370`。该服务没有内建认证，暴露到公网前应通过可信网络或反向代理增加访问控制。

另开一个终端启动桌面界面：

```powershell
cd app
flutter pub get
flutter run -d windows
```

界面会优先连接已启动的 engine；未检测到服务时会尝试启动 `engine/server.py`。

## 命令行处理

可跳过桌面界面直接运行单个或多个文件：

```powershell
cd engine
python -m kt run C:\media\song.srt --no-translate
python -m kt run C:\media\song.mkv --uvr --correct
```

`--uvr` 开启人声分离，`--correct` 开启听写矫正，`--no-translate` 仅导出原文时间轴。

## HTTP API

远程接口以 JSON 传输，上传文件的 `content_base64` 需为 Base64 编码。常用接口：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/api/v1/health` | 服务健康检查 |
| `POST` | `/api/v1/jobs` | 创建任务，`files` 可为文件路径或 `{ name, content_base64 }` |
| `GET` | `/api/v1/jobs/{job_id}` | 获取任务状态与下载地址 |
| `GET` | `/api/v1/jobs/{job_id}/events` | 获取任务事件 |
| `GET` | `/api/v1/jobs/{job_id}/files/{index}` | 下载输出文件 |
| `POST` | `/api/v1/jobs/{job_id}/cancel` | 取消任务 |

本地 API 还提供 `/api/settings`、`/api/tools` 与 `/api/jobs`，供桌面界面维护设置和任务队列。

## 构建 Windows 发布包

在项目根目录执行交互式构建脚本：

```powershell
python build.py
```

也可以双击 `start build.bat`。脚本会询问版本号和 build number，使用 `FLUTTER_BIN` 环境变量指定 Flutter（未设置时默认 `G:\A1\flutter\bin\flutter.bat`），并生成：

```text
releases/kikoeta-transl-<version>-windows-x64/
```

该目录包含 Flutter Release、engine、GalTransl、字典、许可证与已准备的 `bin/` 资源。`releases/` 是构建产物，默认被 Git 忽略。

## 目录说明

```text
app/                 Flutter Windows UI
engine/              Python API、任务编排与处理阶段
engine/GalTransl/    内置 GalTransl 源码、插件与字典
bin/                 本地可执行文件与模型（不提交）
docs/                架构与设计说明
logo/                应用图标
build.py             Windows 发布构建脚本
```

更完整的处理流程、配置约定与技术决策见 [docs/架构方案.md](docs/架构方案.md)。

## 许可

本项目采用 [GPL-3.0](LICENSE) 许可。仓库内置的 GalTransl 及其第三方组件仍受各自许可证约束；发布或再分发前请一并阅读随附许可证。
>>>>>>> f4d8c78 (Add translated content across project files)
