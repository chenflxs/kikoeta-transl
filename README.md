# Kikoeta Transl

![Kikoeta Transl logo](logo/logo.png)

Kikoeta 的 Windows 翻译伴侣：将音视频或已有字幕处理为带时间轴的歌词 / 字幕，并导出给 [kikoeta](https://github.com/chenflxs/kikoeta) 使用。

## 能做什么

- 导入音频、视频，以及 `SRT`、`LRC`、`VTT`、`ASS`、`SSA` 字幕。
- 使用 ffmpeg 转码并由 CrispASR 听写；已有字幕会保留原有时间轴。
- 可选使用 OpenAI 兼容接口矫正听写文本，并由内置 GalTransl 翻译。
- 导出目标语言或双语 `LRC` / `SRT`，可选写入 kikoeta 歌词库。
- 提供 Flutter Windows 界面、命令行和局域网任务 API。

```text
音视频 → 转码 → 听写 → [矫正] → [翻译] → LRC / SRT
字幕   → 解析 ──────→ [矫正] → [翻译] → LRC / SRT
```

## 从源码运行

运行环境：Windows 10/11 x64、Python 3.10+；仅在运行或构建桌面界面时需要 Flutter SDK。

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

## 本地资源与 Git 策略

仓库只保存源码、文档和小型配置。以下资源由使用者自行放置，已被 `.gitignore` 排除：

| 资源 | 放置位置 |
| --- | --- |
| ffmpeg、ffprobe | `bin/ffmpeg/` |
| CrispASR、模型与 aligner | `bin/crispasr/` |
| llama-server 和本地模型（可选） | `bin/llama/` |

每个 `bin/` 子目录中保留的 `README.md` 说明资源用途。若未内置 ffmpeg，程序会尝试使用系统 `PATH` 中的版本；只处理已有字幕时不需要 CrispASR。

同样不会提交 API 设置和密钥（`engine/data/settings.json`、`.env*`）、任务工作目录、Flutter/Dart 缓存、手工测试资料、发布包及本机构建辅助文件。模型页打开时，API 地址、模型名和 API Key 均为空，需在本机填写并保存。

## 目录说明

```text
app/                 Flutter Windows 界面
engine/              Python 服务、HTTP API 与处理管线
engine/GalTransl/    内置 GalTransl、插件、字典和翻译规范
bin/                 本地可执行文件与模型（不提交）
docs/                开发与功能说明
output/              默认导出目录（不提交）
```

实现位置与接口索引见 [功能索引](docs/功能索引.md)。

## 许可

[GPL-3.0](LICENSE)。内置的 GalTransl 及其他第三方组件仍受各自许可证约束。
