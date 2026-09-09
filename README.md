# Kikoeta Transl

![Kikoeta Transl logo](logo/logo.png)

Kikoeta 的 Windows 翻译伴侣：将音视频或已有字幕处理为带时间轴的歌词 / 字幕，并导出给 [kikoeta](https://github.com/chenflxs/kikoeta) 使用。

## 功能

- 导入音频、视频与 `SRT`、`LRC`、`VTT`、`ASS`、`SSA` 字幕。
- 媒体经 ffmpeg 转码后使用 CrispASR 听写；已有字幕保留原时间轴直接处理。
- 可选 OpenAI 兼容模型矫正听写文本，并通过内置 GalTransl 翻译。
- 导出目标语言或双语 `LRC` / `SRT`，可选写入 kikoeta 歌词库。
- 提供 Flutter Windows 界面、命令行和局域网任务 API。

```text
音视频 → 转码 → 听写 → [矫正] → [翻译] → LRC / SRT
字幕   → 解析 ──────→ [矫正] → [翻译] → LRC / SRT
```

## 运行环境

- Windows 10/11 x64
- Python 3.10+
- Flutter SDK（仅从源码运行桌面界面或构建发布包时需要）

以下大文件不纳入 Git，请放到 `bin/` 对应目录：

| 资源 | 目录 |
| --- | --- |
| ffmpeg、ffprobe | `bin/ffmpeg/` |
| CrispASR、模型、aligner | `bin/crispasr/` |
| llama-server 与本地模型（可选） | `bin/llama/` |

`bin/` 下的 README 说明了各资源的位置。没有内置 ffmpeg 时，程序会使用系统 `PATH` 中的 ffmpeg；仅处理已有字幕时不需要 CrispASR。

## 从源码运行

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

## 项目结构

```text
app/                 Flutter Windows 界面
engine/              Python 服务与处理管线
engine/GalTransl/    内置 GalTransl、插件和字典
bin/                 本地可执行文件与模型
docs/                架构文档
```

更多设计细节见 [架构方案](docs/架构方案.md)。

## 许可

[GPL-3.0](LICENSE)。内置的 GalTransl 及其他第三方组件仍受各自许可证约束。
