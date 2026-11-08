// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get engineConnecting => 'エンジンに接続中…';

  @override
  String get engineConnected => 'エンジンに接続済み';

  @override
  String engineStartHelp(Object arg1) {
    return '$arg1。python engine/server.py を手動で実行してください。';
  }

  @override
  String get engineStartFailed => 'エンジンを起動できませんでした';

  @override
  String toolDetectionFailed(Object arg1) {
    return 'ツールの検出に失敗しました：$arg1';
  }

  @override
  String get addFilesFirst => '先にファイルを追加してください';

  @override
  String get jobStarted => 'タスクを開始しました';

  @override
  String jobSubmitError(Object arg1) {
    return 'タスクを送信できませんでした：$arg1';
  }

  @override
  String get jobStopping => 'タスクを停止中…';

  @override
  String get jobStopRequested => '停止を要求しました。現在の処理段階の終了を待っています';

  @override
  String get jobPausedMessage => 'タスクを一時保存しました';

  @override
  String jobEnded(Object arg1) {
    return 'タスク終了：$arg1';
  }

  @override
  String get eventTimeoutRetry => 'イベント待機がタイムアウトしました。ポーリングを続行します';

  @override
  String pollFailed(Object arg1) {
    return 'ポーリングに失敗しました：$arg1';
  }

  @override
  String get jobResumed => 'タスクの処理を再開しました';

  @override
  String get showingKikoetaLogs => 'Kikoeta からのタスクのログを表示中';

  @override
  String get showWindow => 'ウィンドウを表示';

  @override
  String get stopTask => 'タスクを停止';

  @override
  String get exitApp => '終了';

  @override
  String get activeTaskTitle => 'タスク実行中';

  @override
  String get closeActiveTask => 'ウィンドウを閉じると現在のタスクが停止します。閉じますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirmClose => '閉じる';

  @override
  String exitSaveFailed(Object arg1) {
    return '設定を保存できなかったため終了していません：$arg1';
  }

  @override
  String autoSaveFailed(Object arg1) {
    return '自動保存に失敗したため、このページに留まりました：$arg1';
  }

  @override
  String get recent => '最近';

  @override
  String get tasks => 'タスク';

  @override
  String get models => 'モデル';

  @override
  String get asrParameters => '文字起こし設定';

  @override
  String get modelParameters => 'モデル設定';

  @override
  String get dictionaries => '辞書';

  @override
  String get output => '出力';

  @override
  String get settings => '設定';

  @override
  String get gptDictionary => 'GPT 辞書';

  @override
  String get postTranslation => '翻訳後';

  @override
  String get preTranslation => '翻訳前';

  @override
  String dictionaryReadFailed(Object arg1) {
    return '辞書を読み込めませんでした：$arg1';
  }

  @override
  String get dictionarySaved => '辞書を保存しました';

  @override
  String dictionaryRefreshFailed(Object arg1) {
    return '辞書を保存しましたが、更新に失敗しました：$arg1';
  }

  @override
  String get dictionaryDescription =>
      'GalTransl の内蔵辞書を使用します。項目を選ぶと内蔵エディターで開きます。';

  @override
  String dictionariesFound(Object arg1) {
    return '更新しました。辞書 $arg1 個を検出';
  }

  @override
  String refreshFailed(Object arg1) {
    return '更新に失敗しました：$arg1';
  }

  @override
  String get refreshDictionaries => '辞書を更新';

  @override
  String get noDictionaries => '辞書ファイルが見つかりません';

  @override
  String dictionaryEntryCount(Object arg1) {
    return '$arg1 件 · クリックして編集';
  }

  @override
  String saveFailed(Object arg1) {
    return '保存に失敗しました：$arg1';
  }

  @override
  String get saving => '保存中…';

  @override
  String get save => '保存';

  @override
  String get modelSettingsSaved => 'モデル設定を保存しました';

  @override
  String get noAsrModels => 'ASR モデルが見つかりません';

  @override
  String noAsrModelsIn(Object arg1) {
    return 'ASR モデルが見つかりません：$arg1';
  }

  @override
  String asrModelsFound(Object arg1) {
    return 'ASR モデル $arg1 個を検出';
  }

  @override
  String asrScanFailed(Object arg1) {
    return 'ASR モデルの検索に失敗しました：$arg1';
  }

  @override
  String get noLlamaModels => 'Llama モデルが見つかりません';

  @override
  String noLlamaModelsIn(Object arg1) {
    return 'Llama モデルが見つかりません：$arg1';
  }

  @override
  String llamaModelsFound(Object arg1) {
    return 'Llama モデル $arg1 個を検出';
  }

  @override
  String llamaScanFailed(Object arg1) {
    return 'Llama モデルの検索に失敗しました：$arg1';
  }

  @override
  String modelPathMissing(Object arg1) {
    return '$arg1 モデルのパスを取得できません';
  }

  @override
  String modelPathNotFound(Object arg1, Object arg2) {
    return '$arg1 モデルのパスが存在しません：$arg2';
  }

  @override
  String modelPathOpenFailed(Object arg1, Object arg2) {
    return '$arg1 モデルのパスを開けませんでした：$arg2';
  }

  @override
  String get apiUrlRequired => '先に API URL を入力してください';

  @override
  String modelsFetched(Object arg1) {
    return 'モデル $arg1 個を取得しました';
  }

  @override
  String modelListFailed(Object arg1) {
    return 'モデル一覧を取得できませんでした：$arg1';
  }

  @override
  String get modelFile => 'モデルファイル';

  @override
  String get asrModelHint => 'bin/crispasr 内の GGUF ファイル名';

  @override
  String get sourceLanguage => '原文の言語';

  @override
  String get scanning => '検索中…';

  @override
  String get queryModels => 'モデル一覧を取得';

  @override
  String get openModelPath => 'モデルの場所を開く';

  @override
  String get localLlama => 'ローカル Llama';

  @override
  String get localLlamaDescription =>
      'llama-server は一度に 1 つの GGUF モデルを読み込みます。矯正と翻訳をローカルに設定すると、このモデルを共有します。モデル変更後は、次のローカルタスクの前に llama-server が再起動します。';

  @override
  String get llamaModelHint => 'bin/llama 内の GGUF ファイル名';

  @override
  String get fixedPort => '固定ポート';

  @override
  String get correction => '文字起こし修正';

  @override
  String get connectionMode => '接続方式';

  @override
  String get online => 'オンライン';

  @override
  String get sharedModel => '共有モデル';

  @override
  String get noModelSelected => 'モデル未選択';

  @override
  String get apiUrl => 'API URL';

  @override
  String get modelName => 'モデル名';

  @override
  String get querying => '取得中…';

  @override
  String get translation => '翻訳';

  @override
  String get translator => '翻訳エンジン';

  @override
  String get indexCompatibility => 'Index-Translate 互換モード';

  @override
  String get indexCompatibilityDescription =>
      '公式スクリプトのリクエスト識別子と推論パラメーター形式を使用し、思考を常に無効にします。';

  @override
  String get openAiUrl => 'OpenAI 互換 URL';

  @override
  String get targetLanguage => '翻訳先の言語';

  @override
  String get modelParametersSaved => 'モデルのパラメーターを保存しました';

  @override
  String get modelParametersDescription =>
      '文字起こし修正・翻訳モデルのプロンプトとリクエストパラメーターを設定します。';

  @override
  String get correctionPrompt => '追加の校正指示（任意）';

  @override
  String get correctionPromptHint =>
      '内蔵ルールは常に適用されます。不明瞭な箇所は原文を残し、聴き直し用の修正記録に保存します。';

  @override
  String get enableThinking => '思考・推論を有効化';

  @override
  String get thinkingDisabledDescription =>
      'オフの場合、API が対応していれば thinking.type=disabled を送信します。';

  @override
  String get promptMode => 'プロンプトの適用方法';

  @override
  String get appendPrompt => '既定のプロンプトに追記';

  @override
  String get overwritePrompt => '既定のプロンプトを置換';

  @override
  String get translationPrompt => '翻訳プロンプト';

  @override
  String get translationPromptHint => '空欄なら既定のプロンプトを使用';

  @override
  String get contextSentences => '文脈の文数';

  @override
  String get batchSentences => '1 回あたりの翻訳文数';

  @override
  String get tokenLimit => 'トークン上限';

  @override
  String get indexThinkingDisabled => 'Index 互換モードでは思考が常に無効になります。';

  @override
  String get targetLrc => '翻訳 LRC';

  @override
  String get targetLrcDescription => '翻訳のみの歌詞。Kikoeta が優先的に照合';

  @override
  String get targetSrt => '翻訳 SRT';

  @override
  String get targetSrtDescription => '翻訳のみの字幕';

  @override
  String get bilingualLrc => '対訳 LRC';

  @override
  String get translationFirstDescription => '同一ファイルに訳文 + 原文';

  @override
  String get bilingualSrt => '対訳 SRT';

  @override
  String get sourceTargetLrc => '原文 + 翻訳 LRC';

  @override
  String get sourceFirstDescription => '同一ファイルに原文 + 訳文';

  @override
  String get sourceTargetSrt => '原文 + 翻訳 SRT';

  @override
  String get outputSettingsSaved => '出力設定を保存しました';

  @override
  String get readingLyricsCache => '歌詞キャッシュを読み込み中…';

  @override
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3) {
    return '送信中 $arg1/$arg2：$arg3';
  }

  @override
  String get noLyricsCacheToPush => '送信できる Kikoeta 歌詞キャッシュがありません';

  @override
  String cachePushCompleted(Object arg1, Object arg2) {
    return '送信完了：成功 $arg1 件、失敗 $arg2 件';
  }

  @override
  String cachePushFailed(Object arg1) {
    return '送信が完了しませんでした：$arg1';
  }

  @override
  String get files => 'ファイル';

  @override
  String get outputDirectory => '出力先フォルダー';

  @override
  String get outputDirectoryHint => '空欄なら元ファイルと同じフォルダーに出力';

  @override
  String get chooseDirectory => 'フォルダーを選択';

  @override
  String get useSourceDirectory => '元ファイルのフォルダーを使用';

  @override
  String get format => '形式';

  @override
  String get outputFormat => '出力形式';

  @override
  String get llsSyncTitle => 'Kikoeta からの翻訳結果を Kikoeta-LLS に送信';

  @override
  String get llsSyncDescription => 'タスク成功後に歌詞を送信します。ローカルタスクには影響しません';

  @override
  String get llsUrl => 'Kikoeta-LLS URL（HTTP/HTTPS）';

  @override
  String get llsUrlHint => '空欄ならローカルの http://127.0.0.1:2378 を使用';

  @override
  String get uploadAuthentication => 'アップロード認証';

  @override
  String get twelveCharacterKey => '12 文字のキー';

  @override
  String get separateCredentials => '専用のユーザー名とパスワード';

  @override
  String get uploadKey => 'アップロードキー';

  @override
  String get uploadKeyHint => 'Kikoeta-LLS の設定で 12 文字のキーを生成または設定';

  @override
  String get uploadUsername => 'アップロード用ユーザー名';

  @override
  String get uploadPassword => 'アップロード用パスワード';

  @override
  String get lyricsCache => '歌詞キャッシュ';

  @override
  String get lyricsCacheDescription =>
      '直近 5 件の Kikoeta タスクの LRC キャッシュを、上の URL と認証設定で LLS に送信します。自動同期は不要です。同名ファイルは上書きし、ローカルキャッシュは保持します。';

  @override
  String get pushingCache => '送信中…';

  @override
  String get pushCacheToLls => 'キャッシュを LLS に送信';

  @override
  String get viewFailureDetails => '失敗の詳細を表示';

  @override
  String get asrPresetSaved => '文字起こしプリセットを保存しました';

  @override
  String presetSwitchFailed(Object arg1) {
    return 'プリセットを切り替えられませんでした：$arg1';
  }

  @override
  String get asrParametersDescription =>
      'メディアの文字起こしに使用する CrispASR の設定です。字幕入力ではこの処理を省略します。';

  @override
  String get basicSegmentation => '基本・分割';

  @override
  String get startOffsetMs => '開始オフセット（ミリ秒）';

  @override
  String get segmentOffset => '開始セグメントのオフセット';

  @override
  String get processingDurationMs => '処理時間（ミリ秒）';

  @override
  String get zeroMeansAll => '0 で全体を処理';

  @override
  String get maxTextContext => '最大テキスト文脈長';

  @override
  String get maxSegmentLength => '最大セグメント長';

  @override
  String get chunkSecondsWithoutVad => 'VAD 無効時の分割秒数';

  @override
  String get chunkOverlapSeconds => '分割の重複秒数';

  @override
  String get forceAligner => '強制アラインメント';

  @override
  String get splitOnPunctuation => '句読点で分割';

  @override
  String get splitOnWord => '単語で分割';

  @override
  String get vadAndPunctuation => 'VAD・句読点';

  @override
  String get disablePunctuation => '句読点を無効化';

  @override
  String get maxSpeechSeconds => '最大音声時間（秒）';

  @override
  String get minSilenceMs => '最小無音時間（ミリ秒）';

  @override
  String get vadModel => 'VAD モデル';

  @override
  String get vadModelHint => 'モデルの別名またはパスを入力';

  @override
  String get vadThreshold => 'VAD しきい値';

  @override
  String get hotwords => 'ホットワード（カンマ区切り）';

  @override
  String get recognitionSensitivity => '認識感度';

  @override
  String get punctuationModel => '句読点モデル';

  @override
  String get leaveEmptyForDefault => '空欄なら既定値を使用';

  @override
  String get truecaseModel => '大文字・小文字モデル';

  @override
  String get truecaseModelHint => 'auto またはモデルのパス';

  @override
  String get flushSrtEveryN => 'N セグメントごとに SRT を書き込み';

  @override
  String get flushSrtHint => '1 で各セグメントのログを出力';

  @override
  String get decoding => 'デコード';

  @override
  String get bestOf => '候補数 best-of';

  @override
  String get audioContext => '音声コンテキスト';

  @override
  String get wordTimestampThreshold => '単語タイムスタンプのしきい値';

  @override
  String get entropyThreshold => 'エントロピーしきい値';

  @override
  String get logProbabilityThreshold => '対数確率しきい値';

  @override
  String get noSpeechThreshold => '無音判定しきい値';

  @override
  String get randomSeed => '乱数シード';

  @override
  String get disableTemperatureFallback => '温度フォールバックを無効化';

  @override
  String get device => 'デバイス';

  @override
  String get disableGpu => 'GPU を無効化';

  @override
  String get threads => 'スレッド数';

  @override
  String get processors => 'プロセッサー数';

  @override
  String get gpuDeviceIndex => 'GPU デバイス番号';

  @override
  String get gpuBackend => 'GPU バックエンド';

  @override
  String get advancedTemplate => '詳細テンプレート';

  @override
  String get restoreDefaults => '既定値に戻す';

  @override
  String get editCommandTemplate => 'コマンドテンプレートを編集';

  @override
  String get fullCommandTemplate => '完全なコマンドテンプレート';

  @override
  String get commandTemplateHint => '上の設定から自動生成します。手動で編集して保存できます';

  @override
  String get commandTemplateDescription =>
      '手動編集後の保存時に設定を解析します。不明な引数はテンプレートに残します。';

  @override
  String get fileNotFound => 'ファイルが存在しません';

  @override
  String openFileFailed(Object arg1) {
    return 'ファイルを開けませんでした：$arg1';
  }

  @override
  String get deleteTranslationCacheTitle => '翻訳キャッシュを削除しますか？';

  @override
  String get deleteTranslationCacheDescription =>
      'このタスクの GalTransl 作業キャッシュのみを削除します。出力済みファイルと Kikoeta 歌詞同期キャッシュは保持します。';

  @override
  String get deleteCache => 'キャッシュを削除';

  @override
  String cacheFreed(Object arg1) {
    return '翻訳キャッシュ $arg1 を削除しました';
  }

  @override
  String cleanupFailed(Object arg1) {
    return '削除に失敗しました：$arg1';
  }

  @override
  String get deleteRecentTitle => 'この履歴を削除しますか？';

  @override
  String get deleteRecentDescription =>
      'このタスクの作業ファイルとキャッシュを削除し、履歴から除きます。出力済みファイルは保持します。';

  @override
  String get deleteRecord => '履歴を削除';

  @override
  String get recordDeleted => '履歴を削除しました。出力済みファイルは保持しました';

  @override
  String deleteFailed(Object arg1) {
    return '削除に失敗しました：$arg1';
  }

  @override
  String get deleteAllRecentTitle => 'すべての履歴を削除しますか？';

  @override
  String deleteAllRecentDescription(Object arg1) {
    return '$arg1 件の履歴に対応する作業ファイルとキャッシュを削除します。出力済みファイルは保持します。';
  }

  @override
  String get deleteAll => 'すべて削除';

  @override
  String recordsDeleted(Object arg1) {
    return '$arg1 件を削除しました。出力済みファイルは保持しました';
  }

  @override
  String get legacyTask => '過去のタスク';

  @override
  String get recentDescription =>
      '最近の翻訳タスクと GalTransl 作業キャッシュです。キャッシュ削除後も出力済みファイルは残ります。';

  @override
  String get deleteAllRecords => 'すべての履歴を削除';

  @override
  String get refresh => '更新';

  @override
  String get loadFailed => '読み込みに失敗しました';

  @override
  String get translationHistory => '翻訳履歴';

  @override
  String get noTranslationCache => '翻訳キャッシュがありません';

  @override
  String get kikoetaSourceSuffix => ' · Kikoeta から';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusCancelled => 'キャンセル済み';

  @override
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4) {
    return '$arg1 · $arg2$arg3 · キャッシュ $arg4';
  }

  @override
  String get clearing => '削除中';

  @override
  String get deleteRecordKeepOutput => '履歴を削除（出力済みファイルは保持）';

  @override
  String get noLyricsOutput => '表示できる完成済み歌詞がありません';

  @override
  String get open => '開く';

  @override
  String get fileMoved => 'ファイルが移動されています';

  @override
  String get invalidRemoteCredentials => 'リモートのユーザー名またはパスワードが無効です';

  @override
  String get remoteRestartFailed => 'リモートサービスを再起動できませんでした';

  @override
  String get settingsSaved => '設定を保存しました';

  @override
  String get remoteCredentialsRequired => 'リモートのユーザー名とパスワードを入力してください';

  @override
  String get remoteUsernameColon => 'リモートのユーザー名にコロンは使用できません';

  @override
  String get remoteCredentialsReset => 'リモートの認証情報を admin / kikoeta に戻しました';

  @override
  String get toolsRefreshed => 'ツール検出を更新しました';

  @override
  String get releaseMissingVersion => 'GitHub Release にバージョンがありません';

  @override
  String githubStatus(Object arg1) {
    return 'GitHub が $arg1 を返しました';
  }

  @override
  String releaseFeedStatus(Object arg1) {
    return 'GitHub API が 403、Release Feed が $arg1 を返しました';
  }

  @override
  String get releaseFeedEmpty => 'Release Feed にリリースがありません';

  @override
  String get releaseFeedMissingVersion => 'Release Feed にバージョンがありません';

  @override
  String get invalidVersion => 'バージョン形式が無効です';

  @override
  String updateAvailable(Object arg1, Object arg2) {
    return '新バージョン $arg1 があります（現在：$arg2）';
  }

  @override
  String alreadyLatest(Object arg1) {
    return '最新バージョンです（$arg1）';
  }

  @override
  String updateCheckFailed(Object arg1) {
    return '更新の確認に失敗しました：$arg1';
  }

  @override
  String get tools => 'ツール';

  @override
  String get notDetected => '未検出';

  @override
  String get executableNotFound => '実行ファイルが見つかりません';

  @override
  String get paths => 'パス';

  @override
  String get ffmpegPath => 'ffmpeg のパス';

  @override
  String get crispAsrDirectory => 'CrispASR フォルダー';

  @override
  String get httpProxy => 'HTTP プロキシ';

  @override
  String get chooseCrispAsrDirectory => 'CrispASR フォルダーを選択';

  @override
  String get interfaceAndService => '表示とサービス';

  @override
  String get theme => 'テーマ';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get lightTheme => 'ライト';

  @override
  String get darkTheme => 'ダーク';

  @override
  String get allowRemoteAccess => 'リモートアクセスを許可';

  @override
  String get remoteListenAll => '0.0.0.0:2370 で待機';

  @override
  String get remoteListenLocal => '127.0.0.1:2370 のみで待機';

  @override
  String get remoteAuthentication => 'リモート認証';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get resetRemoteCredentials => '既定の認証情報に戻す';

  @override
  String get reset => 'リセット';

  @override
  String get about => 'このアプリについて';

  @override
  String get repository => 'プロジェクトのリポジトリ';

  @override
  String get checkingUpdate => '確認中…';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get exportLogs => 'ログを出力';

  @override
  String get logsExported => 'ログを出力しました';

  @override
  String logExportFailed(Object arg1) {
    return 'ログを出力できませんでした：$arg1';
  }

  @override
  String get statusQueued => '待機中';

  @override
  String get statusRunning => '処理中';

  @override
  String get statusPausing => '一時保存中';

  @override
  String get statusPaused => '一時保存済み';

  @override
  String get statusCancelling => 'キャンセル中';

  @override
  String get processingStages => '処理段階';

  @override
  String get transcodeAndAsr => '変換 + ASR';

  @override
  String get transcodeDescription => '音声・動画では必須。字幕入力では省略';

  @override
  String get fixed => '固定';

  @override
  String get correctionStageDescription => '文字起こしのみ修正し、翻訳はしません';

  @override
  String get translationStageDescription => '設定済みの翻訳エンジンを使用';

  @override
  String get inputFiles => '入力ファイル';

  @override
  String get clearFileList => '一覧をクリア';

  @override
  String get dropFilesHint => '音声・動画・字幕をドロップ、またはクリックして選択';

  @override
  String selectedFiles(Object arg1) {
    return '$arg1 ファイル選択済み。クリックして追加';
  }

  @override
  String get removeFile => 'ファイルを除外';

  @override
  String get submitting => '送信中…';

  @override
  String get stopping => '停止中…';

  @override
  String get stopWorkflow => 'ワークフローを停止';

  @override
  String get startProcessing => '処理を開始';

  @override
  String get currentWorkflow => '現在のワークフロー';

  @override
  String get fromKikoeta => 'Kikoeta から';

  @override
  String get localTask => 'ローカルタスク';

  @override
  String get logs => 'ログ';

  @override
  String get noLogs => 'ログはまだありません';

  @override
  String get pythonNotFound => '使用可能な Python 3 が見つかりません';

  @override
  String get engineScriptNotFound => 'engine/server.py が見つかりません';

  @override
  String pythonStartFailed(Object arg1) {
    return 'Python を起動できませんでした：$arg1';
  }

  @override
  String get engineTimeout => 'エンジンの応答がタイムアウトしました';

  @override
  String engineTimeoutDetails(Object arg1) {
    return 'エンジンの応答がタイムアウトしました：$arg1';
  }

  @override
  String engineExitedCode(Object arg1) {
    return 'エンジンが終了しました（コード $arg1）';
  }

  @override
  String engineExitedDetails(Object arg1) {
    return 'エンジンが終了しました：$arg1';
  }

  @override
  String get jobSubmitFailed => 'タスクを送信できませんでした';

  @override
  String get recentLoadFailed => '最近のタスクを読み込めませんでした';

  @override
  String get cacheClearFailed => 'キャッシュを削除できませんでした';

  @override
  String get recentDeleteFailed => '履歴を削除できませんでした';

  @override
  String get lyricsCacheLoadFailed => '歌詞キャッシュを読み込めませんでした';

  @override
  String get lyricsCachePushFailed => '歌詞キャッシュを送信できませんでした';

  @override
  String get ffmpegNotFound =>
      'ffmpeg が見つかりません。ffmpeg.exe を bin/ffmpeg/bin に配置してください。';

  @override
  String get autoDetectLanguage => 'auto · 自動検出';

  @override
  String get forNovelTranslator => 'ForNovel · 小説 / その他のテキスト';

  @override
  String get galtranslSakuraTranslator => 'galtransl-v3 · Sakura API';

  @override
  String get sakuraTranslator => 'sakura-v1.0 · Sakura API';

  @override
  String get presetNameRequired => 'プリセット名を入力してください';

  @override
  String get presetNameExists => 'この名前は使用済みです。別の名前を入力してください';

  @override
  String get saveAsrPresetAs => '文字起こしプリセットを別名保存';

  @override
  String get presetName => 'プリセット名';

  @override
  String get comboInputHint => '入力するか一覧から選択';

  @override
  String get openList => '一覧を開く';

  @override
  String get noPresetOptions => '候補がありません。直接入力できます';

  @override
  String get saveAs => '別名で保存';

  @override
  String get presets => 'プリセット';

  @override
  String get asrPreset => '文字起こしプリセット';

  @override
  String basePresetLabel(Object arg1) {
    return '$arg1（標準）';
  }

  @override
  String get basePresetDescription =>
      '標準プリセットの変更は別名で保存します。ページを離れるとカスタムプリセットとして自動保存します。';

  @override
  String get restorePreset => 'プリセットを復元';

  @override
  String get uiLanguage => '表示言語';

  @override
  String get llamaStopped => '停止中';

  @override
  String get llamaStarting => '起動中';

  @override
  String get llamaReady => '準備完了';
}
