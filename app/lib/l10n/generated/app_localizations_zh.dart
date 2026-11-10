// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get engineConnecting => '正在连接 engine…';

  @override
  String get engineConnected => 'engine 已连接';

  @override
  String engineStartHelp(Object arg1) {
    return '$arg1，请手动运行 python engine/server.py';
  }

  @override
  String get engineStartFailed => '未能启动 engine';

  @override
  String toolDetectionFailed(Object arg1) {
    return '工具检测失败：$arg1';
  }

  @override
  String get addFilesFirst => '请先添加文件';

  @override
  String get jobStarted => '任务已开始';

  @override
  String jobSubmitError(Object arg1) {
    return '提交任务失败：$arg1';
  }

  @override
  String get jobStopping => '正在停止任务…';

  @override
  String get jobStopRequested => '已请求停止任务，正在等待当前阶段结束';

  @override
  String get jobPausedMessage => '任务已暂存';

  @override
  String jobEnded(Object arg1) {
    return '任务结束：$arg1';
  }

  @override
  String get eventTimeoutRetry => '等待 engine 事件超时，将继续轮询';

  @override
  String pollFailed(Object arg1) {
    return '轮询失败: $arg1';
  }

  @override
  String get jobResumed => '任务继续处理中';

  @override
  String get showingKikoetaLogs => '正在显示由 kikoeta 发起的任务日志';

  @override
  String get showWindow => '显示窗口';

  @override
  String get stopTask => '停止任务';

  @override
  String get exitApp => '退出';

  @override
  String get activeTaskTitle => '任务正在运行';

  @override
  String get closeActiveTask => '关闭窗口将停止当前任务，确定要关闭吗？';

  @override
  String get cancel => '取消';

  @override
  String get confirmClose => '确定关闭';

  @override
  String exitSaveFailed(Object arg1) {
    return '设置保存失败，尚未退出：$arg1';
  }

  @override
  String autoSaveFailed(Object arg1) {
    return '自动保存失败，已留在当前页面：$arg1';
  }

  @override
  String get recent => '最近';

  @override
  String get tasks => '任务';

  @override
  String get models => '模型';

  @override
  String get asrParameters => '听写参数';

  @override
  String get modelParameters => '模型参数';

  @override
  String get dictionaries => '字典';

  @override
  String get output => '输出';

  @override
  String get settings => '设置';

  @override
  String get gptDictionary => 'GPT 字典';

  @override
  String get postTranslation => '译后';

  @override
  String get preTranslation => '译前';

  @override
  String dictionaryReadFailed(Object arg1) {
    return '无法读取字典：$arg1';
  }

  @override
  String get dictionarySaved => '字典已保存';

  @override
  String dictionaryRefreshFailed(Object arg1) {
    return '字典已保存，但刷新失败：$arg1';
  }

  @override
  String get dictionaryDescription =>
      '直接使用 GalTransl 内置 Dict。点击条目会在 kikoeta-transl 内置编辑器中打开。';

  @override
  String dictionariesFound(Object arg1) {
    return '已刷新，发现 $arg1 个字典';
  }

  @override
  String refreshFailed(Object arg1) {
    return '刷新失败：$arg1';
  }

  @override
  String get refreshDictionaries => '刷新字典';

  @override
  String get noDictionaries => '未找到字典文件';

  @override
  String dictionaryEntryCount(Object arg1) {
    return '$arg1 条 · 点击编辑';
  }

  @override
  String saveFailed(Object arg1) {
    return '保存失败：$arg1';
  }

  @override
  String get saving => '保存中…';

  @override
  String get save => '保存';

  @override
  String get modelSettingsSaved => '模型设置已保存';

  @override
  String get noAsrModels => '未扫描到 ASR 模型';

  @override
  String noAsrModelsIn(Object arg1) {
    return '未扫描到 ASR 模型：$arg1';
  }

  @override
  String asrModelsFound(Object arg1) {
    return '已扫描到 $arg1 个 ASR 模型';
  }

  @override
  String asrScanFailed(Object arg1) {
    return 'ASR 模型刷新失败：$arg1';
  }

  @override
  String get noLlamaModels => '未扫描到 Llama 模型';

  @override
  String noLlamaModelsIn(Object arg1) {
    return '未扫描到 Llama 模型：$arg1';
  }

  @override
  String llamaModelsFound(Object arg1) {
    return '已扫描到 $arg1 个 Llama 模型';
  }

  @override
  String llamaScanFailed(Object arg1) {
    return 'Llama 模型刷新失败：$arg1';
  }

  @override
  String modelPathMissing(Object arg1) {
    return '未获取到 $arg1 模型路径';
  }

  @override
  String modelPathNotFound(Object arg1, Object arg2) {
    return '$arg1 模型路径不存在：$arg2';
  }

  @override
  String modelPathOpenFailed(Object arg1, Object arg2) {
    return '无法打开 $arg1 模型路径：$arg2';
  }

  @override
  String get apiUrlRequired => '请先填写 API 地址';

  @override
  String modelsFetched(Object arg1) {
    return '已获取 $arg1 个模型';
  }

  @override
  String modelListFailed(Object arg1) {
    return '模型列表获取失败：$arg1';
  }

  @override
  String get modelFile => '模型文件';

  @override
  String get asrModelHint => 'bin/crispasr 下的 gguf 文件名';

  @override
  String get sourceLanguage => '源语言';

  @override
  String get scanning => '正在扫描…';

  @override
  String get queryModels => '查询模型列表';

  @override
  String get openModelPath => '打开模型路径';

  @override
  String get localLlama => '本地 Llama';

  @override
  String get localLlamaDescription =>
      '本项目以单模型模式运行 llama-server，同一时间只挂载一个 GGUF 模型。矫正和翻译选择“本地”时，将共同使用此处选择的模型。切换模型后，llama-server 会在下一次本地任务开始前重新启动。';

  @override
  String get llamaModelHint => 'bin/llama 下的 GGUF 文件名';

  @override
  String get fixedPort => '固定端口';

  @override
  String get correction => '矫正';

  @override
  String get connectionMode => '连接方式';

  @override
  String get online => '在线';

  @override
  String get sharedModel => '共享模型';

  @override
  String get noModelSelected => '尚未选择模型';

  @override
  String get apiUrl => 'API 地址';

  @override
  String get modelName => '模型名';

  @override
  String get querying => '正在查询…';

  @override
  String get translation => '翻译';

  @override
  String get translator => '翻译器';

  @override
  String get indexCompatibility => 'Index-Translate 兼容模式';

  @override
  String get indexCompatibilityDescription => '使用官方脚本的请求标识和思考参数格式，并固定关闭思考模式。';

  @override
  String get openAiUrl => 'OpenAI 兼容地址';

  @override
  String get targetLanguage => '目标语言';

  @override
  String get modelParametersSaved => '模型参数已保存';

  @override
  String get modelParametersDescription => '配置矫正模型与翻译模型的提示词及请求参数。';

  @override
  String get correctionPrompt => '补充校对要求（可选）';

  @override
  String get correctionPromptHint => '内置规则始终生效；含混内容保留原文，并写入矫正记录供回听';

  @override
  String get enableThinking => '启用思考/推理';

  @override
  String get thinkingDisabledDescription =>
      '关闭后请求会发送 thinking.type=disabled（接口支持时生效）';

  @override
  String get promptMode => 'Prompt 工作模式';

  @override
  String get appendPrompt => '衔接到默认提示词尾部';

  @override
  String get overwritePrompt => '直接覆盖默认提示词';

  @override
  String get translationPrompt => '翻译 Prompt';

  @override
  String get translationPromptHint => '留空则不修改默认提示词';

  @override
  String get contextSentences => '上下文句数';

  @override
  String get batchSentences => '单次翻译句数';

  @override
  String get tokenLimit => 'Token 上限';

  @override
  String get indexThinkingDisabled => 'Index 兼容模式下固定关闭思考。';

  @override
  String get targetLrc => '目标 LRC';

  @override
  String get targetLrcDescription => '单语歌词，kikoeta 优先匹配';

  @override
  String get targetSrt => '目标 SRT';

  @override
  String get targetSrtDescription => '单语字幕';

  @override
  String get bilingualLrc => '双语 LRC';

  @override
  String get translationFirstDescription => '同一文件内译文 + 原文';

  @override
  String get bilingualSrt => '双语 SRT';

  @override
  String get sourceTargetLrc => '原文 + 目标 LRC';

  @override
  String get sourceFirstDescription => '同一文件内原文 + 译文';

  @override
  String get sourceTargetSrt => '原文 + 目标 SRT';

  @override
  String get outputSettingsSaved => '输出设置已保存';

  @override
  String get readingLyricsCache => '正在读取歌词缓存…';

  @override
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3) {
    return '正在推送 $arg1/$arg2：$arg3';
  }

  @override
  String get noLyricsCacheToPush => '暂无可推送的 Kikoeta 歌词缓存';

  @override
  String cachePushCompleted(Object arg1, Object arg2) {
    return '推送完成：成功 $arg1 个，失败 $arg2 个';
  }

  @override
  String cachePushFailed(Object arg1) {
    return '推送未完成：$arg1';
  }

  @override
  String get files => '文件';

  @override
  String get outputDirectory => '输出目录';

  @override
  String get outputDirectoryHint => '留空则输出到源文件所在目录';

  @override
  String get chooseDirectory => '选择目录';

  @override
  String get useSourceDirectory => '使用源文件目录';

  @override
  String get format => '格式';

  @override
  String get outputFormat => '输出格式';

  @override
  String get llsSyncTitle => '来自 Kikoeta 的翻译请求，产物同步上传到 Kikoeta-LLS';

  @override
  String get llsSyncDescription => '任务成功完成后上传歌词；本地任务不受影响';

  @override
  String get llsUrl => 'Kikoeta-LLS 地址（HTTP/HTTPS）';

  @override
  String get llsUrlHint => '留空使用本机 http://127.0.0.1:2378';

  @override
  String get uploadAuthentication => '上传验证方式';

  @override
  String get twelveCharacterKey => '12 位密钥';

  @override
  String get separateCredentials => '独立账号和密码';

  @override
  String get uploadKey => '上传密钥';

  @override
  String get uploadKeyHint => '在 Kikoeta-LLS 设置页生成或手动设置 12 位密钥';

  @override
  String get uploadUsername => '上传账号';

  @override
  String get uploadPassword => '上传密码';

  @override
  String get lyricsCache => '歌词缓存';

  @override
  String get lyricsCacheDescription =>
      '将最近 5 次 Kikoeta 任务中保留的 LRC 缓存推送到 LLS。使用上方地址和验证配置，无需开启自动同步。同名歌词会覆盖，推送后保留本地缓存。';

  @override
  String get pushingCache => '正在推送…';

  @override
  String get pushCacheToLls => '将缓存推送到 LLS';

  @override
  String get viewFailureDetails => '查看失败详情';

  @override
  String get asrPresetSaved => '听写预设已保存';

  @override
  String presetSwitchFailed(Object arg1) {
    return '切换预设失败：$arg1';
  }

  @override
  String get asrParametersDescription => '媒体听写使用的 CrispASR 参数。字幕输入不会走到这一步。';

  @override
  String get basicSegmentation => '基础与分段';

  @override
  String get startOffsetMs => '起始偏移（毫秒）';

  @override
  String get segmentOffset => '起始片段偏移';

  @override
  String get processingDurationMs => '处理时长（毫秒）';

  @override
  String get zeroMeansAll => '0 表示全部';

  @override
  String get maxTextContext => '最大文本上下文';

  @override
  String get maxSegmentLength => '最大片段长度';

  @override
  String get chunkSecondsWithoutVad => '无 VAD 时分段秒数';

  @override
  String get chunkOverlapSeconds => '分段重叠秒数';

  @override
  String get forceAligner => '强制 Aligner';

  @override
  String get splitOnPunctuation => '按标点切分';

  @override
  String get splitOnWord => '按单词切分';

  @override
  String get vadAndPunctuation => 'VAD 与标点';

  @override
  String get disablePunctuation => '禁用标点';

  @override
  String get maxSpeechSeconds => '最大语音时长（秒）';

  @override
  String get minSilenceMs => '最小静音（毫秒）';

  @override
  String get vadModel => 'VAD 模型';

  @override
  String get vadModelHint => '可输入模型别名或路径';

  @override
  String get vadThreshold => 'VAD 阈值';

  @override
  String get hotwords => '热词（逗号分隔）';

  @override
  String get recognitionSensitivity => '识别敏感度';

  @override
  String get punctuationModel => '标点模型';

  @override
  String get leaveEmptyForDefault => '留空使用默认';

  @override
  String get truecaseModel => '大小写模型';

  @override
  String get truecaseModelHint => 'auto 或模型路径';

  @override
  String get flushSrtEveryN => '每 N 段刷新 SRT';

  @override
  String get flushSrtHint => '1 表示逐段输出日志';

  @override
  String get decoding => '解码';

  @override
  String get bestOf => '候选数 best-of';

  @override
  String get audioContext => '音频上下文';

  @override
  String get wordTimestampThreshold => '词时间戳阈值';

  @override
  String get entropyThreshold => '熵阈值';

  @override
  String get logProbabilityThreshold => '对数概率阈值';

  @override
  String get noSpeechThreshold => '无语音阈值';

  @override
  String get randomSeed => '随机种子';

  @override
  String get disableTemperatureFallback => '禁用温度回退';

  @override
  String get device => '设备';

  @override
  String get disableGpu => '禁用 GPU';

  @override
  String get threads => '线程数';

  @override
  String get processors => '处理器数';

  @override
  String get gpuDeviceIndex => 'GPU 设备编号';

  @override
  String get gpuBackend => 'GPU 后端';

  @override
  String get advancedTemplate => '高级模板';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get editCommandTemplate => '编辑命令模板';

  @override
  String get fullCommandTemplate => '完整命令模板';

  @override
  String get commandTemplateHint => '根据上方参数实时生成；可手动编辑后保存';

  @override
  String get commandTemplateDescription => '手动编辑后保存会解析参数；未知参数保留在模板中。';

  @override
  String get fileNotFound => '文件不存在';

  @override
  String openFileFailed(Object arg1) {
    return '打开文件失败：$arg1';
  }

  @override
  String get deleteTranslationCacheTitle => '删除翻译缓存？';

  @override
  String get deleteTranslationCacheDescription =>
      '仅删除此任务的 GalTransl 工作缓存；已导出的成果文件和 Kikoeta 歌词同步缓存不会删除。';

  @override
  String get deleteCache => '删除缓存';

  @override
  String cacheFreed(Object arg1) {
    return '已清理 $arg1 翻译缓存';
  }

  @override
  String cleanupFailed(Object arg1) {
    return '清理失败：$arg1';
  }

  @override
  String get deleteRecentTitle => '删除这条最近记录？';

  @override
  String get deleteRecentDescription =>
      '将删除此任务的工作文件和缓存，并从最近列表移除记录。已导出的成果文件会保留。';

  @override
  String get deleteRecord => '删除记录';

  @override
  String get recordDeleted => '记录已删除，成果文件已保留';

  @override
  String deleteFailed(Object arg1) {
    return '删除失败：$arg1';
  }

  @override
  String get deleteAllRecentTitle => '删除全部最近记录？';

  @override
  String deleteAllRecentDescription(Object arg1) {
    return '将删除当前 $arg1 条记录对应的工作文件和缓存。已导出的成果文件会保留。';
  }

  @override
  String get deleteAll => '全部删除';

  @override
  String recordsDeleted(Object arg1) {
    return '已删除 $arg1 条记录，成果文件已保留';
  }

  @override
  String get legacyTask => '旧任务';

  @override
  String get recentDescription => '最近的翻译任务与 GalTransl 工作缓存。清理缓存不会删除导出的文件。';

  @override
  String get deleteAllRecords => '一键删除所有记录';

  @override
  String get refresh => '刷新';

  @override
  String get loadFailed => '加载失败';

  @override
  String get translationHistory => '翻译记录';

  @override
  String get noTranslationCache => '暂无翻译缓存';

  @override
  String get kikoetaSourceSuffix => ' · 来自 Kikoeta';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusCancelled => '已取消';

  @override
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4) {
    return '$arg1 · $arg2$arg3 · 缓存 $arg4';
  }

  @override
  String get clearing => '清理中';

  @override
  String get deleteRecordKeepOutput => '删除记录（保留成果文件）';

  @override
  String get noLyricsOutput => '暂无可显示的成品歌词';

  @override
  String get open => '打开';

  @override
  String get fileMoved => '文件已移走';

  @override
  String get invalidRemoteCredentials => '远程用户名或密码无效';

  @override
  String get remoteRestartFailed => '远程服务重启失败';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get remoteCredentialsRequired => '远程用户名和密码不能为空';

  @override
  String get remoteUsernameColon => '远程用户名不能包含冒号';

  @override
  String get remoteCredentialsReset => '远程账密已重置为 admin / kikoeta';

  @override
  String get toolsRefreshed => '已刷新工具检测';

  @override
  String get releaseMissingVersion => 'GitHub Release 未提供版本号';

  @override
  String githubStatus(Object arg1) {
    return 'GitHub 返回 $arg1';
  }

  @override
  String releaseFeedStatus(Object arg1) {
    return 'GitHub API 返回 403，Release Feed 返回 $arg1';
  }

  @override
  String get releaseFeedEmpty => 'Release Feed 中没有发布版本';

  @override
  String get releaseFeedMissingVersion => 'Release Feed 未提供版本号';

  @override
  String get invalidVersion => '版本号格式无效';

  @override
  String updateAvailable(Object arg1, Object arg2) {
    return '发现新版本 $arg1（当前 $arg2）';
  }

  @override
  String alreadyLatest(Object arg1) {
    return '当前已是最新版本（$arg1）';
  }

  @override
  String updateCheckFailed(Object arg1) {
    return '检查更新失败：$arg1';
  }

  @override
  String get tools => '工具';

  @override
  String get notDetected => '未检测';

  @override
  String get executableNotFound => '未找到可执行文件';

  @override
  String get paths => '路径';

  @override
  String get ffmpegPath => 'ffmpeg 路径';

  @override
  String get crispAsrDirectory => 'CrispASR 目录';

  @override
  String get httpProxy => 'HTTP 代理';

  @override
  String get chooseCrispAsrDirectory => '选择 CrispASR 目录';

  @override
  String get interfaceAndService => '界面与服务';

  @override
  String get theme => '主题';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get allowRemoteAccess => '允许远程访问';

  @override
  String get remoteListenAll => '服务监听 0.0.0.0:2370';

  @override
  String get remoteListenLocal => '服务仅监听 127.0.0.1:2370';

  @override
  String get remoteAuthentication => '远程身份验证';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get resetRemoteCredentials => '重置默认账密';

  @override
  String get reset => '重置';

  @override
  String get about => '关于';

  @override
  String get repository => '项目仓库';

  @override
  String get checkingUpdate => '正在检查…';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get exportLogs => '导出日志';

  @override
  String get logsExported => '日志已导出';

  @override
  String logExportFailed(Object arg1) {
    return '日志导出失败：$arg1';
  }

  @override
  String get statusQueued => '待处理';

  @override
  String get statusRunning => '处理中';

  @override
  String get statusPausing => '正在暂存';

  @override
  String get statusPaused => '已暂存';

  @override
  String get statusCancelling => '正在取消';

  @override
  String get processingStages => '处理阶段';

  @override
  String get transcodeAndAsr => '转码 + ASR';

  @override
  String get transcodeDescription => '音频 / 视频必做；字幕输入自动跳过';

  @override
  String get fixed => '固定';

  @override
  String get correctionStageDescription => '只修听写，不翻译';

  @override
  String get translationStageDescription => '使用已配置的翻译器';

  @override
  String get inputFiles => '输入文件';

  @override
  String get clearFileList => '清空列表';

  @override
  String get dropFilesHint => '拖入音视频或字幕，或点击选择';

  @override
  String selectedFiles(Object arg1) {
    return '已选择 $arg1 个文件，点击继续添加';
  }

  @override
  String get removeFile => '移除文件';

  @override
  String get submitting => '正在提交…';

  @override
  String get stopping => '正在停止…';

  @override
  String get stopWorkflow => '停止工作流';

  @override
  String get startProcessing => '开始处理';

  @override
  String get currentWorkflow => '当前工作流';

  @override
  String get fromKikoeta => '来自 Kikoeta';

  @override
  String get localTask => '本地任务';

  @override
  String get logs => '日志';

  @override
  String get noLogs => '尚无日志';

  @override
  String get pythonNotFound => '未找到可用的 Python 3 解释器';

  @override
  String get engineScriptNotFound => '未找到 engine/server.py';

  @override
  String pythonStartFailed(Object arg1) {
    return '无法启动 Python：$arg1';
  }

  @override
  String get engineTimeout => '等待 engine 响应超时';

  @override
  String engineTimeoutDetails(Object arg1) {
    return '等待 engine 响应超时：$arg1';
  }

  @override
  String engineExitedCode(Object arg1) {
    return 'engine 已退出（退出码 $arg1）';
  }

  @override
  String engineExitedDetails(Object arg1) {
    return 'engine 已退出：$arg1';
  }

  @override
  String get jobSubmitFailed => '提交任务失败';

  @override
  String get recentLoadFailed => '加载最近任务失败';

  @override
  String get cacheClearFailed => '清理缓存失败';

  @override
  String get recentDeleteFailed => '删除最近记录失败';

  @override
  String get lyricsCacheLoadFailed => '加载歌词缓存失败';

  @override
  String get lyricsCachePushFailed => '推送歌词缓存失败';

  @override
  String get ffmpegNotFound => '未找到 ffmpeg。请将 ffmpeg.exe 放到 bin/ffmpeg/bin';

  @override
  String get autoDetectLanguage => 'auto · 自动检测';

  @override
  String get forNovelTranslator => 'ForNovel · 小说 / 其他文本';

  @override
  String get galtranslSakuraTranslator => 'galtransl-v3 · Sakura 接口';

  @override
  String get sakuraTranslator => 'sakura-v1.0 · Sakura 接口';

  @override
  String get presetNameRequired => '请输入预设名称';

  @override
  String get presetNameExists => '名称已存在，请使用其他名称';

  @override
  String get saveAsrPresetAs => '另存听写预设';

  @override
  String get presetName => '预设名称';

  @override
  String get comboInputHint => '输入或从列表选择';

  @override
  String get openList => '打开列表';

  @override
  String get noPresetOptions => '暂无预置选项，可直接输入';

  @override
  String get saveAs => '另存为';

  @override
  String get presets => '预设';

  @override
  String get asrPreset => '听写预设';

  @override
  String basePresetLabel(Object arg1) {
    return '$arg1（基础）';
  }

  @override
  String get basePresetDescription => '基础预设修改后需另存；离页时自动保存为自定义预设。';

  @override
  String get restorePreset => '恢复预设';

  @override
  String get uiLanguage => '界面语言';

  @override
  String get llamaStopped => '已停止';

  @override
  String get llamaStarting => '正在启动';

  @override
  String get llamaReady => '已就绪';

  @override
  String get crispCheckUpdate => '检测更新';

  @override
  String get crispQuickUpdate => '快速更新';

  @override
  String get crispDownload => '下载';

  @override
  String get crispReleaseTitle => 'CrispASR 发行版本';

  @override
  String crispVersions(Object current, Object latest) {
    return '当前：$current · 最新：$latest';
  }

  @override
  String get crispInstalled => 'CrispASR 已更新';

  @override
  String get crispRecommended => '推荐';

  @override
  String get crispAlreadyLatest => '当前已是最新版本，可重装或更换运行后端。';

  @override
  String get crispNoPackage => '此发行版没有适合当前系统架构的完整安装包。';

  @override
  String get crispPreserveModels => '仅更新程序及运行库，保留本地模型。';

  @override
  String get crispDownloading => '正在下载';

  @override
  String get crispExtracting => '正在解压与验证';

  @override
  String get crispInstalling => '正在安装';

  @override
  String get crispCancelling => '正在取消';

  @override
  String get crispInstall => '下载并安装';

  @override
  String get crispCpuHint => 'CPU：无需独立显卡，兼容性好；x86 版本需要 AVX2，通常比 GPU 慢。';

  @override
  String get crispLegacyHint => '旧 CPU：支持缺少 AVX2 的处理器，速度较慢。';

  @override
  String get crispAvx512Hint => 'AVX-512：适合支持 AVX-512 的 CPU，不兼容较旧处理器。';

  @override
  String get crispCudaHint => 'CUDA 12.8：NVIDIA 专用加速，通常优先选择；需兼容驱动，已含运行库。';

  @override
  String get crispCuda126Hint =>
      'CUDA 12.6：适合驱动较旧的 NVIDIA 显卡，不支持 RTX 50 系列；已含运行库。';

  @override
  String get crispCuda13Hint =>
      'CUDA 13：适合 Turing 及更新 NVIDIA 显卡和新驱动；已含运行库，不保证比 CUDA 12 更快。';

  @override
  String get crispVulkanHint =>
      'Vulkan：覆盖 AMD、Intel 和 NVIDIA 显卡，包较小；速度及兼容性取决于模型和驱动，Linux 缺少 Vulkan 时无法启动。';

  @override
  String get crispMetalHint => 'Metal：使用 Apple 芯片 GPU 加速，无需 CUDA。';

  @override
  String get crispHipHint => 'ROCm：用于 AMD GPU，ROCm 6 与 ROCm 7 必须选择对应的包。';

  @override
  String get crispCudaMissing =>
      '检测到 NVIDIA 显卡，但未检测到可用 CUDA。建议检查驱动，并下载适配版本的 CUDA。';

  @override
  String get crispDownloadCuda => '下载 CUDA';

  @override
  String get crispChooseCuda => '如何选择 CUDA';

  @override
  String get crispChooseCudaHelp =>
      '将显卡型号和系统版本发送给 AI，让 AI 帮你推荐合适的 CUDA 版本。完整 CUDA 发行包已包含运行库，通常无需另装工具包。';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get crispCheckUpdate => '检测更新';

  @override
  String get crispQuickUpdate => '快速更新';

  @override
  String get crispDownload => '下载';

  @override
  String get crispReleaseTitle => 'CrispASR 发行版本';

  @override
  String crispVersions(Object current, Object latest) {
    return '当前：$current · 最新：$latest';
  }

  @override
  String get crispInstalled => 'CrispASR 已更新';

  @override
  String get crispRecommended => '推荐';

  @override
  String get crispAlreadyLatest => '当前已是最新版本，可重装或更换运行后端。';

  @override
  String get crispNoPackage => '此发行版没有适合当前系统架构的完整安装包。';

  @override
  String get crispPreserveModels => '仅更新程序及运行库，保留本地模型。';

  @override
  String get crispDownloading => '正在下载';

  @override
  String get crispExtracting => '正在解压与验证';

  @override
  String get crispInstalling => '正在安装';

  @override
  String get crispCancelling => '正在取消';

  @override
  String get crispInstall => '下载并安装';

  @override
  String get crispCpuHint => 'CPU：无需独立显卡，兼容性好；x86 版本需要 AVX2，通常比 GPU 慢。';

  @override
  String get crispLegacyHint => '旧 CPU：支持缺少 AVX2 的处理器，速度较慢。';

  @override
  String get crispAvx512Hint => 'AVX-512：适合支持 AVX-512 的 CPU，不兼容较旧处理器。';

  @override
  String get crispCudaHint => 'CUDA 12.8：NVIDIA 专用加速，通常优先选择；需兼容驱动，已含运行库。';

  @override
  String get crispCuda126Hint =>
      'CUDA 12.6：适合驱动较旧的 NVIDIA 显卡，不支持 RTX 50 系列；已含运行库。';

  @override
  String get crispCuda13Hint =>
      'CUDA 13：适合 Turing 及更新 NVIDIA 显卡和新驱动；已含运行库，不保证比 CUDA 12 更快。';

  @override
  String get crispVulkanHint =>
      'Vulkan：覆盖 AMD、Intel 和 NVIDIA 显卡，包较小；速度及兼容性取决于模型和驱动，Linux 缺少 Vulkan 时无法启动。';

  @override
  String get crispMetalHint => 'Metal：使用 Apple 芯片 GPU 加速，无需 CUDA。';

  @override
  String get crispHipHint => 'ROCm：用于 AMD GPU，ROCm 6 与 ROCm 7 必须选择对应的包。';

  @override
  String get crispCudaMissing =>
      '检测到 NVIDIA 显卡，但未检测到可用 CUDA。建议检查驱动，并下载适配版本的 CUDA。';

  @override
  String get crispDownloadCuda => '下载 CUDA';

  @override
  String get crispChooseCuda => '如何选择 CUDA';

  @override
  String get crispChooseCudaHelp =>
      '将显卡型号和系统版本发送给 AI，让 AI 帮你推荐合适的 CUDA 版本。完整 CUDA 发行包已包含运行库，通常无需另装工具包。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get engineConnecting => '正在連線 engine…';

  @override
  String get engineConnected => 'engine 已連線';

  @override
  String engineStartHelp(Object arg1) {
    return '$arg1，請手動執行 python engine/server.py';
  }

  @override
  String get engineStartFailed => '未能啟動 engine';

  @override
  String toolDetectionFailed(Object arg1) {
    return '工具檢測失敗：$arg1';
  }

  @override
  String get addFilesFirst => '請先新增檔案';

  @override
  String get jobStarted => '任務已開始';

  @override
  String jobSubmitError(Object arg1) {
    return '提交任務失敗：$arg1';
  }

  @override
  String get jobStopping => '正在停止任務…';

  @override
  String get jobStopRequested => '已請求停止任務，正在等待當前階段結束';

  @override
  String get jobPausedMessage => '任務已暫存';

  @override
  String jobEnded(Object arg1) {
    return '任務結束：$arg1';
  }

  @override
  String get eventTimeoutRetry => '等待 engine 事件超時，將繼續輪詢';

  @override
  String pollFailed(Object arg1) {
    return '輪詢失敗: $arg1';
  }

  @override
  String get jobResumed => '任務繼續處理中';

  @override
  String get showingKikoetaLogs => '正在顯示由 kikoeta 發起的任務日誌';

  @override
  String get showWindow => '顯示視窗';

  @override
  String get stopTask => '停止任務';

  @override
  String get exitApp => '退出';

  @override
  String get activeTaskTitle => '任務正在執行';

  @override
  String get closeActiveTask => '關閉視窗將停止當前任務，確定要關閉嗎？';

  @override
  String get cancel => '取消';

  @override
  String get confirmClose => '確定關閉';

  @override
  String exitSaveFailed(Object arg1) {
    return '設定儲存失敗，尚未退出：$arg1';
  }

  @override
  String autoSaveFailed(Object arg1) {
    return '自動儲存失敗，已留在當前頁面：$arg1';
  }

  @override
  String get recent => '最近';

  @override
  String get tasks => '任務';

  @override
  String get models => '模型';

  @override
  String get asrParameters => '聽寫參數';

  @override
  String get modelParameters => '模型參數';

  @override
  String get dictionaries => '字典';

  @override
  String get output => '輸出';

  @override
  String get settings => '設定';

  @override
  String get gptDictionary => 'GPT 字典';

  @override
  String get postTranslation => '譯後';

  @override
  String get preTranslation => '譯前';

  @override
  String dictionaryReadFailed(Object arg1) {
    return '無法讀取字典：$arg1';
  }

  @override
  String get dictionarySaved => '字典已儲存';

  @override
  String dictionaryRefreshFailed(Object arg1) {
    return '字典已儲存，但重新整理失敗：$arg1';
  }

  @override
  String get dictionaryDescription =>
      '直接使用 GalTransl 內建 Dict。點選條目會在 kikoeta-transl 內建編輯器中開啟。';

  @override
  String dictionariesFound(Object arg1) {
    return '已重新整理，發現 $arg1 個字典';
  }

  @override
  String refreshFailed(Object arg1) {
    return '重新整理失敗：$arg1';
  }

  @override
  String get refreshDictionaries => '重新整理字典';

  @override
  String get noDictionaries => '未找到字典檔案';

  @override
  String dictionaryEntryCount(Object arg1) {
    return '$arg1 條 · 點選編輯';
  }

  @override
  String saveFailed(Object arg1) {
    return '儲存失敗：$arg1';
  }

  @override
  String get saving => '儲存中…';

  @override
  String get save => '儲存';

  @override
  String get modelSettingsSaved => '模型設定已儲存';

  @override
  String get noAsrModels => '未掃描到 ASR 模型';

  @override
  String noAsrModelsIn(Object arg1) {
    return '未掃描到 ASR 模型：$arg1';
  }

  @override
  String asrModelsFound(Object arg1) {
    return '已掃描到 $arg1 個 ASR 模型';
  }

  @override
  String asrScanFailed(Object arg1) {
    return 'ASR 模型重新整理失敗：$arg1';
  }

  @override
  String get noLlamaModels => '未掃描到 Llama 模型';

  @override
  String noLlamaModelsIn(Object arg1) {
    return '未掃描到 Llama 模型：$arg1';
  }

  @override
  String llamaModelsFound(Object arg1) {
    return '已掃描到 $arg1 個 Llama 模型';
  }

  @override
  String llamaScanFailed(Object arg1) {
    return 'Llama 模型重新整理失敗：$arg1';
  }

  @override
  String modelPathMissing(Object arg1) {
    return '未獲取到 $arg1 模型路徑';
  }

  @override
  String modelPathNotFound(Object arg1, Object arg2) {
    return '$arg1 模型路徑不存在：$arg2';
  }

  @override
  String modelPathOpenFailed(Object arg1, Object arg2) {
    return '無法開啟 $arg1 模型路徑：$arg2';
  }

  @override
  String get apiUrlRequired => '請先填寫 API 地址';

  @override
  String modelsFetched(Object arg1) {
    return '已獲取 $arg1 個模型';
  }

  @override
  String modelListFailed(Object arg1) {
    return '模型列表獲取失敗：$arg1';
  }

  @override
  String get modelFile => '模型檔案';

  @override
  String get asrModelHint => 'bin/crispasr 下的 gguf 檔名';

  @override
  String get sourceLanguage => '源語言';

  @override
  String get scanning => '正在掃描…';

  @override
  String get queryModels => '查詢模型列表';

  @override
  String get openModelPath => '開啟模型路徑';

  @override
  String get localLlama => '本地 Llama';

  @override
  String get localLlamaDescription =>
      '本專案以單模型模式執行 llama-server，同一時間只掛載一個 GGUF 模型。矯正和翻譯選擇“本地”時，將共同使用此處選擇的模型。切換模型後，llama-server 會在下一次本地任務開始前重新啟動。';

  @override
  String get llamaModelHint => 'bin/llama 下的 GGUF 檔名';

  @override
  String get fixedPort => '固定埠';

  @override
  String get correction => '矯正';

  @override
  String get connectionMode => '連線方式';

  @override
  String get online => '線上';

  @override
  String get sharedModel => '共享模型';

  @override
  String get noModelSelected => '尚未選擇模型';

  @override
  String get apiUrl => 'API 地址';

  @override
  String get modelName => '模型名';

  @override
  String get querying => '正在查詢…';

  @override
  String get translation => '翻譯';

  @override
  String get translator => '翻譯器';

  @override
  String get indexCompatibility => 'Index-Translate 相容模式';

  @override
  String get indexCompatibilityDescription => '使用官方指令碼的請求標識和思考參數格式，並固定關閉思考模式。';

  @override
  String get openAiUrl => 'OpenAI 相容地址';

  @override
  String get targetLanguage => '目標語言';

  @override
  String get modelParametersSaved => '模型參數已儲存';

  @override
  String get modelParametersDescription => '配置矯正模型與翻譯模型的提示詞及請求參數。';

  @override
  String get correctionPrompt => '補充校對要求（可選）';

  @override
  String get correctionPromptHint => '內建規則始終生效；含混內容保留原文，並寫入矯正記錄供回聽';

  @override
  String get enableThinking => '啟用思考/推理';

  @override
  String get thinkingDisabledDescription =>
      '關閉後請求會發送 thinking.type=disabled（介面支援時生效）';

  @override
  String get promptMode => 'Prompt 工作模式';

  @override
  String get appendPrompt => '銜接到預設提示詞尾部';

  @override
  String get overwritePrompt => '直接覆蓋預設提示詞';

  @override
  String get translationPrompt => '翻譯 Prompt';

  @override
  String get translationPromptHint => '留空則不修改預設提示詞';

  @override
  String get contextSentences => '上下文句數';

  @override
  String get batchSentences => '單次翻譯句數';

  @override
  String get tokenLimit => 'Token 上限';

  @override
  String get indexThinkingDisabled => 'Index 相容模式下固定關閉思考。';

  @override
  String get targetLrc => '目標 LRC';

  @override
  String get targetLrcDescription => '單語歌詞，kikoeta 優先匹配';

  @override
  String get targetSrt => '目標 SRT';

  @override
  String get targetSrtDescription => '單語字幕';

  @override
  String get bilingualLrc => '雙語 LRC';

  @override
  String get translationFirstDescription => '同一檔案內譯文 + 原文';

  @override
  String get bilingualSrt => '雙語 SRT';

  @override
  String get sourceTargetLrc => '原文 + 目標 LRC';

  @override
  String get sourceFirstDescription => '同一檔案內原文 + 譯文';

  @override
  String get sourceTargetSrt => '原文 + 目標 SRT';

  @override
  String get outputSettingsSaved => '輸出設定已儲存';

  @override
  String get readingLyricsCache => '正在讀取歌詞快取…';

  @override
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3) {
    return '正在推送 $arg1/$arg2：$arg3';
  }

  @override
  String get noLyricsCacheToPush => '暫無可推送的 Kikoeta 歌詞快取';

  @override
  String cachePushCompleted(Object arg1, Object arg2) {
    return '推送完成：成功 $arg1 個，失敗 $arg2 個';
  }

  @override
  String cachePushFailed(Object arg1) {
    return '推送未完成：$arg1';
  }

  @override
  String get files => '檔案';

  @override
  String get outputDirectory => '輸出目錄';

  @override
  String get outputDirectoryHint => '留空則輸出到原始檔所在目錄';

  @override
  String get chooseDirectory => '選擇目錄';

  @override
  String get useSourceDirectory => '使用原始檔目錄';

  @override
  String get format => '格式';

  @override
  String get outputFormat => '輸出格式';

  @override
  String get llsSyncTitle => '來自 Kikoeta 的翻譯請求，產物同步上傳到 Kikoeta-LLS';

  @override
  String get llsSyncDescription => '任務成功完成後上傳歌詞；本地任務不受影響';

  @override
  String get llsUrl => 'Kikoeta-LLS 地址（HTTP/HTTPS）';

  @override
  String get llsUrlHint => '留空使用本機 http://127.0.0.1:2378';

  @override
  String get uploadAuthentication => '上傳驗證方式';

  @override
  String get twelveCharacterKey => '12 位金鑰';

  @override
  String get separateCredentials => '獨立賬號和密碼';

  @override
  String get uploadKey => '上傳金鑰';

  @override
  String get uploadKeyHint => '在 Kikoeta-LLS 設定頁生成或手動設定 12 位金鑰';

  @override
  String get uploadUsername => '上傳賬號';

  @override
  String get uploadPassword => '上傳密碼';

  @override
  String get lyricsCache => '歌詞快取';

  @override
  String get lyricsCacheDescription =>
      '將最近 5 次 Kikoeta 任務中保留的 LRC 快取推送到 LLS。使用上方地址和驗證配置，無需開啟自動同步。同名歌詞會覆蓋，推送後保留本地快取。';

  @override
  String get pushingCache => '正在推送…';

  @override
  String get pushCacheToLls => '將快取推送到 LLS';

  @override
  String get viewFailureDetails => '檢視失敗詳情';

  @override
  String get asrPresetSaved => '聽寫預設已儲存';

  @override
  String presetSwitchFailed(Object arg1) {
    return '切換預設失敗：$arg1';
  }

  @override
  String get asrParametersDescription => '媒體聽寫使用的 CrispASR 參數。字幕輸入不會走到這一步。';

  @override
  String get basicSegmentation => '基礎與分段';

  @override
  String get startOffsetMs => '起始偏移（毫秒）';

  @override
  String get segmentOffset => '起始片段偏移';

  @override
  String get processingDurationMs => '處理時長（毫秒）';

  @override
  String get zeroMeansAll => '0 表示全部';

  @override
  String get maxTextContext => '最大文本上下文';

  @override
  String get maxSegmentLength => '最大片段長度';

  @override
  String get chunkSecondsWithoutVad => '無 VAD 時分段秒數';

  @override
  String get chunkOverlapSeconds => '分段重疊秒數';

  @override
  String get forceAligner => '強制 Aligner';

  @override
  String get splitOnPunctuation => '按標點切分';

  @override
  String get splitOnWord => '按單詞切分';

  @override
  String get vadAndPunctuation => 'VAD 與標點';

  @override
  String get disablePunctuation => '停用標點';

  @override
  String get maxSpeechSeconds => '最大語音時長（秒）';

  @override
  String get minSilenceMs => '最小靜音（毫秒）';

  @override
  String get vadModel => 'VAD 模型';

  @override
  String get vadModelHint => '可輸入模型別名或路徑';

  @override
  String get vadThreshold => 'VAD 閾值';

  @override
  String get hotwords => '熱詞（逗號分隔）';

  @override
  String get recognitionSensitivity => '識別敏感度';

  @override
  String get punctuationModel => '標點模型';

  @override
  String get leaveEmptyForDefault => '留空使用預設';

  @override
  String get truecaseModel => '大小寫模型';

  @override
  String get truecaseModelHint => 'auto 或模型路徑';

  @override
  String get flushSrtEveryN => '每 N 段重新整理 SRT';

  @override
  String get flushSrtHint => '1 表示逐段輸出日誌';

  @override
  String get decoding => '解碼';

  @override
  String get bestOf => '候選數 best-of';

  @override
  String get audioContext => '音訊上下文';

  @override
  String get wordTimestampThreshold => '詞時間戳閾值';

  @override
  String get entropyThreshold => '熵閾值';

  @override
  String get logProbabilityThreshold => '對數機率閾值';

  @override
  String get noSpeechThreshold => '無語音閾值';

  @override
  String get randomSeed => '隨機種子';

  @override
  String get disableTemperatureFallback => '停用溫度回退';

  @override
  String get device => '裝置';

  @override
  String get disableGpu => '停用 GPU';

  @override
  String get threads => '執行緒數';

  @override
  String get processors => '處理器數';

  @override
  String get gpuDeviceIndex => 'GPU 裝置編號';

  @override
  String get gpuBackend => 'GPU 後端';

  @override
  String get advancedTemplate => '高階模板';

  @override
  String get restoreDefaults => '恢復預設';

  @override
  String get editCommandTemplate => '編輯命令模板';

  @override
  String get fullCommandTemplate => '完整命令模板';

  @override
  String get commandTemplateHint => '根據上方參數即時生成；可手動編輯後儲存';

  @override
  String get commandTemplateDescription => '手動編輯後儲存會解析參數；未知參數保留在模板中。';

  @override
  String get fileNotFound => '檔案不存在';

  @override
  String openFileFailed(Object arg1) {
    return '開啟檔案失敗：$arg1';
  }

  @override
  String get deleteTranslationCacheTitle => '刪除翻譯快取？';

  @override
  String get deleteTranslationCacheDescription =>
      '僅刪除此任務的 GalTransl 工作快取；已匯出的成果檔案和 Kikoeta 歌詞同步快取不會刪除。';

  @override
  String get deleteCache => '刪除快取';

  @override
  String cacheFreed(Object arg1) {
    return '已清理 $arg1 翻譯快取';
  }

  @override
  String cleanupFailed(Object arg1) {
    return '清理失敗：$arg1';
  }

  @override
  String get deleteRecentTitle => '刪除這條最近記錄？';

  @override
  String get deleteRecentDescription =>
      '將刪除此任務的工作檔案和快取，並從最近列表移除記錄。已匯出的成果檔案會保留。';

  @override
  String get deleteRecord => '刪除記錄';

  @override
  String get recordDeleted => '記錄已刪除，成果檔案已保留';

  @override
  String deleteFailed(Object arg1) {
    return '刪除失敗：$arg1';
  }

  @override
  String get deleteAllRecentTitle => '刪除全部最近記錄？';

  @override
  String deleteAllRecentDescription(Object arg1) {
    return '將刪除當前 $arg1 條記錄對應的工作檔案和快取。已匯出的成果檔案會保留。';
  }

  @override
  String get deleteAll => '全部刪除';

  @override
  String recordsDeleted(Object arg1) {
    return '已刪除 $arg1 條記錄，成果檔案已保留';
  }

  @override
  String get legacyTask => '舊任務';

  @override
  String get recentDescription => '最近的翻譯任務與 GalTransl 工作快取。清理快取不會刪除匯出的檔案。';

  @override
  String get deleteAllRecords => '一鍵刪除所有記錄';

  @override
  String get refresh => '重新整理';

  @override
  String get loadFailed => '載入失敗';

  @override
  String get translationHistory => '翻譯記錄';

  @override
  String get noTranslationCache => '暫無翻譯快取';

  @override
  String get kikoetaSourceSuffix => ' · 來自 Kikoeta';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusCancelled => '已取消';

  @override
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4) {
    return '$arg1 · $arg2$arg3 · 快取 $arg4';
  }

  @override
  String get clearing => '清理中';

  @override
  String get deleteRecordKeepOutput => '刪除記錄（保留成果檔案）';

  @override
  String get noLyricsOutput => '暫無可顯示的成品歌詞';

  @override
  String get open => '開啟';

  @override
  String get fileMoved => '檔案已移走';

  @override
  String get invalidRemoteCredentials => '遠端使用者名稱或密碼無效';

  @override
  String get remoteRestartFailed => '遠端服務重啟失敗';

  @override
  String get settingsSaved => '設定已儲存';

  @override
  String get remoteCredentialsRequired => '遠端使用者名稱和密碼不能為空';

  @override
  String get remoteUsernameColon => '遠端使用者名稱不能包含冒號';

  @override
  String get remoteCredentialsReset => '遠端賬密已重置為 admin / kikoeta';

  @override
  String get toolsRefreshed => '已重新整理工具檢測';

  @override
  String get releaseMissingVersion => 'GitHub Release 未提供版本號';

  @override
  String githubStatus(Object arg1) {
    return 'GitHub 返回 $arg1';
  }

  @override
  String releaseFeedStatus(Object arg1) {
    return 'GitHub API 返回 403，Release Feed 返回 $arg1';
  }

  @override
  String get releaseFeedEmpty => 'Release Feed 中沒有釋出版本';

  @override
  String get releaseFeedMissingVersion => 'Release Feed 未提供版本號';

  @override
  String get invalidVersion => '版本號格式無效';

  @override
  String updateAvailable(Object arg1, Object arg2) {
    return '發現新版本 $arg1（當前 $arg2）';
  }

  @override
  String alreadyLatest(Object arg1) {
    return '當前已是最新版本（$arg1）';
  }

  @override
  String updateCheckFailed(Object arg1) {
    return '檢查更新失敗：$arg1';
  }

  @override
  String get tools => '工具';

  @override
  String get notDetected => '未檢測';

  @override
  String get executableNotFound => '未找到執行檔';

  @override
  String get paths => '路徑';

  @override
  String get ffmpegPath => 'ffmpeg 路徑';

  @override
  String get crispAsrDirectory => 'CrispASR 目錄';

  @override
  String get httpProxy => 'HTTP 代理';

  @override
  String get chooseCrispAsrDirectory => '選擇 CrispASR 目錄';

  @override
  String get interfaceAndService => '介面與服務';

  @override
  String get theme => '主題';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightTheme => '淺色';

  @override
  String get darkTheme => '深色';

  @override
  String get allowRemoteAccess => '允許遠端訪問';

  @override
  String get remoteListenAll => '服務監聽 0.0.0.0:2370';

  @override
  String get remoteListenLocal => '服務僅監聽 127.0.0.1:2370';

  @override
  String get remoteAuthentication => '遠端身份驗證';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get resetRemoteCredentials => '重置預設賬密';

  @override
  String get reset => '重置';

  @override
  String get about => '關於';

  @override
  String get repository => '專案倉庫';

  @override
  String get checkingUpdate => '正在檢查…';

  @override
  String get checkForUpdates => '檢查更新';

  @override
  String get exportLogs => '匯出日誌';

  @override
  String get logsExported => '日誌已匯出';

  @override
  String logExportFailed(Object arg1) {
    return '日誌匯出失敗：$arg1';
  }

  @override
  String get statusQueued => '待處理';

  @override
  String get statusRunning => '處理中';

  @override
  String get statusPausing => '正在暫存';

  @override
  String get statusPaused => '已暫存';

  @override
  String get statusCancelling => '正在取消';

  @override
  String get processingStages => '處理階段';

  @override
  String get transcodeAndAsr => '轉碼 + ASR';

  @override
  String get transcodeDescription => '音訊 / 影片必做；字幕輸入自動跳過';

  @override
  String get fixed => '固定';

  @override
  String get correctionStageDescription => '只修聽寫，不翻譯';

  @override
  String get translationStageDescription => '使用已配置的翻譯器';

  @override
  String get inputFiles => '輸入檔案';

  @override
  String get clearFileList => '清空列表';

  @override
  String get dropFilesHint => '拖入音影片或字幕，或點選選擇';

  @override
  String selectedFiles(Object arg1) {
    return '已選擇 $arg1 個檔案，點選繼續新增';
  }

  @override
  String get removeFile => '移除檔案';

  @override
  String get submitting => '正在提交…';

  @override
  String get stopping => '正在停止…';

  @override
  String get stopWorkflow => '停止工作流';

  @override
  String get startProcessing => '開始處理';

  @override
  String get currentWorkflow => '當前工作流';

  @override
  String get fromKikoeta => '來自 Kikoeta';

  @override
  String get localTask => '本地任務';

  @override
  String get logs => '日誌';

  @override
  String get noLogs => '尚無日誌';

  @override
  String get pythonNotFound => '未找到可用的 Python 3 直譯器';

  @override
  String get engineScriptNotFound => '未找到 engine/server.py';

  @override
  String pythonStartFailed(Object arg1) {
    return '無法啟動 Python：$arg1';
  }

  @override
  String get engineTimeout => '等待 engine 響應超時';

  @override
  String engineTimeoutDetails(Object arg1) {
    return '等待 engine 響應超時：$arg1';
  }

  @override
  String engineExitedCode(Object arg1) {
    return 'engine 已退出（退出碼 $arg1）';
  }

  @override
  String engineExitedDetails(Object arg1) {
    return 'engine 已退出：$arg1';
  }

  @override
  String get jobSubmitFailed => '提交任務失敗';

  @override
  String get recentLoadFailed => '載入最近任務失敗';

  @override
  String get cacheClearFailed => '清理快取失敗';

  @override
  String get recentDeleteFailed => '刪除最近記錄失敗';

  @override
  String get lyricsCacheLoadFailed => '載入歌詞快取失敗';

  @override
  String get lyricsCachePushFailed => '推送歌詞快取失敗';

  @override
  String get ffmpegNotFound => '未找到 ffmpeg。請將 ffmpeg.exe 放到 bin/ffmpeg/bin';

  @override
  String get autoDetectLanguage => 'auto · 自動檢測';

  @override
  String get forNovelTranslator => 'ForNovel · 小說 / 其他文本';

  @override
  String get galtranslSakuraTranslator => 'galtransl-v3 · Sakura 介面';

  @override
  String get sakuraTranslator => 'sakura-v1.0 · Sakura 介面';

  @override
  String get presetNameRequired => '請輸入預設名稱';

  @override
  String get presetNameExists => '名稱已存在，請使用其他名稱';

  @override
  String get saveAsrPresetAs => '另存聽寫預設';

  @override
  String get presetName => '預設名稱';

  @override
  String get comboInputHint => '輸入或從列表選擇';

  @override
  String get openList => '開啟列表';

  @override
  String get noPresetOptions => '暫無預置選項，可直接輸入';

  @override
  String get saveAs => '另存為';

  @override
  String get presets => '預設';

  @override
  String get asrPreset => '聽寫預設';

  @override
  String basePresetLabel(Object arg1) {
    return '$arg1（基礎）';
  }

  @override
  String get basePresetDescription => '基礎預設修改後需另存；離頁時自動儲存為自定義預設。';

  @override
  String get restorePreset => '恢復預設';

  @override
  String get uiLanguage => '介面語言';

  @override
  String get llamaStopped => '已停止';

  @override
  String get llamaStarting => '正在啟動';

  @override
  String get llamaReady => '已就緒';

  @override
  String get crispCheckUpdate => '檢查更新';

  @override
  String get crispQuickUpdate => '快速更新';

  @override
  String get crispDownload => '下載';

  @override
  String get crispReleaseTitle => 'CrispASR 發行版本';

  @override
  String crispVersions(Object current, Object latest) {
    return '目前：$current · 最新：$latest';
  }

  @override
  String get crispInstalled => 'CrispASR 已更新';

  @override
  String get crispRecommended => '推薦';

  @override
  String get crispAlreadyLatest => '目前已是最新版本，可重新安裝或更換執行後端。';

  @override
  String get crispNoPackage => '此發行版沒有適合目前系統架構的完整安裝套件。';

  @override
  String get crispPreserveModels => '僅更新程式及執行階段，保留本機模型。';

  @override
  String get crispDownloading => '正在下載';

  @override
  String get crispExtracting => '正在解壓縮與驗證';

  @override
  String get crispInstalling => '正在安裝';

  @override
  String get crispCancelling => '正在取消';

  @override
  String get crispInstall => '下載並安裝';

  @override
  String get crispCpuHint => 'CPU：不需要獨立顯示卡，相容性佳；x86 版本需要 AVX2，通常比 GPU 慢。';

  @override
  String get crispLegacyHint => '舊 CPU：支援缺少 AVX2 的處理器，速度較慢。';

  @override
  String get crispAvx512Hint => 'AVX-512：適合支援 AVX-512 的 CPU，不相容較舊處理器。';

  @override
  String get crispCudaHint => 'CUDA 12.8：NVIDIA 專用加速，通常優先選擇；需要相容驅動程式，已含執行階段。';

  @override
  String get crispCuda126Hint =>
      'CUDA 12.6：適合驅動程式較舊的 NVIDIA 顯示卡，不支援 RTX 50 系列；已含執行階段。';

  @override
  String get crispCuda13Hint =>
      'CUDA 13：適合 Turing 及更新 NVIDIA 顯示卡和新驅動程式；已含執行階段，不保證比 CUDA 12 更快。';

  @override
  String get crispVulkanHint =>
      'Vulkan：涵蓋 AMD、Intel 和 NVIDIA 顯示卡，套件較小；速度及相容性取決於模型和驅動程式，Linux 缺少 Vulkan 時無法啟動。';

  @override
  String get crispMetalHint => 'Metal：使用 Apple 晶片 GPU 加速，不需要 CUDA。';

  @override
  String get crispHipHint => 'ROCm：用於 AMD GPU，ROCm 6 與 ROCm 7 必須選擇對應套件。';

  @override
  String get crispCudaMissing =>
      '偵測到 NVIDIA 顯示卡，但未偵測到可用 CUDA。建議檢查驅動程式，並下載適合的 CUDA 版本。';

  @override
  String get crispDownloadCuda => '下載 CUDA';

  @override
  String get crispChooseCuda => '如何選擇 CUDA';

  @override
  String get crispChooseCudaHelp =>
      '將顯示卡型號和系統版本傳送給 AI，讓 AI 幫你推薦適合的 CUDA 版本。完整 CUDA 發行套件已包含執行階段，通常不需要另裝工具包。';
}
