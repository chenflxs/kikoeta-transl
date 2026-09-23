# Kikoeta Transl

![Kikoeta Transl logo](logo/logo.png)

Kikoeta 的 Windows 翻译伴侣：将音视频或已有字幕处理为带时间轴的歌词 / 字幕，并导出给 [kikoeta](https://github.com/chenflxs/kikoeta) 使用。当然也可作为独立翻译器使用，但是我更推荐你使用[VoiceTransl](https://github.com/shinnpuru/VoiceTransl)

## 能做什么

- 导入音频、视频，以及 `SRT`、`LRC`、`VTT`、`ASS`、`SSA` 字幕。
- 音视频可自动听写并生成词级时间轴；已有字幕会保留原时间轴。词级对齐可在听写参数中开关。
- 矫正和翻译可选择在线服务或本地模型；本地模型会在任务开始时自动启动，任务结束后自动关闭。
- 输出支持目标语言单语、译文在前的双语、原文在前的双语，可选择 `LRC` 或 `SRT`；kikoeta 发起的任务可按曲目缓存 LRC 供其读取。
- “最近”页可查看并打开翻译成果，也能按任务清理翻译缓存；清理不会删除已导出的文件。
- 离开模型、听写参数、模型参数、输出或设置页时，未保存的改动会自动保存。“设置”页还可打开项目仓库并检查新版本；发现更新后可进入发布页下载。
- 提供 Windows 桌面应用；kikoeta 和其他受信任的局域网程序也可提交任务。

```text
音视频 → 转码 → 听写 → [矫正] → [翻译] → LRC / SRT
字幕   → 解析 ──────→ [矫正] → [翻译] → LRC / SRT
```

## 下载与配置本地资源

部分组件和模型体积较大，需要单独下载并放到程序目录下对应的文件夹：

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

本地矫正或翻译需要下载 [llama.cpp](https://github.com/ggml-org/llama.cpp) 的 Windows 版，并与 GGUF 模型一起放入 `bin/llama/`。在“模型”页刷新模型列表、选中模型，再把矫正或翻译方式切换为“本地 Llama”即可。程序会在任务运行时自动启动本地模型服务，并在任务结束后关闭；两项都使用本地模型时会共用所选模型。以下按可用显存给出建议，实际占用也受上下文长度和其他程序影响。

| 可用显存 | 推荐模型 | 建议量化 / 说明 |
| --- | --- | --- |
| 4–6 GB | **首选：[GalTransl-v4-4B-2601](https://huggingface.co/SakuraLLM/GalTransl-v4-4B-2601)**<br>备选：[Sakura-1.5B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-1.5B-Qwen2.5-v1.0-GGUF) | GalTransl 4B：4 GB 选择 Q5_K_S，6 GB 选择 Q6_K。<br>Sakura 1.5B：选择 Q4。 |
| 8–10 GB | **首选：[Sakura-GalTransl-7B-v3.7](https://huggingface.co/SakuraLLM/Sakura-GalTransl-7B-v3.7)**<br>备选：[Sakura-7B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-7B-Qwen2.5-v1.0-GGUF) | GalTransl 7B：选择 IQ4_XS / Q4_K。<br>Sakura 7B：选择 IQ4_XS / Q4。 |
| 12–16 GB | **首选：[Sakura-GalTransl-14B-v3.8](https://huggingface.co/SakuraLLM/Sakura-GalTransl-14B-v3.8)**<br>备选：[Sakura-14B-Qwen2.5-v1.0-GGUF](https://huggingface.co/SakuraLLM/Sakura-14B-Qwen2.5-v1.0-GGUF) | GalTransl 14B：选择 IQ4_XS / Q5_K_S。<br>Sakura 14B：选择 IQ4_XS / Q4。 |
| 24 GB 以上 | [Sakura-32B-Qwen2beta-v0.9-GGUF](https://huggingface.co/SakuraLLM/Sakura-32B-Qwen2beta-v0.9-GGUF) | Q4；建议保留额外显存给上下文。若更重视稳定速度，可改用 14B 的 Q6_K。 |

SakuraLLM 声明其模型采用 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh-hans) 且禁止商用，下载和使用前请同时阅读对应模型页的说明。

### 在线翻译模型

在线服务只需在“模型”页填写服务商提供的 OpenAI 兼容地址、模型名和 API Key。个人推荐优先尝试 `ds-v4-pro` 与 `kimi-k2.5`。(这只是个人使用偏好，并不保证是最适合或最好的模型；如果发现更适合字幕翻译的模型，欢迎[提交 Issue](https://github.com/chenflxs/kikoeta-transl/issues/new)分享)。

## 与 GalTransl 的关系

本项目集成并适配了开源项目 [XD2333/GalTransl](https://github.com/XD2333/GalTransl)。感谢 GalTransl 的作者和贡献者提供翻译框架、提示词、字典、缓存及质量检查等基础能力；其完整功能、使用文档和最新版本请以上游的 [README](https://github.com/XD2333/GalTransl#readme)、[Wiki](https://github.com/XD2333/GalTransl/wiki) 与 [Releases](https://github.com/XD2333/GalTransl/releases) 为准。

Kikoeta Transl 主要在 GalTransl 之外增加音视频转码、语音识别、字幕时间轴处理、Kikoeta 歌词库导出，以及面向这些流程的 Windows 界面、命令行和任务 API，并对集成代码做了兼容与衔接调整。因此，本项目中的行为可能与上游原版不同，也不代表 GalTransl 官方立场。两个项目相互独立，不存在官方隶属、背书或合作关系；除非另有明确说明，各项目维护者只对各自仓库中的代码和发布负责。

如问题只在 Kikoeta Transl 中出现，请在[本项目 Issues](https://github.com/chenflxs/kikoeta-transl/issues/new)反馈；如能在未经本项目修改的 GalTransl 最新版中复现，再按上游的贡献说明向 GalTransl 反馈。提交问题时请注明使用的项目、版本、运行方式和复现步骤，避免把集成层问题归因给上游。使用 AI 生成的翻译成果时，也请遵守原作品版权及模型/服务商条款，并清楚标注“AI 翻译”或“机器翻译”，不要将未经完整校对的结果表述为人工汉化。

## 更多信息

开发者可查看[功能索引](docs/功能索引.md)定位实现代码，并查看[网络接口文档](docs/网络接口.md)了解程序接入方式。

## 许可

[GPL-3.0](LICENSE)。集成的 GalTransl 源码沿用其 [GPL-3.0 许可证](engine/GalTransl/LICENSE)；其他第三方组件仍受各自许可证约束。项目名称、链接和致谢用于说明来源，不表示原作者对本项目提供背书或担保。

<details>
<summary>开发者：从源码运行</summary>

运行环境：Windows 10/11 x64、Python 3.10+；运行或构建桌面界面还需要 Flutter SDK。音视频听写和本地模型功能需要按上文准备 ffmpeg、CrispASR 和模型。

启动 engine：

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

也可使用命令行处理文件：

```powershell
cd engine
python -m kt run C:\media\song.srt --no-translate
python -m kt run C:\media\song.mkv --correct
```

</details>
