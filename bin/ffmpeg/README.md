# FFmpeg 转码资源

将 Windows 版 `ffmpeg.exe` 与 `ffprobe.exe` 放在本目录，也支持 `bin/ffmpeg/bin/`。下载入口：[FFmpeg 下载页](https://ffmpeg.org/download.html)。如果发布包带有运行所需的 DLL，请一并保留。

也可将工具加入系统 `PATH`，或在“设置”页分别指定 `ffmpeg_path`、`ffprobe_path`。KT 会检查工具是否可运行；只放 `ffmpeg.exe` 而缺少可用的 `ffprobe.exe` 会报错。

音视频听写前统一转为 16 kHz、单声道、PCM WAV，转码中间文件在该文件处理结束后清理。已有 SRT、LRC、VTT、ASS、SSA 直接解析，不执行媒体转码。

完整安装与使用说明见[项目 README](../../README.md)。
