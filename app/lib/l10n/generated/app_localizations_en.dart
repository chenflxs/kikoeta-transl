// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get engineConnecting => 'Connecting to engine…';

  @override
  String get engineConnected => 'Engine connected';

  @override
  String engineStartHelp(Object arg1) {
    return '$arg1. Run python engine/server.py manually.';
  }

  @override
  String get engineStartFailed => 'Could not start engine';

  @override
  String toolDetectionFailed(Object arg1) {
    return 'Tool detection failed: $arg1';
  }

  @override
  String get addFilesFirst => 'Add files first';

  @override
  String get jobStarted => 'Task started';

  @override
  String jobSubmitError(Object arg1) {
    return 'Could not submit task: $arg1';
  }

  @override
  String get jobStopping => 'Stopping task…';

  @override
  String get jobStopRequested =>
      'Stop requested; waiting for the current stage to finish';

  @override
  String get jobPausedMessage => 'Task suspended';

  @override
  String jobEnded(Object arg1) {
    return 'Task ended: $arg1';
  }

  @override
  String get eventTimeoutRetry => 'Engine event timeout; polling will continue';

  @override
  String pollFailed(Object arg1) {
    return 'Polling failed: $arg1';
  }

  @override
  String get jobResumed => 'Task processing resumed';

  @override
  String get showingKikoetaLogs => 'Showing logs for a task from Kikoeta';

  @override
  String get showWindow => 'Show window';

  @override
  String get stopTask => 'Stop task';

  @override
  String get exitApp => 'Exit';

  @override
  String get activeTaskTitle => 'Task in progress';

  @override
  String get closeActiveTask =>
      'Closing the window will stop the current task. Close anyway?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmClose => 'Close';

  @override
  String exitSaveFailed(Object arg1) {
    return 'Settings could not be saved; app is still open: $arg1';
  }

  @override
  String autoSaveFailed(Object arg1) {
    return 'Autosave failed; stayed on this page: $arg1';
  }

  @override
  String get recent => 'Recent';

  @override
  String get tasks => 'Tasks';

  @override
  String get models => 'Models';

  @override
  String get asrParameters => 'ASR parameters';

  @override
  String get modelParameters => 'Model parameters';

  @override
  String get dictionaries => 'Dictionaries';

  @override
  String get output => 'Output';

  @override
  String get settings => 'Settings';

  @override
  String get gptDictionary => 'GPT dictionary';

  @override
  String get postTranslation => 'After translation';

  @override
  String get preTranslation => 'Before translation';

  @override
  String dictionaryReadFailed(Object arg1) {
    return 'Could not read dictionary: $arg1';
  }

  @override
  String get dictionarySaved => 'Dictionary saved';

  @override
  String dictionaryRefreshFailed(Object arg1) {
    return 'Dictionary saved, but refresh failed: $arg1';
  }

  @override
  String get dictionaryDescription =>
      'Uses GalTransl dictionaries directly. Select an entry to open it in the built-in editor.';

  @override
  String dictionariesFound(Object arg1) {
    return 'Refreshed; found $arg1 dictionaries';
  }

  @override
  String refreshFailed(Object arg1) {
    return 'Refresh failed: $arg1';
  }

  @override
  String get refreshDictionaries => 'Refresh dictionaries';

  @override
  String get noDictionaries => 'No dictionary files found';

  @override
  String dictionaryEntryCount(Object arg1) {
    return '$arg1 entries · Click to edit';
  }

  @override
  String saveFailed(Object arg1) {
    return 'Save failed: $arg1';
  }

  @override
  String get saving => 'Saving…';

  @override
  String get save => 'Save';

  @override
  String get modelSettingsSaved => 'Model settings saved';

  @override
  String get noAsrModels => 'No ASR models found';

  @override
  String noAsrModelsIn(Object arg1) {
    return 'No ASR models found: $arg1';
  }

  @override
  String asrModelsFound(Object arg1) {
    return 'Found $arg1 ASR models';
  }

  @override
  String asrScanFailed(Object arg1) {
    return 'ASR model scan failed: $arg1';
  }

  @override
  String get noLlamaModels => 'No Llama models found';

  @override
  String noLlamaModelsIn(Object arg1) {
    return 'No Llama models found: $arg1';
  }

  @override
  String llamaModelsFound(Object arg1) {
    return 'Found $arg1 Llama models';
  }

  @override
  String llamaScanFailed(Object arg1) {
    return 'Llama model scan failed: $arg1';
  }

  @override
  String modelPathMissing(Object arg1) {
    return 'No path available for the $arg1 model';
  }

  @override
  String modelPathNotFound(Object arg1, Object arg2) {
    return '$arg1 model path does not exist: $arg2';
  }

  @override
  String modelPathOpenFailed(Object arg1, Object arg2) {
    return 'Could not open the $arg1 model path: $arg2';
  }

  @override
  String get apiUrlRequired => 'Enter an API URL first';

  @override
  String modelsFetched(Object arg1) {
    return 'Fetched $arg1 models';
  }

  @override
  String modelListFailed(Object arg1) {
    return 'Could not fetch model list: $arg1';
  }

  @override
  String get modelFile => 'Model file';

  @override
  String get asrModelHint => 'GGUF filename under bin/crispasr';

  @override
  String get sourceLanguage => 'Source language';

  @override
  String get scanning => 'Scanning…';

  @override
  String get queryModels => 'List models';

  @override
  String get openModelPath => 'Open model folder';

  @override
  String get localLlama => 'Local Llama';

  @override
  String get localLlamaDescription =>
      'llama-server loads one GGUF model at a time. Correction and translation share this model when set to local. After changing models, llama-server restarts before the next local task.';

  @override
  String get llamaModelHint => 'GGUF filename under bin/llama';

  @override
  String get fixedPort => 'Fixed port';

  @override
  String get correction => 'Correction';

  @override
  String get connectionMode => 'Connection mode';

  @override
  String get online => 'Online';

  @override
  String get sharedModel => 'Shared model';

  @override
  String get noModelSelected => 'No model selected';

  @override
  String get apiUrl => 'API URL';

  @override
  String get modelName => 'Model name';

  @override
  String get querying => 'Querying…';

  @override
  String get translation => 'Translation';

  @override
  String get translator => 'Translator';

  @override
  String get indexCompatibility => 'Index-Translate compatibility';

  @override
  String get indexCompatibilityDescription =>
      'Uses the official script request identifiers and reasoning format, with reasoning always disabled.';

  @override
  String get openAiUrl => 'OpenAI-compatible URL';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get modelParametersSaved => 'Model parameters saved';

  @override
  String get modelParametersDescription =>
      'Configure prompts and request parameters for correction and translation models.';

  @override
  String get correctionPrompt =>
      'Additional proofreading instructions (optional)';

  @override
  String get correctionPromptHint =>
      'Built-in rules always apply. Ambiguous text is kept and recorded for listening review.';

  @override
  String get enableThinking => 'Enable thinking/reasoning';

  @override
  String get thinkingDisabledDescription =>
      'When off, sends thinking.type=disabled if supported by the API.';

  @override
  String get promptMode => 'Prompt mode';

  @override
  String get appendPrompt => 'Append to the default prompt';

  @override
  String get overwritePrompt => 'Replace the default prompt';

  @override
  String get translationPrompt => 'Translation prompt';

  @override
  String get translationPromptHint => 'Leave empty to keep the default prompt';

  @override
  String get contextSentences => 'Context sentences';

  @override
  String get batchSentences => 'Sentences per request';

  @override
  String get tokenLimit => 'Token limit';

  @override
  String get indexThinkingDisabled =>
      'Thinking is always disabled in Index compatibility mode.';

  @override
  String get targetLrc => 'Translated LRC';

  @override
  String get targetLrcDescription => 'Translated lyrics; preferred by Kikoeta';

  @override
  String get targetSrt => 'Translated SRT';

  @override
  String get targetSrtDescription => 'Translated subtitles';

  @override
  String get bilingualLrc => 'Bilingual LRC';

  @override
  String get translationFirstDescription =>
      'Translation + original in one file';

  @override
  String get bilingualSrt => 'Bilingual SRT';

  @override
  String get sourceTargetLrc => 'Original + translated LRC';

  @override
  String get sourceFirstDescription => 'Original + translation in one file';

  @override
  String get sourceTargetSrt => 'Original + translated SRT';

  @override
  String get outputSettingsSaved => 'Output settings saved';

  @override
  String get readingLyricsCache => 'Reading lyrics cache…';

  @override
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3) {
    return 'Uploading $arg1/$arg2: $arg3';
  }

  @override
  String get noLyricsCacheToPush => 'No Kikoeta lyrics cache to upload';

  @override
  String cachePushCompleted(Object arg1, Object arg2) {
    return 'Upload complete: $arg1 succeeded, $arg2 failed';
  }

  @override
  String cachePushFailed(Object arg1) {
    return 'Upload incomplete: $arg1';
  }

  @override
  String get files => 'Files';

  @override
  String get outputDirectory => 'Output folder';

  @override
  String get outputDirectoryHint => 'Leave empty to use the source file folder';

  @override
  String get chooseDirectory => 'Choose folder';

  @override
  String get useSourceDirectory => 'Use source folder';

  @override
  String get format => 'Format';

  @override
  String get outputFormat => 'Output format';

  @override
  String get llsSyncTitle =>
      'Upload results from Kikoeta requests to Kikoeta-LLS';

  @override
  String get llsSyncDescription =>
      'Uploads lyrics after successful completion; local tasks are unaffected';

  @override
  String get llsUrl => 'Kikoeta-LLS URL (HTTP/HTTPS)';

  @override
  String get llsUrlHint => 'Leave empty for local http://127.0.0.1:2378';

  @override
  String get uploadAuthentication => 'Upload authentication';

  @override
  String get twelveCharacterKey => '12-character key';

  @override
  String get separateCredentials => 'Separate username and password';

  @override
  String get uploadKey => 'Upload key';

  @override
  String get uploadKeyHint =>
      'Generate or set a 12-character key in Kikoeta-LLS settings';

  @override
  String get uploadUsername => 'Upload username';

  @override
  String get uploadPassword => 'Upload password';

  @override
  String get lyricsCache => 'Lyrics cache';

  @override
  String get lyricsCacheDescription =>
      'Upload LRC files cached from the last 5 Kikoeta tasks using the URL and authentication above. Auto-sync need not be enabled. Files with the same name are replaced; local cache is kept.';

  @override
  String get pushingCache => 'Uploading…';

  @override
  String get pushCacheToLls => 'Upload cache to LLS';

  @override
  String get viewFailureDetails => 'View error details';

  @override
  String get asrPresetSaved => 'ASR preset saved';

  @override
  String presetSwitchFailed(Object arg1) {
    return 'Could not switch preset: $arg1';
  }

  @override
  String get asrParametersDescription =>
      'CrispASR parameters for media transcription. Subtitle input skips this stage.';

  @override
  String get basicSegmentation => 'Basics and segmentation';

  @override
  String get startOffsetMs => 'Start offset (ms)';

  @override
  String get segmentOffset => 'Start segment offset';

  @override
  String get processingDurationMs => 'Processing duration (ms)';

  @override
  String get zeroMeansAll => '0 for all';

  @override
  String get maxTextContext => 'Maximum text context';

  @override
  String get maxSegmentLength => 'Maximum segment length';

  @override
  String get chunkSecondsWithoutVad => 'Chunk length without VAD (s)';

  @override
  String get chunkOverlapSeconds => 'Chunk overlap (s)';

  @override
  String get forceAligner => 'Force aligner';

  @override
  String get splitOnPunctuation => 'Split on punctuation';

  @override
  String get splitOnWord => 'Split on words';

  @override
  String get vadAndPunctuation => 'VAD and punctuation';

  @override
  String get disablePunctuation => 'Disable punctuation';

  @override
  String get maxSpeechSeconds => 'Maximum speech duration (s)';

  @override
  String get minSilenceMs => 'Minimum silence (ms)';

  @override
  String get vadModel => 'VAD model';

  @override
  String get vadModelHint => 'Enter a model alias or path';

  @override
  String get vadThreshold => 'VAD threshold';

  @override
  String get hotwords => 'Hotwords (comma-separated)';

  @override
  String get recognitionSensitivity => 'Recognition sensitivity';

  @override
  String get punctuationModel => 'Punctuation model';

  @override
  String get leaveEmptyForDefault => 'Leave empty for default';

  @override
  String get truecaseModel => 'Capitalization model';

  @override
  String get truecaseModelHint => 'auto or model path';

  @override
  String get flushSrtEveryN => 'Flush SRT every N segments';

  @override
  String get flushSrtHint => '1 logs each segment';

  @override
  String get decoding => 'Decoding';

  @override
  String get bestOf => 'Candidates (best-of)';

  @override
  String get audioContext => 'Audio context';

  @override
  String get wordTimestampThreshold => 'Word timestamp threshold';

  @override
  String get entropyThreshold => 'Entropy threshold';

  @override
  String get logProbabilityThreshold => 'Log probability threshold';

  @override
  String get noSpeechThreshold => 'No-speech threshold';

  @override
  String get randomSeed => 'Random seed';

  @override
  String get disableTemperatureFallback => 'Disable temperature fallback';

  @override
  String get device => 'Device';

  @override
  String get disableGpu => 'Disable GPU';

  @override
  String get threads => 'Threads';

  @override
  String get processors => 'Processors';

  @override
  String get gpuDeviceIndex => 'GPU device index';

  @override
  String get gpuBackend => 'GPU backend';

  @override
  String get advancedTemplate => 'Advanced template';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get editCommandTemplate => 'Edit command template';

  @override
  String get fullCommandTemplate => 'Full command template';

  @override
  String get commandTemplateHint =>
      'Generated from the parameters above; edit manually and save';

  @override
  String get commandTemplateDescription =>
      'Saving manual edits parses known parameters and keeps unknown arguments in the template.';

  @override
  String get fileNotFound => 'File does not exist';

  @override
  String openFileFailed(Object arg1) {
    return 'Could not open file: $arg1';
  }

  @override
  String get deleteTranslationCacheTitle => 'Delete translation cache?';

  @override
  String get deleteTranslationCacheDescription =>
      'Deletes only this task’s GalTransl work cache. Exported files and Kikoeta lyrics sync cache are kept.';

  @override
  String get deleteCache => 'Delete cache';

  @override
  String cacheFreed(Object arg1) {
    return 'Cleared $arg1 of translation cache';
  }

  @override
  String cleanupFailed(Object arg1) {
    return 'Cleanup failed: $arg1';
  }

  @override
  String get deleteRecentTitle => 'Delete this recent task?';

  @override
  String get deleteRecentDescription =>
      'Deletes this task’s work files and cache, and removes it from recent tasks. Exported files are kept.';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get recordDeleted => 'Record deleted; exported files kept';

  @override
  String deleteFailed(Object arg1) {
    return 'Delete failed: $arg1';
  }

  @override
  String get deleteAllRecentTitle => 'Delete all recent tasks?';

  @override
  String deleteAllRecentDescription(Object arg1) {
    return 'Deletes work files and cache for $arg1 records. Exported files are kept.';
  }

  @override
  String get deleteAll => 'Delete all';

  @override
  String recordsDeleted(Object arg1) {
    return 'Deleted $arg1 records; exported files kept';
  }

  @override
  String get legacyTask => 'Older task';

  @override
  String get recentDescription =>
      'Recent translation tasks and GalTransl work cache. Clearing cache keeps exported files.';

  @override
  String get deleteAllRecords => 'Delete all records';

  @override
  String get refresh => 'Refresh';

  @override
  String get loadFailed => 'Could not load';

  @override
  String get translationHistory => 'Translation history';

  @override
  String get noTranslationCache => 'No translation cache';

  @override
  String get kikoetaSourceSuffix => ' · From Kikoeta';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4) {
    return '$arg1 · $arg2$arg3 · Cache $arg4';
  }

  @override
  String get clearing => 'Clearing';

  @override
  String get deleteRecordKeepOutput => 'Delete record (keep exported files)';

  @override
  String get noLyricsOutput => 'No finished lyrics to display';

  @override
  String get open => 'Open';

  @override
  String get fileMoved => 'File moved';

  @override
  String get invalidRemoteCredentials => 'Invalid remote username or password';

  @override
  String get remoteRestartFailed => 'Could not restart remote service';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get remoteCredentialsRequired =>
      'Remote username and password are required';

  @override
  String get remoteUsernameColon => 'Remote username cannot contain a colon';

  @override
  String get remoteCredentialsReset =>
      'Remote credentials reset to admin / kikoeta';

  @override
  String get toolsRefreshed => 'Tool detection refreshed';

  @override
  String get releaseMissingVersion =>
      'GitHub Release did not include a version';

  @override
  String githubStatus(Object arg1) {
    return 'GitHub returned $arg1';
  }

  @override
  String releaseFeedStatus(Object arg1) {
    return 'GitHub API returned 403; release feed returned $arg1';
  }

  @override
  String get releaseFeedEmpty => 'No releases in the release feed';

  @override
  String get releaseFeedMissingVersion =>
      'Release feed did not include a version';

  @override
  String get invalidVersion => 'Invalid version format';

  @override
  String updateAvailable(Object arg1, Object arg2) {
    return 'New version $arg1 available (current: $arg2)';
  }

  @override
  String alreadyLatest(Object arg1) {
    return 'Already up to date ($arg1)';
  }

  @override
  String updateCheckFailed(Object arg1) {
    return 'Update check failed: $arg1';
  }

  @override
  String get tools => 'Tools';

  @override
  String get notDetected => 'Not detected';

  @override
  String get executableNotFound => 'Executable not found';

  @override
  String get paths => 'Paths';

  @override
  String get ffmpegPath => 'ffmpeg path';

  @override
  String get crispAsrDirectory => 'CrispASR folder';

  @override
  String get httpProxy => 'HTTP proxy';

  @override
  String get chooseCrispAsrDirectory => 'Choose CrispASR folder';

  @override
  String get interfaceAndService => 'Interface and service';

  @override
  String get theme => 'Theme';

  @override
  String get followSystem => 'Follow system';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get allowRemoteAccess => 'Allow remote access';

  @override
  String get remoteListenAll => 'Listening on 0.0.0.0:2370';

  @override
  String get remoteListenLocal => 'Listening only on 127.0.0.1:2370';

  @override
  String get remoteAuthentication => 'Remote authentication';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get resetRemoteCredentials => 'Reset default credentials';

  @override
  String get reset => 'Reset';

  @override
  String get about => 'About';

  @override
  String get repository => 'Project repository';

  @override
  String get checkingUpdate => 'Checking…';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get logsExported => 'Logs exported';

  @override
  String logExportFailed(Object arg1) {
    return 'Could not export logs: $arg1';
  }

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusRunning => 'Processing';

  @override
  String get statusPausing => 'Suspending';

  @override
  String get statusPaused => 'Suspended';

  @override
  String get statusCancelling => 'Cancelling';

  @override
  String get processingStages => 'Processing stages';

  @override
  String get transcodeAndAsr => 'Transcode + ASR';

  @override
  String get transcodeDescription =>
      'Required for audio/video; skipped for subtitles';

  @override
  String get fixed => 'Fixed';

  @override
  String get correctionStageDescription =>
      'Fix transcription only; no translation';

  @override
  String get translationStageDescription => 'Uses the configured translator';

  @override
  String get inputFiles => 'Input files';

  @override
  String get clearFileList => 'Clear list';

  @override
  String get dropFilesHint =>
      'Drop audio, video, or subtitles here, or click to choose';

  @override
  String selectedFiles(Object arg1) {
    return '$arg1 files selected; click to add more';
  }

  @override
  String get removeFile => 'Remove file';

  @override
  String get submitting => 'Submitting…';

  @override
  String get stopping => 'Stopping…';

  @override
  String get stopWorkflow => 'Stop workflow';

  @override
  String get startProcessing => 'Start processing';

  @override
  String get currentWorkflow => 'Current workflow';

  @override
  String get fromKikoeta => 'From Kikoeta';

  @override
  String get localTask => 'Local task';

  @override
  String get logs => 'Logs';

  @override
  String get noLogs => 'No logs yet';

  @override
  String get pythonNotFound => 'No usable Python 3 interpreter found';

  @override
  String get engineScriptNotFound => 'engine/server.py not found';

  @override
  String pythonStartFailed(Object arg1) {
    return 'Could not start Python: $arg1';
  }

  @override
  String get engineTimeout => 'Timed out waiting for engine';

  @override
  String engineTimeoutDetails(Object arg1) {
    return 'Timed out waiting for engine: $arg1';
  }

  @override
  String engineExitedCode(Object arg1) {
    return 'Engine exited (code $arg1)';
  }

  @override
  String engineExitedDetails(Object arg1) {
    return 'Engine exited: $arg1';
  }

  @override
  String get jobSubmitFailed => 'Could not submit task';

  @override
  String get recentLoadFailed => 'Could not load recent tasks';

  @override
  String get cacheClearFailed => 'Could not clear cache';

  @override
  String get recentDeleteFailed => 'Could not delete recent record';

  @override
  String get lyricsCacheLoadFailed => 'Could not load lyrics cache';

  @override
  String get lyricsCachePushFailed => 'Could not upload lyrics cache';

  @override
  String get ffmpegNotFound =>
      'ffmpeg not found. Put ffmpeg.exe in bin/ffmpeg/bin.';

  @override
  String get autoDetectLanguage => 'auto · Detect automatically';

  @override
  String get forNovelTranslator => 'ForNovel · Novels / other text';

  @override
  String get galtranslSakuraTranslator => 'galtransl-v3 · Sakura API';

  @override
  String get sakuraTranslator => 'sakura-v1.0 · Sakura API';

  @override
  String get presetNameRequired => 'Enter a preset name';

  @override
  String get presetNameExists => 'Name already exists; use another name';

  @override
  String get saveAsrPresetAs => 'Save ASR preset as';

  @override
  String get presetName => 'Preset name';

  @override
  String get comboInputHint => 'Type or choose from the list';

  @override
  String get openList => 'Open list';

  @override
  String get noPresetOptions => 'No preset options; type a value';

  @override
  String get saveAs => 'Save as';

  @override
  String get presets => 'Presets';

  @override
  String get asrPreset => 'ASR preset';

  @override
  String basePresetLabel(Object arg1) {
    return '$arg1 (built-in)';
  }

  @override
  String get basePresetDescription =>
      'Save changes to built-in presets as a new preset. Leaving this page saves them as a custom preset automatically.';

  @override
  String get restorePreset => 'Restore preset';

  @override
  String get uiLanguage => 'Interface language';

  @override
  String get llamaStopped => 'Stopped';

  @override
  String get llamaStarting => 'Starting';

  @override
  String get llamaReady => 'Ready';

  @override
  String get crispCheckUpdate => 'Check updates';

  @override
  String get crispQuickUpdate => 'Quick update';

  @override
  String get crispDownload => 'Download';

  @override
  String get crispReleaseTitle => 'CrispASR releases';

  @override
  String crispVersions(Object current, Object latest) {
    return 'Current: $current · Latest: $latest';
  }

  @override
  String get crispInstalled => 'CrispASR updated';

  @override
  String get crispRecommended => 'Recommended';

  @override
  String get crispAlreadyLatest =>
      'Already up to date. You can reinstall or switch backends.';

  @override
  String get crispNoPackage =>
      'This release has no complete package for this system architecture.';

  @override
  String get crispPreserveModels =>
      'Updates the runtime only; local models are preserved.';

  @override
  String get crispDownloading => 'Downloading';

  @override
  String get crispExtracting => 'Extracting and verifying';

  @override
  String get crispInstalling => 'Installing';

  @override
  String get crispCancelling => 'Cancelling';

  @override
  String get crispInstall => 'Download and install';

  @override
  String get crispCpuHint =>
      'CPU: no dedicated GPU required; x86 builds need AVX2. Usually slower than a GPU.';

  @override
  String get crispLegacyHint =>
      'Legacy CPU: supports processors without AVX2, with lower performance.';

  @override
  String get crispAvx512Hint =>
      'AVX-512: for CPUs supporting AVX-512; incompatible with older processors.';

  @override
  String get crispCudaHint =>
      'CUDA 12.8: optimized for NVIDIA GPUs, usually the first choice. Compatible driver required; runtime included.';

  @override
  String get crispCuda126Hint =>
      'CUDA 12.6: for NVIDIA GPUs with older drivers. No RTX 50 series support; runtime included.';

  @override
  String get crispCuda13Hint =>
      'CUDA 13: for Turing or newer NVIDIA GPUs and recent drivers. Runtime included; not necessarily faster than CUDA 12.';

  @override
  String get crispVulkanHint =>
      'Vulkan: covers AMD, Intel and NVIDIA GPUs, with a smaller download. Speed and compatibility depend on the model and driver; Linux requires Vulkan to start.';

  @override
  String get crispMetalHint =>
      'Metal: GPU acceleration on Apple silicon, without CUDA.';

  @override
  String get crispHipHint =>
      'ROCm: for AMD GPUs. Select the package matching ROCm 6 or ROCm 7.';

  @override
  String get crispCudaMissing =>
      'NVIDIA GPU detected, but usable CUDA was not detected. Check the driver and download a compatible CUDA version.';

  @override
  String get crispDownloadCuda => 'Download CUDA';

  @override
  String get crispChooseCuda => 'How to choose CUDA';

  @override
  String get crispChooseCudaHelp =>
      'Send your GPU model and operating system version to an AI and ask it to recommend a compatible CUDA version. Complete CUDA packages include the runtime, so a separate toolkit is usually unnecessary.';
}
