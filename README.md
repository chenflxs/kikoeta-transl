# Kikoeta Transl

![Kikoeta Transl logo](logo/logo.png)

Kikoeta 的 Windows 翻译伴侣：将音视频或已有字幕处理为带时间轴的歌词 / 字幕，并导出给 [kikoeta](https://github.com/chenflxs/kikoeta) 使用。当然也可作为独立翻译器使用，但是我更推荐你使用[VoiceTransl](https://github.com/shinnpuru/VoiceTransl)
## 能做什么

- 导入音频、视频，以及 `SRT`、`LRC`、`VTT`、`ASS`、`SSA` 字幕。
- 使用 ffmpeg 转码并由 CrispASR 听写；已有字幕会保留原有时间轴。
- 可选使用 OpenAI 兼容接口矫正听写文本，并由集成的 [GalTransl](https://github.com/XD2333/GalTransl) 翻译核心完成翻译。
- 导出目标语言或双语 `LRC` / `SRT`，可选写入 kikoeta 歌词库。
- 提供 Flutter Windows 界面、命令行和局域网任务 API。

```text
音视频 → 转码 → 听写 → [矫正] → [翻译] → LRC / SRT
字幕   → 解析 ──────→ [矫正] → [翻译] → LRC / SRT
```

## 从源码运行

运行环境：Windows 10/11 x64、Python 3.10+；仅在运行或构建桌面界面时需要 Flutter SDK。请先按下文下载并配置 ffmpeg、CrispASR 与模型；这些大文件不会随仓库提供。

启动 Python engine：

```powershell
cd engine
python -m pip install -r requirements.txt
python server.py
```

另开终端启动桌面端：

```powershell
cd app
flutter pub get
flutter run -d windows
```

也可直接用命令行处理文件：

```powershell
cd engine
python -m kt run C:\media\song.srt --no-translate
python -m kt run C:\media\song.mkv --correct
```

## 下载与配置本地资源

仓库只保存源码、文档和小型配置。可执行文件、模型、API 设置和工作产物均在 `.gitignore` 中排除，需自行下载并放到以下目录：

| 资源 | 放置位置 | 快速链接 |
| --- | --- | --- |
| ffmpeg、ffprobe | `bin/ffmpeg/` | [FFmpeg 下载页](https://ffmpeg.org/download.html) |
| CrispASR 可执行文件 | `bin/crispasr/` | [CrispASR Releases](https://github.com/CrispStrobe/CrispASR/releases) |
| 本地翻译模型与 llama-server（可选） | `bin/llama/` | [llama.cpp Releases](https://github.com/ggml-org/llama.cpp/releases) |

将 `ffmpeg.exe`、`ffprobe.exe` 放入 `bin/ffmpeg/`，并将 CrispASR 发布包中的 `crispasr.exe` 放入 `bin/crispasr/`。也可以将 ffmpeg 安装到系统 `PATH`；只处理已有字幕时不需要 CrispASR。

### ASR 与时间轴对齐模型

本项目使用 CrispASR 的 GGUF 模型。请将下表中各下载页提供的一个 `.gguf` 文件放进 `bin/crispasr/`；不要下载仅供 Python/Transformers 使用的 Safetensors 权重。模型页点击“查询模型列表”后会自动发现文件。

| 用途 | 建议模型与文件 | 魔搭 | Hugging Face |
| --- | --- | --- | --- |
| 日语动漫 / Galgame 听写 | `qwen3-asr-1.7b-ja-anime`；推荐 `qwen3-asr-1.7b-ja-anime-q4_k.gguf`（约 1.5 GB） | [搜索同名 GGUF](https://modelscope.cn/models?name=qwen3-asr-1.7b-ja-anime-GGUF) | [模型页](https://huggingface.co/cstr/qwen3-asr-1.7b-ja-anime-GGUF) |
| 字词级时间轴 | `qwen3-forced-aligner-0.6b`；推荐 `qwen3-forced-aligner-0.6b-q4_k.gguf`（约 0.5 GB） | [搜索同名 GGUF](https://modelscope.cn/models?name=qwen3-forced-aligner-0.6b-GGUF) | [模型页](https://huggingface.co/cstr/qwen3-forced-aligner-0.6b-GGUF) |

在“模型”页中选择这两个文件，`backend` 选择 `qwen3-1.7b`（或 CrispASR 列出的等效 Qwen3 backend），源语言选择 `ja`。Q4_K 是默认推荐的体积与质量平衡；显存或内存充足时也可选择同页的 Q8_0 文件。

### 本地翻译模型

本地翻译需要将 [llama.cpp](https://github.com/ggml-org/llama.cpp) 的 `llama-server.exe` 与一个 Sakura GGUF 放入 `bin/llama/`，再在模型页填写本地服务的 OpenAI 兼容地址（通常为 `http://127.0.0.1:8080/v1`）。以下按可用显存给出建议；实际占用还会随量化、上下文长度和其他程序变化。

| 可用显存 | 推荐 Sakura 模型 | 建议量化 / 说明 |
| --- | --- | --- |
| 4–6 GB | [Sakura-1.5B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-1.5B-Qwen2.5-v1.0-GGUF) | Q4；适合尝试或低显存设备，翻译质量有限。 |
| 8–10 GB | [Sakura-7B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-7B-Qwen2.5-v1.0-GGUF) | IQ4_XS / Q4；日常本地翻译的优先选择。 |
| 12–16 GB | [Sakura-14B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-14B-Qwen2.5-v1.0-GGUF) | IQ4_XS / Q4；质量与显存的平衡选择。 |
| 24 GB 以上 | [Sakura-32B-Qwen2beta-v0.9-GGUF](https://huggingface.co/SakuraLLM/Sakura-32B-Qwen2beta-v0.9-GGUF) | Q4；建议保留额外显存给上下文。若更重视稳定速度，可改用 14B 的 Q6_K。 |

示例启动命令（请把模型文件名替换为实际下载的文件）：

```powershell
cd bin/llama
.\llama-server.exe -m .\sakura-7b-qwen2.5-v1.0-iq4xs.gguf --host 127.0.0.1 --port 8080
```

### 在线翻译模型

在线服务只需在“模型”页填写服务商提供的 OpenAI 兼容地址、模型名和 API Key。个人推荐优先尝试 `ds-v4-pro` 与 `kimi-k2.5`。(这只是个人使用偏好，并不保证是最适合或最好的模型；如果发现更适合字幕翻译的模型，欢迎[提交 Issue](https://github.com/chenflxs/kikoeta-transl/issues/new)分享)。

## 与 GalTransl 的关系

本项目的翻译能力建立在开源项目 [XD2333/GalTransl](https://github.com/XD2333/GalTransl) 的工作之上，并在 `engine/GalTransl/` 中保留了一份为本项目工作流适配过的源码。感谢 GalTransl 的作者和贡献者提供翻译框架、提示词、字典、缓存及质量检查等基础能力；其完整功能、使用文档和最新版本请以上游的 [README](https://github.com/XD2333/GalTransl#readme)、[Wiki](https://github.com/XD2333/GalTransl/wiki) 与 [Releases](https://github.com/XD2333/GalTransl/releases) 为准。

Kikoeta Transl 主要在 GalTransl 之外增加音视频转码、语音识别、字幕时间轴处理、Kikoeta 歌词库导出，以及面向这些流程的 Windows 界面、命令行和任务 API；同时对所集成的 GalTransl 代码做了兼容与衔接调整。因此，本仓库中的行为可能与上游原版不同，也不代表 GalTransl 官方版本或官方立场。两个项目相互独立，不存在官方隶属、背书或合作关系；除非另有明确说明，各项目维护者只对各自仓库中的代码和发布负责。

如问题只在 Kikoeta Transl 中出现，请在[本项目 Issues](https://github.com/chenflxs/kikoeta-transl/issues/new)反馈；如能在未经本项目修改的 GalTransl 最新版中复现，再按上游的贡献说明向 GalTransl 反馈。提交问题时请注明使用的项目、版本、运行方式和复现步骤，避免把集成层问题归因给上游。使用 AI 生成的翻译成果时，也请遵守原作品版权及模型/服务商条款，并清楚标注“AI 翻译”或“机器翻译”，不要将未经完整校对的结果表述为人工汉化。

## 目录说明

```text
app/                 Flutter Windows 界面
engine/              Python 服务、HTTP API 与处理管线
engine/GalTransl/    经本项目适配的 GalTransl 源码、插件、字典和翻译规范
bin/                 本地可执行文件与模型（不提交）
docs/                开发与功能说明
output/              默认导出目录（不提交）
```

实现位置与接口索引见 [功能索引](docs/功能索引.md)。

## 许可

[GPL-3.0](LICENSE)。集成的 GalTransl 源码沿用其 [GPL-3.0 许可证](engine/GalTransl/LICENSE)；其他第三方组件仍受各自许可证约束。项目名称、链接和致谢用于说明来源，不表示原作者对本项目提供背书或担保。
