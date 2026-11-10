import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh', 'CN'),
    Locale('ja'),
    Locale('ru'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @engineConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 engine…'**
  String get engineConnecting;

  /// No description provided for @engineConnected.
  ///
  /// In zh, this message translates to:
  /// **'engine 已连接'**
  String get engineConnected;

  /// No description provided for @engineStartHelp.
  ///
  /// In zh, this message translates to:
  /// **'{arg1}，请手动运行 python engine/server.py'**
  String engineStartHelp(Object arg1);

  /// No description provided for @engineStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能启动 engine'**
  String get engineStartFailed;

  /// No description provided for @toolDetectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'工具检测失败：{arg1}'**
  String toolDetectionFailed(Object arg1);

  /// No description provided for @addFilesFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先添加文件'**
  String get addFilesFirst;

  /// No description provided for @jobStarted.
  ///
  /// In zh, this message translates to:
  /// **'任务已开始'**
  String get jobStarted;

  /// No description provided for @jobSubmitError.
  ///
  /// In zh, this message translates to:
  /// **'提交任务失败：{arg1}'**
  String jobSubmitError(Object arg1);

  /// No description provided for @jobStopping.
  ///
  /// In zh, this message translates to:
  /// **'正在停止任务…'**
  String get jobStopping;

  /// No description provided for @jobStopRequested.
  ///
  /// In zh, this message translates to:
  /// **'已请求停止任务，正在等待当前阶段结束'**
  String get jobStopRequested;

  /// No description provided for @jobPausedMessage.
  ///
  /// In zh, this message translates to:
  /// **'任务已暂存'**
  String get jobPausedMessage;

  /// No description provided for @jobEnded.
  ///
  /// In zh, this message translates to:
  /// **'任务结束：{arg1}'**
  String jobEnded(Object arg1);

  /// No description provided for @eventTimeoutRetry.
  ///
  /// In zh, this message translates to:
  /// **'等待 engine 事件超时，将继续轮询'**
  String get eventTimeoutRetry;

  /// No description provided for @pollFailed.
  ///
  /// In zh, this message translates to:
  /// **'轮询失败: {arg1}'**
  String pollFailed(Object arg1);

  /// No description provided for @jobResumed.
  ///
  /// In zh, this message translates to:
  /// **'任务继续处理中'**
  String get jobResumed;

  /// No description provided for @showingKikoetaLogs.
  ///
  /// In zh, this message translates to:
  /// **'正在显示由 kikoeta 发起的任务日志'**
  String get showingKikoetaLogs;

  /// No description provided for @showWindow.
  ///
  /// In zh, this message translates to:
  /// **'显示窗口'**
  String get showWindow;

  /// No description provided for @stopTask.
  ///
  /// In zh, this message translates to:
  /// **'停止任务'**
  String get stopTask;

  /// No description provided for @exitApp.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exitApp;

  /// No description provided for @activeTaskTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务正在运行'**
  String get activeTaskTitle;

  /// No description provided for @closeActiveTask.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口将停止当前任务，确定要关闭吗？'**
  String get closeActiveTask;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirmClose.
  ///
  /// In zh, this message translates to:
  /// **'确定关闭'**
  String get confirmClose;

  /// No description provided for @exitSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置保存失败，尚未退出：{arg1}'**
  String exitSaveFailed(Object arg1);

  /// No description provided for @autoSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'自动保存失败，已留在当前页面：{arg1}'**
  String autoSaveFailed(Object arg1);

  /// No description provided for @recent.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get recent;

  /// No description provided for @tasks.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get tasks;

  /// No description provided for @models.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get models;

  /// No description provided for @asrParameters.
  ///
  /// In zh, this message translates to:
  /// **'听写参数'**
  String get asrParameters;

  /// No description provided for @modelParameters.
  ///
  /// In zh, this message translates to:
  /// **'模型参数'**
  String get modelParameters;

  /// No description provided for @dictionaries.
  ///
  /// In zh, this message translates to:
  /// **'字典'**
  String get dictionaries;

  /// No description provided for @output.
  ///
  /// In zh, this message translates to:
  /// **'输出'**
  String get output;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @gptDictionary.
  ///
  /// In zh, this message translates to:
  /// **'GPT 字典'**
  String get gptDictionary;

  /// No description provided for @postTranslation.
  ///
  /// In zh, this message translates to:
  /// **'译后'**
  String get postTranslation;

  /// No description provided for @preTranslation.
  ///
  /// In zh, this message translates to:
  /// **'译前'**
  String get preTranslation;

  /// No description provided for @dictionaryReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取字典：{arg1}'**
  String dictionaryReadFailed(Object arg1);

  /// No description provided for @dictionarySaved.
  ///
  /// In zh, this message translates to:
  /// **'字典已保存'**
  String get dictionarySaved;

  /// No description provided for @dictionaryRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'字典已保存，但刷新失败：{arg1}'**
  String dictionaryRefreshFailed(Object arg1);

  /// No description provided for @dictionaryDescription.
  ///
  /// In zh, this message translates to:
  /// **'直接使用 GalTransl 内置 Dict。点击条目会在 kikoeta-transl 内置编辑器中打开。'**
  String get dictionaryDescription;

  /// No description provided for @dictionariesFound.
  ///
  /// In zh, this message translates to:
  /// **'已刷新，发现 {arg1} 个字典'**
  String dictionariesFound(Object arg1);

  /// No description provided for @refreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败：{arg1}'**
  String refreshFailed(Object arg1);

  /// No description provided for @refreshDictionaries.
  ///
  /// In zh, this message translates to:
  /// **'刷新字典'**
  String get refreshDictionaries;

  /// No description provided for @noDictionaries.
  ///
  /// In zh, this message translates to:
  /// **'未找到字典文件'**
  String get noDictionaries;

  /// No description provided for @dictionaryEntryCount.
  ///
  /// In zh, this message translates to:
  /// **'{arg1} 条 · 点击编辑'**
  String dictionaryEntryCount(Object arg1);

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{arg1}'**
  String saveFailed(Object arg1);

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @modelSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'模型设置已保存'**
  String get modelSettingsSaved;

  /// No description provided for @noAsrModels.
  ///
  /// In zh, this message translates to:
  /// **'未扫描到 ASR 模型'**
  String get noAsrModels;

  /// No description provided for @noAsrModelsIn.
  ///
  /// In zh, this message translates to:
  /// **'未扫描到 ASR 模型：{arg1}'**
  String noAsrModelsIn(Object arg1);

  /// No description provided for @asrModelsFound.
  ///
  /// In zh, this message translates to:
  /// **'已扫描到 {arg1} 个 ASR 模型'**
  String asrModelsFound(Object arg1);

  /// No description provided for @asrScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'ASR 模型刷新失败：{arg1}'**
  String asrScanFailed(Object arg1);

  /// No description provided for @noLlamaModels.
  ///
  /// In zh, this message translates to:
  /// **'未扫描到 Llama 模型'**
  String get noLlamaModels;

  /// No description provided for @noLlamaModelsIn.
  ///
  /// In zh, this message translates to:
  /// **'未扫描到 Llama 模型：{arg1}'**
  String noLlamaModelsIn(Object arg1);

  /// No description provided for @llamaModelsFound.
  ///
  /// In zh, this message translates to:
  /// **'已扫描到 {arg1} 个 Llama 模型'**
  String llamaModelsFound(Object arg1);

  /// No description provided for @llamaScanFailed.
  ///
  /// In zh, this message translates to:
  /// **'Llama 模型刷新失败：{arg1}'**
  String llamaScanFailed(Object arg1);

  /// No description provided for @modelPathMissing.
  ///
  /// In zh, this message translates to:
  /// **'未获取到 {arg1} 模型路径'**
  String modelPathMissing(Object arg1);

  /// No description provided for @modelPathNotFound.
  ///
  /// In zh, this message translates to:
  /// **'{arg1} 模型路径不存在：{arg2}'**
  String modelPathNotFound(Object arg1, Object arg2);

  /// No description provided for @modelPathOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开 {arg1} 模型路径：{arg2}'**
  String modelPathOpenFailed(Object arg1, Object arg2);

  /// No description provided for @apiUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 API 地址'**
  String get apiUrlRequired;

  /// No description provided for @modelsFetched.
  ///
  /// In zh, this message translates to:
  /// **'已获取 {arg1} 个模型'**
  String modelsFetched(Object arg1);

  /// No description provided for @modelListFailed.
  ///
  /// In zh, this message translates to:
  /// **'模型列表获取失败：{arg1}'**
  String modelListFailed(Object arg1);

  /// No description provided for @modelFile.
  ///
  /// In zh, this message translates to:
  /// **'模型文件'**
  String get modelFile;

  /// No description provided for @asrModelHint.
  ///
  /// In zh, this message translates to:
  /// **'bin/crispasr 下的 gguf 文件名'**
  String get asrModelHint;

  /// No description provided for @sourceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'源语言'**
  String get sourceLanguage;

  /// No description provided for @scanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描…'**
  String get scanning;

  /// No description provided for @queryModels.
  ///
  /// In zh, this message translates to:
  /// **'查询模型列表'**
  String get queryModels;

  /// No description provided for @openModelPath.
  ///
  /// In zh, this message translates to:
  /// **'打开模型路径'**
  String get openModelPath;

  /// No description provided for @localLlama.
  ///
  /// In zh, this message translates to:
  /// **'本地 Llama'**
  String get localLlama;

  /// No description provided for @localLlamaDescription.
  ///
  /// In zh, this message translates to:
  /// **'本项目以单模型模式运行 llama-server，同一时间只挂载一个 GGUF 模型。矫正和翻译选择“本地”时，将共同使用此处选择的模型。切换模型后，llama-server 会在下一次本地任务开始前重新启动。'**
  String get localLlamaDescription;

  /// No description provided for @llamaModelHint.
  ///
  /// In zh, this message translates to:
  /// **'bin/llama 下的 GGUF 文件名'**
  String get llamaModelHint;

  /// No description provided for @fixedPort.
  ///
  /// In zh, this message translates to:
  /// **'固定端口'**
  String get fixedPort;

  /// No description provided for @correction.
  ///
  /// In zh, this message translates to:
  /// **'矫正'**
  String get correction;

  /// No description provided for @connectionMode.
  ///
  /// In zh, this message translates to:
  /// **'连接方式'**
  String get connectionMode;

  /// No description provided for @online.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// No description provided for @sharedModel.
  ///
  /// In zh, this message translates to:
  /// **'共享模型'**
  String get sharedModel;

  /// No description provided for @noModelSelected.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择模型'**
  String get noModelSelected;

  /// No description provided for @apiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get apiUrl;

  /// No description provided for @modelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名'**
  String get modelName;

  /// No description provided for @querying.
  ///
  /// In zh, this message translates to:
  /// **'正在查询…'**
  String get querying;

  /// No description provided for @translation.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translation;

  /// No description provided for @translator.
  ///
  /// In zh, this message translates to:
  /// **'翻译器'**
  String get translator;

  /// No description provided for @indexCompatibility.
  ///
  /// In zh, this message translates to:
  /// **'Index-Translate 兼容模式'**
  String get indexCompatibility;

  /// No description provided for @indexCompatibilityDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用官方脚本的请求标识和思考参数格式，并固定关闭思考模式。'**
  String get indexCompatibilityDescription;

  /// No description provided for @openAiUrl.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容地址'**
  String get openAiUrl;

  /// No description provided for @targetLanguage.
  ///
  /// In zh, this message translates to:
  /// **'目标语言'**
  String get targetLanguage;

  /// No description provided for @modelParametersSaved.
  ///
  /// In zh, this message translates to:
  /// **'模型参数已保存'**
  String get modelParametersSaved;

  /// No description provided for @modelParametersDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置矫正模型与翻译模型的提示词及请求参数。'**
  String get modelParametersDescription;

  /// No description provided for @correctionPrompt.
  ///
  /// In zh, this message translates to:
  /// **'补充校对要求（可选）'**
  String get correctionPrompt;

  /// No description provided for @correctionPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'内置规则始终生效；含混内容保留原文，并写入矫正记录供回听'**
  String get correctionPromptHint;

  /// No description provided for @enableThinking.
  ///
  /// In zh, this message translates to:
  /// **'启用思考/推理'**
  String get enableThinking;

  /// No description provided for @thinkingDisabledDescription.
  ///
  /// In zh, this message translates to:
  /// **'关闭后请求会发送 thinking.type=disabled（接口支持时生效）'**
  String get thinkingDisabledDescription;

  /// No description provided for @promptMode.
  ///
  /// In zh, this message translates to:
  /// **'Prompt 工作模式'**
  String get promptMode;

  /// No description provided for @appendPrompt.
  ///
  /// In zh, this message translates to:
  /// **'衔接到默认提示词尾部'**
  String get appendPrompt;

  /// No description provided for @overwritePrompt.
  ///
  /// In zh, this message translates to:
  /// **'直接覆盖默认提示词'**
  String get overwritePrompt;

  /// No description provided for @translationPrompt.
  ///
  /// In zh, this message translates to:
  /// **'翻译 Prompt'**
  String get translationPrompt;

  /// No description provided for @translationPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则不修改默认提示词'**
  String get translationPromptHint;

  /// No description provided for @contextSentences.
  ///
  /// In zh, this message translates to:
  /// **'上下文句数'**
  String get contextSentences;

  /// No description provided for @batchSentences.
  ///
  /// In zh, this message translates to:
  /// **'单次翻译句数'**
  String get batchSentences;

  /// No description provided for @tokenLimit.
  ///
  /// In zh, this message translates to:
  /// **'Token 上限'**
  String get tokenLimit;

  /// No description provided for @indexThinkingDisabled.
  ///
  /// In zh, this message translates to:
  /// **'Index 兼容模式下固定关闭思考。'**
  String get indexThinkingDisabled;

  /// No description provided for @targetLrc.
  ///
  /// In zh, this message translates to:
  /// **'目标 LRC'**
  String get targetLrc;

  /// No description provided for @targetLrcDescription.
  ///
  /// In zh, this message translates to:
  /// **'单语歌词，kikoeta 优先匹配'**
  String get targetLrcDescription;

  /// No description provided for @targetSrt.
  ///
  /// In zh, this message translates to:
  /// **'目标 SRT'**
  String get targetSrt;

  /// No description provided for @targetSrtDescription.
  ///
  /// In zh, this message translates to:
  /// **'单语字幕'**
  String get targetSrtDescription;

  /// No description provided for @bilingualLrc.
  ///
  /// In zh, this message translates to:
  /// **'双语 LRC'**
  String get bilingualLrc;

  /// No description provided for @translationFirstDescription.
  ///
  /// In zh, this message translates to:
  /// **'同一文件内译文 + 原文'**
  String get translationFirstDescription;

  /// No description provided for @bilingualSrt.
  ///
  /// In zh, this message translates to:
  /// **'双语 SRT'**
  String get bilingualSrt;

  /// No description provided for @sourceTargetLrc.
  ///
  /// In zh, this message translates to:
  /// **'原文 + 目标 LRC'**
  String get sourceTargetLrc;

  /// No description provided for @sourceFirstDescription.
  ///
  /// In zh, this message translates to:
  /// **'同一文件内原文 + 译文'**
  String get sourceFirstDescription;

  /// No description provided for @sourceTargetSrt.
  ///
  /// In zh, this message translates to:
  /// **'原文 + 目标 SRT'**
  String get sourceTargetSrt;

  /// No description provided for @outputSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'输出设置已保存'**
  String get outputSettingsSaved;

  /// No description provided for @readingLyricsCache.
  ///
  /// In zh, this message translates to:
  /// **'正在读取歌词缓存…'**
  String get readingLyricsCache;

  /// No description provided for @pushingCacheProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在推送 {arg1}/{arg2}：{arg3}'**
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3);

  /// No description provided for @noLyricsCacheToPush.
  ///
  /// In zh, this message translates to:
  /// **'暂无可推送的 Kikoeta 歌词缓存'**
  String get noLyricsCacheToPush;

  /// No description provided for @cachePushCompleted.
  ///
  /// In zh, this message translates to:
  /// **'推送完成：成功 {arg1} 个，失败 {arg2} 个'**
  String cachePushCompleted(Object arg1, Object arg2);

  /// No description provided for @cachePushFailed.
  ///
  /// In zh, this message translates to:
  /// **'推送未完成：{arg1}'**
  String cachePushFailed(Object arg1);

  /// No description provided for @files.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get files;

  /// No description provided for @outputDirectory.
  ///
  /// In zh, this message translates to:
  /// **'输出目录'**
  String get outputDirectory;

  /// No description provided for @outputDirectoryHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则输出到源文件所在目录'**
  String get outputDirectoryHint;

  /// No description provided for @chooseDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择目录'**
  String get chooseDirectory;

  /// No description provided for @useSourceDirectory.
  ///
  /// In zh, this message translates to:
  /// **'使用源文件目录'**
  String get useSourceDirectory;

  /// No description provided for @format.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get format;

  /// No description provided for @outputFormat.
  ///
  /// In zh, this message translates to:
  /// **'输出格式'**
  String get outputFormat;

  /// No description provided for @llsSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'来自 Kikoeta 的翻译请求，产物同步上传到 Kikoeta-LLS'**
  String get llsSyncTitle;

  /// No description provided for @llsSyncDescription.
  ///
  /// In zh, this message translates to:
  /// **'任务成功完成后上传歌词；本地任务不受影响'**
  String get llsSyncDescription;

  /// No description provided for @llsUrl.
  ///
  /// In zh, this message translates to:
  /// **'Kikoeta-LLS 地址（HTTP/HTTPS）'**
  String get llsUrl;

  /// No description provided for @llsUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'留空使用本机 http://127.0.0.1:2378'**
  String get llsUrlHint;

  /// No description provided for @uploadAuthentication.
  ///
  /// In zh, this message translates to:
  /// **'上传验证方式'**
  String get uploadAuthentication;

  /// No description provided for @twelveCharacterKey.
  ///
  /// In zh, this message translates to:
  /// **'12 位密钥'**
  String get twelveCharacterKey;

  /// No description provided for @separateCredentials.
  ///
  /// In zh, this message translates to:
  /// **'独立账号和密码'**
  String get separateCredentials;

  /// No description provided for @uploadKey.
  ///
  /// In zh, this message translates to:
  /// **'上传密钥'**
  String get uploadKey;

  /// No description provided for @uploadKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'在 Kikoeta-LLS 设置页生成或手动设置 12 位密钥'**
  String get uploadKeyHint;

  /// No description provided for @uploadUsername.
  ///
  /// In zh, this message translates to:
  /// **'上传账号'**
  String get uploadUsername;

  /// No description provided for @uploadPassword.
  ///
  /// In zh, this message translates to:
  /// **'上传密码'**
  String get uploadPassword;

  /// No description provided for @lyricsCache.
  ///
  /// In zh, this message translates to:
  /// **'歌词缓存'**
  String get lyricsCache;

  /// No description provided for @lyricsCacheDescription.
  ///
  /// In zh, this message translates to:
  /// **'将最近 5 次 Kikoeta 任务中保留的 LRC 缓存推送到 LLS。使用上方地址和验证配置，无需开启自动同步。同名歌词会覆盖，推送后保留本地缓存。'**
  String get lyricsCacheDescription;

  /// No description provided for @pushingCache.
  ///
  /// In zh, this message translates to:
  /// **'正在推送…'**
  String get pushingCache;

  /// No description provided for @pushCacheToLls.
  ///
  /// In zh, this message translates to:
  /// **'将缓存推送到 LLS'**
  String get pushCacheToLls;

  /// No description provided for @viewFailureDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看失败详情'**
  String get viewFailureDetails;

  /// No description provided for @asrPresetSaved.
  ///
  /// In zh, this message translates to:
  /// **'听写预设已保存'**
  String get asrPresetSaved;

  /// No description provided for @presetSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换预设失败：{arg1}'**
  String presetSwitchFailed(Object arg1);

  /// No description provided for @asrParametersDescription.
  ///
  /// In zh, this message translates to:
  /// **'媒体听写使用的 CrispASR 参数。字幕输入不会走到这一步。'**
  String get asrParametersDescription;

  /// No description provided for @basicSegmentation.
  ///
  /// In zh, this message translates to:
  /// **'基础与分段'**
  String get basicSegmentation;

  /// No description provided for @startOffsetMs.
  ///
  /// In zh, this message translates to:
  /// **'起始偏移（毫秒）'**
  String get startOffsetMs;

  /// No description provided for @segmentOffset.
  ///
  /// In zh, this message translates to:
  /// **'起始片段偏移'**
  String get segmentOffset;

  /// No description provided for @processingDurationMs.
  ///
  /// In zh, this message translates to:
  /// **'处理时长（毫秒）'**
  String get processingDurationMs;

  /// No description provided for @zeroMeansAll.
  ///
  /// In zh, this message translates to:
  /// **'0 表示全部'**
  String get zeroMeansAll;

  /// No description provided for @maxTextContext.
  ///
  /// In zh, this message translates to:
  /// **'最大文本上下文'**
  String get maxTextContext;

  /// No description provided for @maxSegmentLength.
  ///
  /// In zh, this message translates to:
  /// **'最大片段长度'**
  String get maxSegmentLength;

  /// No description provided for @chunkSecondsWithoutVad.
  ///
  /// In zh, this message translates to:
  /// **'无 VAD 时分段秒数'**
  String get chunkSecondsWithoutVad;

  /// No description provided for @chunkOverlapSeconds.
  ///
  /// In zh, this message translates to:
  /// **'分段重叠秒数'**
  String get chunkOverlapSeconds;

  /// No description provided for @forceAligner.
  ///
  /// In zh, this message translates to:
  /// **'强制 Aligner'**
  String get forceAligner;

  /// No description provided for @splitOnPunctuation.
  ///
  /// In zh, this message translates to:
  /// **'按标点切分'**
  String get splitOnPunctuation;

  /// No description provided for @splitOnWord.
  ///
  /// In zh, this message translates to:
  /// **'按单词切分'**
  String get splitOnWord;

  /// No description provided for @vadAndPunctuation.
  ///
  /// In zh, this message translates to:
  /// **'VAD 与标点'**
  String get vadAndPunctuation;

  /// No description provided for @disablePunctuation.
  ///
  /// In zh, this message translates to:
  /// **'禁用标点'**
  String get disablePunctuation;

  /// No description provided for @maxSpeechSeconds.
  ///
  /// In zh, this message translates to:
  /// **'最大语音时长（秒）'**
  String get maxSpeechSeconds;

  /// No description provided for @minSilenceMs.
  ///
  /// In zh, this message translates to:
  /// **'最小静音（毫秒）'**
  String get minSilenceMs;

  /// No description provided for @vadModel.
  ///
  /// In zh, this message translates to:
  /// **'VAD 模型'**
  String get vadModel;

  /// No description provided for @vadModelHint.
  ///
  /// In zh, this message translates to:
  /// **'可输入模型别名或路径'**
  String get vadModelHint;

  /// No description provided for @vadThreshold.
  ///
  /// In zh, this message translates to:
  /// **'VAD 阈值'**
  String get vadThreshold;

  /// No description provided for @hotwords.
  ///
  /// In zh, this message translates to:
  /// **'热词（逗号分隔）'**
  String get hotwords;

  /// No description provided for @recognitionSensitivity.
  ///
  /// In zh, this message translates to:
  /// **'识别敏感度'**
  String get recognitionSensitivity;

  /// No description provided for @punctuationModel.
  ///
  /// In zh, this message translates to:
  /// **'标点模型'**
  String get punctuationModel;

  /// No description provided for @leaveEmptyForDefault.
  ///
  /// In zh, this message translates to:
  /// **'留空使用默认'**
  String get leaveEmptyForDefault;

  /// No description provided for @truecaseModel.
  ///
  /// In zh, this message translates to:
  /// **'大小写模型'**
  String get truecaseModel;

  /// No description provided for @truecaseModelHint.
  ///
  /// In zh, this message translates to:
  /// **'auto 或模型路径'**
  String get truecaseModelHint;

  /// No description provided for @flushSrtEveryN.
  ///
  /// In zh, this message translates to:
  /// **'每 N 段刷新 SRT'**
  String get flushSrtEveryN;

  /// No description provided for @flushSrtHint.
  ///
  /// In zh, this message translates to:
  /// **'1 表示逐段输出日志'**
  String get flushSrtHint;

  /// No description provided for @decoding.
  ///
  /// In zh, this message translates to:
  /// **'解码'**
  String get decoding;

  /// No description provided for @bestOf.
  ///
  /// In zh, this message translates to:
  /// **'候选数 best-of'**
  String get bestOf;

  /// No description provided for @audioContext.
  ///
  /// In zh, this message translates to:
  /// **'音频上下文'**
  String get audioContext;

  /// No description provided for @wordTimestampThreshold.
  ///
  /// In zh, this message translates to:
  /// **'词时间戳阈值'**
  String get wordTimestampThreshold;

  /// No description provided for @entropyThreshold.
  ///
  /// In zh, this message translates to:
  /// **'熵阈值'**
  String get entropyThreshold;

  /// No description provided for @logProbabilityThreshold.
  ///
  /// In zh, this message translates to:
  /// **'对数概率阈值'**
  String get logProbabilityThreshold;

  /// No description provided for @noSpeechThreshold.
  ///
  /// In zh, this message translates to:
  /// **'无语音阈值'**
  String get noSpeechThreshold;

  /// No description provided for @randomSeed.
  ///
  /// In zh, this message translates to:
  /// **'随机种子'**
  String get randomSeed;

  /// No description provided for @disableTemperatureFallback.
  ///
  /// In zh, this message translates to:
  /// **'禁用温度回退'**
  String get disableTemperatureFallback;

  /// No description provided for @device.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get device;

  /// No description provided for @disableGpu.
  ///
  /// In zh, this message translates to:
  /// **'禁用 GPU'**
  String get disableGpu;

  /// No description provided for @threads.
  ///
  /// In zh, this message translates to:
  /// **'线程数'**
  String get threads;

  /// No description provided for @processors.
  ///
  /// In zh, this message translates to:
  /// **'处理器数'**
  String get processors;

  /// No description provided for @gpuDeviceIndex.
  ///
  /// In zh, this message translates to:
  /// **'GPU 设备编号'**
  String get gpuDeviceIndex;

  /// No description provided for @gpuBackend.
  ///
  /// In zh, this message translates to:
  /// **'GPU 后端'**
  String get gpuBackend;

  /// No description provided for @advancedTemplate.
  ///
  /// In zh, this message translates to:
  /// **'高级模板'**
  String get advancedTemplate;

  /// No description provided for @restoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefaults;

  /// No description provided for @editCommandTemplate.
  ///
  /// In zh, this message translates to:
  /// **'编辑命令模板'**
  String get editCommandTemplate;

  /// No description provided for @fullCommandTemplate.
  ///
  /// In zh, this message translates to:
  /// **'完整命令模板'**
  String get fullCommandTemplate;

  /// No description provided for @commandTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'根据上方参数实时生成；可手动编辑后保存'**
  String get commandTemplateHint;

  /// No description provided for @commandTemplateDescription.
  ///
  /// In zh, this message translates to:
  /// **'手动编辑后保存会解析参数；未知参数保留在模板中。'**
  String get commandTemplateDescription;

  /// No description provided for @fileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get fileNotFound;

  /// No description provided for @openFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开文件失败：{arg1}'**
  String openFileFailed(Object arg1);

  /// No description provided for @deleteTranslationCacheTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除翻译缓存？'**
  String get deleteTranslationCacheTitle;

  /// No description provided for @deleteTranslationCacheDescription.
  ///
  /// In zh, this message translates to:
  /// **'仅删除此任务的 GalTransl 工作缓存；已导出的成果文件和 Kikoeta 歌词同步缓存不会删除。'**
  String get deleteTranslationCacheDescription;

  /// No description provided for @deleteCache.
  ///
  /// In zh, this message translates to:
  /// **'删除缓存'**
  String get deleteCache;

  /// No description provided for @cacheFreed.
  ///
  /// In zh, this message translates to:
  /// **'已清理 {arg1} 翻译缓存'**
  String cacheFreed(Object arg1);

  /// No description provided for @cleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理失败：{arg1}'**
  String cleanupFailed(Object arg1);

  /// No description provided for @deleteRecentTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这条最近记录？'**
  String get deleteRecentTitle;

  /// No description provided for @deleteRecentDescription.
  ///
  /// In zh, this message translates to:
  /// **'将删除此任务的工作文件和缓存，并从最近列表移除记录。已导出的成果文件会保留。'**
  String get deleteRecentDescription;

  /// No description provided for @deleteRecord.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get deleteRecord;

  /// No description provided for @recordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'记录已删除，成果文件已保留'**
  String get recordDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{arg1}'**
  String deleteFailed(Object arg1);

  /// No description provided for @deleteAllRecentTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除全部最近记录？'**
  String get deleteAllRecentTitle;

  /// No description provided for @deleteAllRecentDescription.
  ///
  /// In zh, this message translates to:
  /// **'将删除当前 {arg1} 条记录对应的工作文件和缓存。已导出的成果文件会保留。'**
  String deleteAllRecentDescription(Object arg1);

  /// No description provided for @deleteAll.
  ///
  /// In zh, this message translates to:
  /// **'全部删除'**
  String get deleteAll;

  /// No description provided for @recordsDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {arg1} 条记录，成果文件已保留'**
  String recordsDeleted(Object arg1);

  /// No description provided for @legacyTask.
  ///
  /// In zh, this message translates to:
  /// **'旧任务'**
  String get legacyTask;

  /// No description provided for @recentDescription.
  ///
  /// In zh, this message translates to:
  /// **'最近的翻译任务与 GalTransl 工作缓存。清理缓存不会删除导出的文件。'**
  String get recentDescription;

  /// No description provided for @deleteAllRecords.
  ///
  /// In zh, this message translates to:
  /// **'一键删除所有记录'**
  String get deleteAllRecords;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @translationHistory.
  ///
  /// In zh, this message translates to:
  /// **'翻译记录'**
  String get translationHistory;

  /// No description provided for @noTranslationCache.
  ///
  /// In zh, this message translates to:
  /// **'暂无翻译缓存'**
  String get noTranslationCache;

  /// No description provided for @kikoetaSourceSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 来自 Kikoeta'**
  String get kikoetaSourceSuffix;

  /// No description provided for @statusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get statusFailed;

  /// No description provided for @statusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get statusCancelled;

  /// No description provided for @recentTaskDetails.
  ///
  /// In zh, this message translates to:
  /// **'{arg1} · {arg2}{arg3} · 缓存 {arg4}'**
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4);

  /// No description provided for @clearing.
  ///
  /// In zh, this message translates to:
  /// **'清理中'**
  String get clearing;

  /// No description provided for @deleteRecordKeepOutput.
  ///
  /// In zh, this message translates to:
  /// **'删除记录（保留成果文件）'**
  String get deleteRecordKeepOutput;

  /// No description provided for @noLyricsOutput.
  ///
  /// In zh, this message translates to:
  /// **'暂无可显示的成品歌词'**
  String get noLyricsOutput;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// No description provided for @fileMoved.
  ///
  /// In zh, this message translates to:
  /// **'文件已移走'**
  String get fileMoved;

  /// No description provided for @invalidRemoteCredentials.
  ///
  /// In zh, this message translates to:
  /// **'远程用户名或密码无效'**
  String get invalidRemoteCredentials;

  /// No description provided for @remoteRestartFailed.
  ///
  /// In zh, this message translates to:
  /// **'远程服务重启失败'**
  String get remoteRestartFailed;

  /// No description provided for @settingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'设置已保存'**
  String get settingsSaved;

  /// No description provided for @remoteCredentialsRequired.
  ///
  /// In zh, this message translates to:
  /// **'远程用户名和密码不能为空'**
  String get remoteCredentialsRequired;

  /// No description provided for @remoteUsernameColon.
  ///
  /// In zh, this message translates to:
  /// **'远程用户名不能包含冒号'**
  String get remoteUsernameColon;

  /// No description provided for @remoteCredentialsReset.
  ///
  /// In zh, this message translates to:
  /// **'远程账密已重置为 admin / kikoeta'**
  String get remoteCredentialsReset;

  /// No description provided for @toolsRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'已刷新工具检测'**
  String get toolsRefreshed;

  /// No description provided for @releaseMissingVersion.
  ///
  /// In zh, this message translates to:
  /// **'GitHub Release 未提供版本号'**
  String get releaseMissingVersion;

  /// No description provided for @githubStatus.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 返回 {arg1}'**
  String githubStatus(Object arg1);

  /// No description provided for @releaseFeedStatus.
  ///
  /// In zh, this message translates to:
  /// **'GitHub API 返回 403，Release Feed 返回 {arg1}'**
  String releaseFeedStatus(Object arg1);

  /// No description provided for @releaseFeedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'Release Feed 中没有发布版本'**
  String get releaseFeedEmpty;

  /// No description provided for @releaseFeedMissingVersion.
  ///
  /// In zh, this message translates to:
  /// **'Release Feed 未提供版本号'**
  String get releaseFeedMissingVersion;

  /// No description provided for @invalidVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本号格式无效'**
  String get invalidVersion;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {arg1}（当前 {arg2}）'**
  String updateAvailable(Object arg1, Object arg2);

  /// No description provided for @alreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本（{arg1}）'**
  String alreadyLatest(Object arg1);

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败：{arg1}'**
  String updateCheckFailed(Object arg1);

  /// No description provided for @tools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get tools;

  /// No description provided for @notDetected.
  ///
  /// In zh, this message translates to:
  /// **'未检测'**
  String get notDetected;

  /// No description provided for @executableNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到可执行文件'**
  String get executableNotFound;

  /// No description provided for @paths.
  ///
  /// In zh, this message translates to:
  /// **'路径'**
  String get paths;

  /// No description provided for @ffmpegPath.
  ///
  /// In zh, this message translates to:
  /// **'ffmpeg 路径'**
  String get ffmpegPath;

  /// No description provided for @crispAsrDirectory.
  ///
  /// In zh, this message translates to:
  /// **'CrispASR 目录'**
  String get crispAsrDirectory;

  /// No description provided for @httpProxy.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理'**
  String get httpProxy;

  /// No description provided for @chooseCrispAsrDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择 CrispASR 目录'**
  String get chooseCrispAsrDirectory;

  /// No description provided for @interfaceAndService.
  ///
  /// In zh, this message translates to:
  /// **'界面与服务'**
  String get interfaceAndService;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @lightTheme.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get darkTheme;

  /// No description provided for @allowRemoteAccess.
  ///
  /// In zh, this message translates to:
  /// **'允许远程访问'**
  String get allowRemoteAccess;

  /// No description provided for @remoteListenAll.
  ///
  /// In zh, this message translates to:
  /// **'服务监听 0.0.0.0:2370'**
  String get remoteListenAll;

  /// No description provided for @remoteListenLocal.
  ///
  /// In zh, this message translates to:
  /// **'服务仅监听 127.0.0.1:2370'**
  String get remoteListenLocal;

  /// No description provided for @remoteAuthentication.
  ///
  /// In zh, this message translates to:
  /// **'远程身份验证'**
  String get remoteAuthentication;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @resetRemoteCredentials.
  ///
  /// In zh, this message translates to:
  /// **'重置默认账密'**
  String get resetRemoteCredentials;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @repository.
  ///
  /// In zh, this message translates to:
  /// **'项目仓库'**
  String get repository;

  /// No description provided for @checkingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在检查…'**
  String get checkingUpdate;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @exportLogs.
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get exportLogs;

  /// No description provided for @logsExported.
  ///
  /// In zh, this message translates to:
  /// **'日志已导出'**
  String get logsExported;

  /// No description provided for @logExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'日志导出失败：{arg1}'**
  String logExportFailed(Object arg1);

  /// No description provided for @statusQueued.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get statusQueued;

  /// No description provided for @statusRunning.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get statusRunning;

  /// No description provided for @statusPausing.
  ///
  /// In zh, this message translates to:
  /// **'正在暂存'**
  String get statusPausing;

  /// No description provided for @statusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂存'**
  String get statusPaused;

  /// No description provided for @statusCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消'**
  String get statusCancelling;

  /// No description provided for @processingStages.
  ///
  /// In zh, this message translates to:
  /// **'处理阶段'**
  String get processingStages;

  /// No description provided for @transcodeAndAsr.
  ///
  /// In zh, this message translates to:
  /// **'转码 + ASR'**
  String get transcodeAndAsr;

  /// No description provided for @transcodeDescription.
  ///
  /// In zh, this message translates to:
  /// **'音频 / 视频必做；字幕输入自动跳过'**
  String get transcodeDescription;

  /// No description provided for @fixed.
  ///
  /// In zh, this message translates to:
  /// **'固定'**
  String get fixed;

  /// No description provided for @correctionStageDescription.
  ///
  /// In zh, this message translates to:
  /// **'只修听写，不翻译'**
  String get correctionStageDescription;

  /// No description provided for @translationStageDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用已配置的翻译器'**
  String get translationStageDescription;

  /// No description provided for @inputFiles.
  ///
  /// In zh, this message translates to:
  /// **'输入文件'**
  String get inputFiles;

  /// No description provided for @clearFileList.
  ///
  /// In zh, this message translates to:
  /// **'清空列表'**
  String get clearFileList;

  /// No description provided for @dropFilesHint.
  ///
  /// In zh, this message translates to:
  /// **'拖入音视频或字幕，或点击选择'**
  String get dropFilesHint;

  /// No description provided for @selectedFiles.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {arg1} 个文件，点击继续添加'**
  String selectedFiles(Object arg1);

  /// No description provided for @removeFile.
  ///
  /// In zh, this message translates to:
  /// **'移除文件'**
  String get removeFile;

  /// No description provided for @submitting.
  ///
  /// In zh, this message translates to:
  /// **'正在提交…'**
  String get submitting;

  /// No description provided for @stopping.
  ///
  /// In zh, this message translates to:
  /// **'正在停止…'**
  String get stopping;

  /// No description provided for @stopWorkflow.
  ///
  /// In zh, this message translates to:
  /// **'停止工作流'**
  String get stopWorkflow;

  /// No description provided for @startProcessing.
  ///
  /// In zh, this message translates to:
  /// **'开始处理'**
  String get startProcessing;

  /// No description provided for @currentWorkflow.
  ///
  /// In zh, this message translates to:
  /// **'当前工作流'**
  String get currentWorkflow;

  /// No description provided for @fromKikoeta.
  ///
  /// In zh, this message translates to:
  /// **'来自 Kikoeta'**
  String get fromKikoeta;

  /// No description provided for @localTask.
  ///
  /// In zh, this message translates to:
  /// **'本地任务'**
  String get localTask;

  /// No description provided for @logs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logs;

  /// No description provided for @noLogs.
  ///
  /// In zh, this message translates to:
  /// **'尚无日志'**
  String get noLogs;

  /// No description provided for @pythonNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到可用的 Python 3 解释器'**
  String get pythonNotFound;

  /// No description provided for @engineScriptNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到 engine/server.py'**
  String get engineScriptNotFound;

  /// No description provided for @pythonStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法启动 Python：{arg1}'**
  String pythonStartFailed(Object arg1);

  /// No description provided for @engineTimeout.
  ///
  /// In zh, this message translates to:
  /// **'等待 engine 响应超时'**
  String get engineTimeout;

  /// No description provided for @engineTimeoutDetails.
  ///
  /// In zh, this message translates to:
  /// **'等待 engine 响应超时：{arg1}'**
  String engineTimeoutDetails(Object arg1);

  /// No description provided for @engineExitedCode.
  ///
  /// In zh, this message translates to:
  /// **'engine 已退出（退出码 {arg1}）'**
  String engineExitedCode(Object arg1);

  /// No description provided for @engineExitedDetails.
  ///
  /// In zh, this message translates to:
  /// **'engine 已退出：{arg1}'**
  String engineExitedDetails(Object arg1);

  /// No description provided for @jobSubmitFailed.
  ///
  /// In zh, this message translates to:
  /// **'提交任务失败'**
  String get jobSubmitFailed;

  /// No description provided for @recentLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载最近任务失败'**
  String get recentLoadFailed;

  /// No description provided for @cacheClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存失败'**
  String get cacheClearFailed;

  /// No description provided for @recentDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除最近记录失败'**
  String get recentDeleteFailed;

  /// No description provided for @lyricsCacheLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载歌词缓存失败'**
  String get lyricsCacheLoadFailed;

  /// No description provided for @lyricsCachePushFailed.
  ///
  /// In zh, this message translates to:
  /// **'推送歌词缓存失败'**
  String get lyricsCachePushFailed;

  /// No description provided for @ffmpegNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到 ffmpeg。请将 ffmpeg.exe 放到 bin/ffmpeg/bin'**
  String get ffmpegNotFound;

  /// No description provided for @autoDetectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'auto · 自动检测'**
  String get autoDetectLanguage;

  /// No description provided for @forNovelTranslator.
  ///
  /// In zh, this message translates to:
  /// **'ForNovel · 小说 / 其他文本'**
  String get forNovelTranslator;

  /// No description provided for @galtranslSakuraTranslator.
  ///
  /// In zh, this message translates to:
  /// **'galtransl-v3 · Sakura 接口'**
  String get galtranslSakuraTranslator;

  /// No description provided for @sakuraTranslator.
  ///
  /// In zh, this message translates to:
  /// **'sakura-v1.0 · Sakura 接口'**
  String get sakuraTranslator;

  /// No description provided for @presetNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入预设名称'**
  String get presetNameRequired;

  /// No description provided for @presetNameExists.
  ///
  /// In zh, this message translates to:
  /// **'名称已存在，请使用其他名称'**
  String get presetNameExists;

  /// No description provided for @saveAsrPresetAs.
  ///
  /// In zh, this message translates to:
  /// **'另存听写预设'**
  String get saveAsrPresetAs;

  /// No description provided for @presetName.
  ///
  /// In zh, this message translates to:
  /// **'预设名称'**
  String get presetName;

  /// No description provided for @comboInputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入或从列表选择'**
  String get comboInputHint;

  /// No description provided for @openList.
  ///
  /// In zh, this message translates to:
  /// **'打开列表'**
  String get openList;

  /// No description provided for @noPresetOptions.
  ///
  /// In zh, this message translates to:
  /// **'暂无预置选项，可直接输入'**
  String get noPresetOptions;

  /// No description provided for @saveAs.
  ///
  /// In zh, this message translates to:
  /// **'另存为'**
  String get saveAs;

  /// No description provided for @presets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presets;

  /// No description provided for @asrPreset.
  ///
  /// In zh, this message translates to:
  /// **'听写预设'**
  String get asrPreset;

  /// No description provided for @basePresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'{arg1}（基础）'**
  String basePresetLabel(Object arg1);

  /// No description provided for @basePresetDescription.
  ///
  /// In zh, this message translates to:
  /// **'基础预设修改后需另存；离页时自动保存为自定义预设。'**
  String get basePresetDescription;

  /// No description provided for @restorePreset.
  ///
  /// In zh, this message translates to:
  /// **'恢复预设'**
  String get restorePreset;

  /// No description provided for @uiLanguage.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get uiLanguage;

  /// No description provided for @llamaStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get llamaStopped;

  /// No description provided for @llamaStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在启动'**
  String get llamaStarting;

  /// No description provided for @llamaReady.
  ///
  /// In zh, this message translates to:
  /// **'已就绪'**
  String get llamaReady;

  /// No description provided for @crispCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检测更新'**
  String get crispCheckUpdate;

  /// No description provided for @crispQuickUpdate.
  ///
  /// In zh, this message translates to:
  /// **'快速更新'**
  String get crispQuickUpdate;

  /// No description provided for @crispDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get crispDownload;

  /// No description provided for @crispReleaseTitle.
  ///
  /// In zh, this message translates to:
  /// **'CrispASR 发行版本'**
  String get crispReleaseTitle;

  /// No description provided for @crispVersions.
  ///
  /// In zh, this message translates to:
  /// **'当前：{current} · 最新：{latest}'**
  String crispVersions(Object current, Object latest);

  /// No description provided for @crispInstalled.
  ///
  /// In zh, this message translates to:
  /// **'CrispASR 已更新'**
  String get crispInstalled;

  /// No description provided for @crispRecommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get crispRecommended;

  /// No description provided for @crispAlreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本，可重装或更换运行后端。'**
  String get crispAlreadyLatest;

  /// No description provided for @crispNoPackage.
  ///
  /// In zh, this message translates to:
  /// **'此发行版没有适合当前系统架构的完整安装包。'**
  String get crispNoPackage;

  /// No description provided for @crispPreserveModels.
  ///
  /// In zh, this message translates to:
  /// **'仅更新程序及运行库，保留本地模型。'**
  String get crispPreserveModels;

  /// No description provided for @crispDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载'**
  String get crispDownloading;

  /// No description provided for @crispExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在解压与验证'**
  String get crispExtracting;

  /// No description provided for @crispInstalling.
  ///
  /// In zh, this message translates to:
  /// **'正在安装'**
  String get crispInstalling;

  /// No description provided for @crispCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消'**
  String get crispCancelling;

  /// No description provided for @crispInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get crispInstall;

  /// No description provided for @crispCpuHint.
  ///
  /// In zh, this message translates to:
  /// **'CPU：无需独立显卡，兼容性好；x86 版本需要 AVX2，通常比 GPU 慢。'**
  String get crispCpuHint;

  /// No description provided for @crispLegacyHint.
  ///
  /// In zh, this message translates to:
  /// **'旧 CPU：支持缺少 AVX2 的处理器，速度较慢。'**
  String get crispLegacyHint;

  /// No description provided for @crispAvx512Hint.
  ///
  /// In zh, this message translates to:
  /// **'AVX-512：适合支持 AVX-512 的 CPU，不兼容较旧处理器。'**
  String get crispAvx512Hint;

  /// No description provided for @crispCudaHint.
  ///
  /// In zh, this message translates to:
  /// **'CUDA 12.8：NVIDIA 专用加速，通常优先选择；需兼容驱动，已含运行库。'**
  String get crispCudaHint;

  /// No description provided for @crispCuda126Hint.
  ///
  /// In zh, this message translates to:
  /// **'CUDA 12.6：适合驱动较旧的 NVIDIA 显卡，不支持 RTX 50 系列；已含运行库。'**
  String get crispCuda126Hint;

  /// No description provided for @crispCuda13Hint.
  ///
  /// In zh, this message translates to:
  /// **'CUDA 13：适合 Turing 及更新 NVIDIA 显卡和新驱动；已含运行库，不保证比 CUDA 12 更快。'**
  String get crispCuda13Hint;

  /// No description provided for @crispVulkanHint.
  ///
  /// In zh, this message translates to:
  /// **'Vulkan：覆盖 AMD、Intel 和 NVIDIA 显卡，包较小；速度及兼容性取决于模型和驱动，Linux 缺少 Vulkan 时无法启动。'**
  String get crispVulkanHint;

  /// No description provided for @crispMetalHint.
  ///
  /// In zh, this message translates to:
  /// **'Metal：使用 Apple 芯片 GPU 加速，无需 CUDA。'**
  String get crispMetalHint;

  /// No description provided for @crispHipHint.
  ///
  /// In zh, this message translates to:
  /// **'ROCm：用于 AMD GPU，ROCm 6 与 ROCm 7 必须选择对应的包。'**
  String get crispHipHint;

  /// No description provided for @crispCudaMissing.
  ///
  /// In zh, this message translates to:
  /// **'检测到 NVIDIA 显卡，但未检测到可用 CUDA。建议检查驱动，并下载适配版本的 CUDA。'**
  String get crispCudaMissing;

  /// No description provided for @crispDownloadCuda.
  ///
  /// In zh, this message translates to:
  /// **'下载 CUDA'**
  String get crispDownloadCuda;

  /// No description provided for @crispChooseCuda.
  ///
  /// In zh, this message translates to:
  /// **'如何选择 CUDA'**
  String get crispChooseCuda;

  /// No description provided for @crispChooseCudaHelp.
  ///
  /// In zh, this message translates to:
  /// **'将显卡型号和系统版本发送给 AI，让 AI 帮你推荐合适的 CUDA 版本。完整 CUDA 发行包已包含运行库，通常无需另装工具包。'**
  String get crispChooseCudaHelp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
