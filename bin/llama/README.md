# 本地 Llama 模型资源

将 Windows 版 `llama-server.exe`、所需 DLL 与本地 `.gguf` 模型放到本目录。下载入口：[llama.cpp Releases](https://github.com/ggml-org/llama.cpp/releases)。

- 在“模型”页刷新模型列表、选择模型，将矫正或翻译方式设为“本地 Llama”。两项都使用本地模型时共用所选模型。
- 模型扫描只读取目录顶层的 `.gguf`。分片模型需保留全部分片；模型列表只展示 `-00001-of-xxxxx.gguf` 入口。
- 可在“设置”页通过 `llama_dir` 改用其他目录；其中仍需提供 `llama-server.exe` 与模型文件。
- KT 按需启动单模型服务，固定监听 `127.0.0.1:18766`，OpenAI 兼容地址为 `http://127.0.0.1:18766/v1`。该端口用于内部模型调用，不是供 Kikoeta 连接的 `2370` 任务端口。
- 服务在工作流完成、失败、取消或暂存后释放；无需提前手动启动。仅使用在线模型时不需要本目录资源。

模型选择和显存说明见[项目 README](../../README.md)。各模型的能力与许可按对应模型发布页确认。
