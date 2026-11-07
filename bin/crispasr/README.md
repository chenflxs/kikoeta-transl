# CrispASR 听写资源

将 Windows 发布包中的 `crispasr.exe` 及其运行依赖放到本目录；保留发布包所需的 DLL 和其他资源。下载入口：[CrispASR Releases](https://github.com/CrispStrobe/CrispASR/releases)。

- ASR 模型和强制对齐模型使用 `.gguf`，直接放在本目录，不放进子文件夹。模型列表按文件名中的 `aligner` / `alignment` 区分对齐模型。
- 在“模型”页查询模型列表，选择模型、backend 和源语言。默认 backend 为 `qwen3-1.7b`，默认源语言为 `ja`；应与实际模型及音频一致。
- 默认启用强制对齐，需要对齐模型；不使用时在“听写参数”页关闭。只处理已有字幕时不需要 CrispASR。
- 可在“设置”页通过 `crispasr_dir` 指定其他目录；可执行文件与模型扫描使用该目录。
- 命令模板使用 `$crispasr_executable`、`$model_file`、`$aligner_file`、`$backend`、`$language`、`$input_file`、`$output_file` 占位符。出现不支持的参数时，按所用 CrispASR 版本调整模板。

KT 先用 [FFmpeg](../ffmpeg/README.md) 转为 16 kHz 单声道 WAV，再执行听写；CrispASR 输入和临时 SRT 暂存于系统临时目录，结束后清理。模型下载示例及完整流程见[项目 README](../../README.md)。
