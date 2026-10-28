# Kikoeru 源目录歌词写回

KT 可将 Kikoeta 远端任务生成的 LRC 可靠投递到独立的 Kikoeru 外挂。外挂将歌词放到对应音轨的同一目录，再请求 kikoeru 刷新曲目索引；不需要修改 kikoeru 程序或数据库。

## 配置

先在 kikoeru 所在机器或能访问其音声目录的机器运行外挂。外挂配置中的 `source_id` 是服务器的稳定名称，例如 `my-kikoeru`；它必须绑定固定的 kikoeru 地址及音声库目录映射。部署方法见外挂的 `sidecar/README.md`。

在 KT“输出”页启用 Kikoeru 写回，并填写：

| 配置 | 说明 |
| --- | --- |
| 外挂地址 | 外挂的 HTTP/HTTPS 基础地址，默认部署端口为 `2379`。 |
| 外挂密钥 | 外挂的 `KIKOERU_SIDECAR_TOKEN`，不是 kikoeru 的登录 JWT。 |
| 来源 ID | 与外挂配置中的来源名称一致。 |
| 媒体 URL 前缀 | 只有原始下载 URL 匹配此来源前缀的音轨才允许写回。 |

设置保存于 `engine/data/settings.json` 的 `output`：

```json
{
  "kikoeru_sync": true,
  "kikoeru_url": "http://127.0.0.1:2379",
  "kikoeru_token": "外挂接收密钥",
  "kikoeru_source_id": "my-kikoeru",
  "kikoeru_media_url_prefix": "http://127.0.0.1:8889/api/media/"
}
```

媒体前缀必须由用户明确指定，不能用作品号推断来源。公共服务、其他自建服务器以及不匹配前缀的音轨不会写入这个来源。若音频由 CDN、反向代理或卸载下载地址提供，应填写实际下载 URL 的可信前缀；多个服务共享同一个无法区分的地址时，需要客户端显式传递来源身份后再启用此功能。

## 投递行为

KT 为每个已经完成的音轨保存独立的投递记录和 LRC 内容。其他音轨失败、任务暂停或程序重启，不会依赖“最近五次歌词缓存”恢复写回。外挂暂时离线时，翻译结果仍保留，恢复后自动重试。

投递使用稳定的 `delivery_id`。重复发送同一条记录不会创建第二份歌词；同一目标已存在不同内容时，外挂报告冲突并保留原文件。重新翻译产生的不同内容也不会覆盖已有歌词。

KT 的待投递数据保存于 `engine/data/kikoeru-outbox.sqlite`，独立于最近五次歌词缓存。关闭自动写回会暂停投递，重新启用后继续；更改外挂地址、来源 ID 或媒体前缀会阻止旧记录改投。密钥从当前本机设置读取，轮换密钥无需更换投递身份。

外挂确认文件存在于 kikoeru 索引后，KT 记录写回结果。`selected` 表示服务端当前选中了这份歌词；`present_not_selected` 表示文件已进入索引，但当前可能选中了其他歌词，不能当作网页已经显示。已经打开的播放器不会由外挂强制刷新。

修改来源地址或目录映射时，旧投递不会自动改投到新来源。凭据可以轮换，来源变更需要重新核对旧任务。日志和投递状态不返回 LRC 正文或密钥。

## 状态与重试

“输出”页可查看投递状态并重试失败记录。对应的本机接口如下，只允许本地桌面端访问：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/api/kikoeru/deliveries` | 返回 `entries` 和尚未保存到投递队列的 `pending_jobs`。 |
| `POST` | `/api/kikoeru/deliveries/{delivery_id}/retry` | 重新处理指定记录；已经送达外挂的失败任务也会请求外挂重试。 |

`entries` 不包含歌词正文或密钥。`queued` 为待投递，`waiting` 为外挂处理中，`retry` 为临时错误后等待重试，`paused` 为自动写回关闭，`blocked` 为来源配置变化或凭据配置不完整，`completed` 为处理完成，`conflict` 为目标文件冲突，`failed` 为明确失败。`completed` 仍需结合 `result.match` 区分是否被服务端选中。

## 限制与验证

- 仅支持 kikoeru 本地可写音声库；OpenList 等远程媒体库需要独立的写入支持。
- 外挂需要目标文件系统支持硬链接，以避免覆盖已有文件或暴露半写入歌词。
- 当前 kikoeru v0.6.19 的 LRC 解析器按两位百分秒解释小数。外挂将 KT 的毫秒时间戳转换为百分秒，截断误差小于 10 毫秒。
- 路径采用精确音轨匹配；Unicode 规范等价名称冲突时拒绝写入。它不能防止其他可信进程在检查后恶意替换目录。

开发验证入口为 `engine/checks/kikoeru_sync_check.py` 和 `engine/checks/kikoeru_delivery_check.py`。后者需要工作区中存在独立外挂源码，验证 KT 的真实任务调度与外挂 HTTP 投递链；模型处理阶段使用确定性结果，避免消耗 ASR 或翻译服务。

Windows 发行版全链验证可运行 `python engine/checks/kikoeru_windows_smoke.py`。默认使用相邻 `kikoeru-ch` 工作区中的 `v0.6.19` 程序和 `sidecar`，也可设置 `KIKOERU_WINDOWS_EXE`、`KIKOERU_SIDECAR_DIR`。该脚本只启动程序副本，创建合成音频与全新数据，通过 KT 的真实远端任务接口下载、绑定来源并投递；成功后清理临时目录，失败时保留诊断文件。它验证文件写回、索引和服务端匹配，不验证真实模型输出质量或已经打开的网页播放器自动刷新。

实现参考 KT 已有的 Kikoeta-LLS 输出同步与工作流检查点，以及 kikoeru Windows v0.6.19 的作品路径、音轨索引和歌词匹配接口。
