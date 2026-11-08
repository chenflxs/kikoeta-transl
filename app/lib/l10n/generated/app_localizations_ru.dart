// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get engineConnecting => 'Подключение к движку…';

  @override
  String get engineConnected => 'Движок подключён';

  @override
  String engineStartHelp(Object arg1) {
    return '$arg1. Запустите python engine/server.py вручную.';
  }

  @override
  String get engineStartFailed => 'Не удалось запустить движок';

  @override
  String toolDetectionFailed(Object arg1) {
    return 'Ошибка обнаружения инструментов: $arg1';
  }

  @override
  String get addFilesFirst => 'Сначала добавьте файлы';

  @override
  String get jobStarted => 'Задача запущена';

  @override
  String jobSubmitError(Object arg1) {
    return 'Не удалось отправить задачу: $arg1';
  }

  @override
  String get jobStopping => 'Остановка задачи…';

  @override
  String get jobStopRequested =>
      'Запрошена остановка; ожидание завершения текущего этапа';

  @override
  String get jobPausedMessage => 'Задача приостановлена';

  @override
  String jobEnded(Object arg1) {
    return 'Задача завершена: $arg1';
  }

  @override
  String get eventTimeoutRetry =>
      'Время ожидания событий движка истекло; опрос продолжится';

  @override
  String pollFailed(Object arg1) {
    return 'Ошибка опроса: $arg1';
  }

  @override
  String get jobResumed => 'Обработка задачи возобновлена';

  @override
  String get showingKikoetaLogs => 'Показ журналов задачи из Kikoeta';

  @override
  String get showWindow => 'Показать окно';

  @override
  String get stopTask => 'Остановить задачу';

  @override
  String get exitApp => 'Выход';

  @override
  String get activeTaskTitle => 'Задача выполняется';

  @override
  String get closeActiveTask =>
      'Закрытие окна остановит текущую задачу. Закрыть?';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirmClose => 'Закрыть';

  @override
  String exitSaveFailed(Object arg1) {
    return 'Не удалось сохранить настройки; приложение осталось открытым: $arg1';
  }

  @override
  String autoSaveFailed(Object arg1) {
    return 'Ошибка автосохранения; текущая страница сохранена: $arg1';
  }

  @override
  String get recent => 'Недавние';

  @override
  String get tasks => 'Задачи';

  @override
  String get models => 'Модели';

  @override
  String get asrParameters => 'Параметры ASR';

  @override
  String get modelParameters => 'Параметры моделей';

  @override
  String get dictionaries => 'Словари';

  @override
  String get output => 'Вывод';

  @override
  String get settings => 'Настройки';

  @override
  String get gptDictionary => 'Словарь GPT';

  @override
  String get postTranslation => 'После перевода';

  @override
  String get preTranslation => 'До перевода';

  @override
  String dictionaryReadFailed(Object arg1) {
    return 'Не удалось прочитать словарь: $arg1';
  }

  @override
  String get dictionarySaved => 'Словарь сохранён';

  @override
  String dictionaryRefreshFailed(Object arg1) {
    return 'Словарь сохранён, но обновление не удалось: $arg1';
  }

  @override
  String get dictionaryDescription =>
      'Используются встроенные словари GalTransl. Выберите запись, чтобы открыть её во встроенном редакторе.';

  @override
  String dictionariesFound(Object arg1) {
    return 'Обновлено; найдено словарей: $arg1';
  }

  @override
  String refreshFailed(Object arg1) {
    return 'Ошибка обновления: $arg1';
  }

  @override
  String get refreshDictionaries => 'Обновить словари';

  @override
  String get noDictionaries => 'Файлы словарей не найдены';

  @override
  String dictionaryEntryCount(Object arg1) {
    return 'Записей: $arg1 · Нажмите для редактирования';
  }

  @override
  String saveFailed(Object arg1) {
    return 'Ошибка сохранения: $arg1';
  }

  @override
  String get saving => 'Сохранение…';

  @override
  String get save => 'Сохранить';

  @override
  String get modelSettingsSaved => 'Настройки моделей сохранены';

  @override
  String get noAsrModels => 'Модели ASR не найдены';

  @override
  String noAsrModelsIn(Object arg1) {
    return 'Модели ASR не найдены: $arg1';
  }

  @override
  String asrModelsFound(Object arg1) {
    return 'Найдено моделей ASR: $arg1';
  }

  @override
  String asrScanFailed(Object arg1) {
    return 'Ошибка поиска моделей ASR: $arg1';
  }

  @override
  String get noLlamaModels => 'Модели Llama не найдены';

  @override
  String noLlamaModelsIn(Object arg1) {
    return 'Модели Llama не найдены: $arg1';
  }

  @override
  String llamaModelsFound(Object arg1) {
    return 'Найдено моделей Llama: $arg1';
  }

  @override
  String llamaScanFailed(Object arg1) {
    return 'Ошибка поиска моделей Llama: $arg1';
  }

  @override
  String modelPathMissing(Object arg1) {
    return 'Путь к модели $arg1 не получен';
  }

  @override
  String modelPathNotFound(Object arg1, Object arg2) {
    return 'Путь к модели $arg1 не существует: $arg2';
  }

  @override
  String modelPathOpenFailed(Object arg1, Object arg2) {
    return 'Не удалось открыть путь к модели $arg1: $arg2';
  }

  @override
  String get apiUrlRequired => 'Сначала укажите адрес API';

  @override
  String modelsFetched(Object arg1) {
    return 'Получено моделей: $arg1';
  }

  @override
  String modelListFailed(Object arg1) {
    return 'Не удалось получить список моделей: $arg1';
  }

  @override
  String get modelFile => 'Файл модели';

  @override
  String get asrModelHint => 'Имя файла GGUF в bin/crispasr';

  @override
  String get sourceLanguage => 'Исходный язык';

  @override
  String get scanning => 'Поиск…';

  @override
  String get queryModels => 'Получить список моделей';

  @override
  String get openModelPath => 'Открыть папку модели';

  @override
  String get localLlama => 'Локальная Llama';

  @override
  String get localLlamaDescription =>
      'llama-server загружает одну модель GGUF за раз. Исправление и перевод в локальном режиме используют эту общую модель. После смены модели llama-server перезапустится перед следующей локальной задачей.';

  @override
  String get llamaModelHint => 'Имя файла GGUF в bin/llama';

  @override
  String get fixedPort => 'Фиксированный порт';

  @override
  String get correction => 'Исправление';

  @override
  String get connectionMode => 'Режим подключения';

  @override
  String get online => 'Онлайн';

  @override
  String get sharedModel => 'Общая модель';

  @override
  String get noModelSelected => 'Модель не выбрана';

  @override
  String get apiUrl => 'Адрес API';

  @override
  String get modelName => 'Имя модели';

  @override
  String get querying => 'Запрос…';

  @override
  String get translation => 'Перевод';

  @override
  String get translator => 'Переводчик';

  @override
  String get indexCompatibility => 'Совместимость с Index-Translate';

  @override
  String get indexCompatibilityDescription =>
      'Использует идентификаторы запросов и формат параметров рассуждения официального скрипта; рассуждение всегда отключено.';

  @override
  String get openAiUrl => 'Адрес, совместимый с OpenAI';

  @override
  String get targetLanguage => 'Язык перевода';

  @override
  String get modelParametersSaved => 'Параметры моделей сохранены';

  @override
  String get modelParametersDescription =>
      'Настройте промпты и параметры запросов моделей исправления и перевода.';

  @override
  String get correctionPrompt =>
      'Дополнительные указания для исправления (необязательно)';

  @override
  String get correctionPromptHint =>
      'Встроенные правила действуют всегда. Неясный текст сохраняется и отмечается для повторного прослушивания.';

  @override
  String get enableThinking => 'Включить рассуждение';

  @override
  String get thinkingDisabledDescription =>
      'При отключении отправляется thinking.type=disabled, если API это поддерживает.';

  @override
  String get promptMode => 'Режим промпта';

  @override
  String get appendPrompt => 'Добавить к стандартному промпту';

  @override
  String get overwritePrompt => 'Заменить стандартный промпт';

  @override
  String get translationPrompt => 'Промпт перевода';

  @override
  String get translationPromptHint =>
      'Оставьте пустым для стандартного промпта';

  @override
  String get contextSentences => 'Предложений контекста';

  @override
  String get batchSentences => 'Предложений за запрос';

  @override
  String get tokenLimit => 'Лимит токенов';

  @override
  String get indexThinkingDisabled =>
      'В режиме совместимости с Index рассуждение всегда отключено.';

  @override
  String get targetLrc => 'Перевод LRC';

  @override
  String get targetLrcDescription =>
      'Переведённый текст; приоритетный вариант для Kikoeta';

  @override
  String get targetSrt => 'Перевод SRT';

  @override
  String get targetSrtDescription => 'Переведённые субтитры';

  @override
  String get bilingualLrc => 'Двуязычный LRC';

  @override
  String get translationFirstDescription => 'Перевод + оригинал в одном файле';

  @override
  String get bilingualSrt => 'Двуязычный SRT';

  @override
  String get sourceTargetLrc => 'Оригинал + перевод LRC';

  @override
  String get sourceFirstDescription => 'Оригинал + перевод в одном файле';

  @override
  String get sourceTargetSrt => 'Оригинал + перевод SRT';

  @override
  String get outputSettingsSaved => 'Настройки вывода сохранены';

  @override
  String get readingLyricsCache => 'Чтение кэша текстов…';

  @override
  String pushingCacheProgress(Object arg1, Object arg2, Object arg3) {
    return 'Отправка $arg1/$arg2: $arg3';
  }

  @override
  String get noLyricsCacheToPush => 'Нет кэша текстов Kikoeta для отправки';

  @override
  String cachePushCompleted(Object arg1, Object arg2) {
    return 'Отправка завершена: успешно — $arg1, ошибок — $arg2';
  }

  @override
  String cachePushFailed(Object arg1) {
    return 'Отправка не завершена: $arg1';
  }

  @override
  String get files => 'Файлы';

  @override
  String get outputDirectory => 'Папка вывода';

  @override
  String get outputDirectoryHint =>
      'Оставьте пустым для сохранения рядом с исходным файлом';

  @override
  String get chooseDirectory => 'Выбрать папку';

  @override
  String get useSourceDirectory => 'Использовать исходную папку';

  @override
  String get format => 'Формат';

  @override
  String get outputFormat => 'Формат вывода';

  @override
  String get llsSyncTitle =>
      'Отправлять результаты запросов Kikoeta в Kikoeta-LLS';

  @override
  String get llsSyncDescription =>
      'Отправляет текст после успешного завершения; локальные задачи не затрагиваются';

  @override
  String get llsUrl => 'Адрес Kikoeta-LLS (HTTP/HTTPS)';

  @override
  String get llsUrlHint =>
      'Оставьте пустым для локального http://127.0.0.1:2378';

  @override
  String get uploadAuthentication => 'Авторизация отправки';

  @override
  String get twelveCharacterKey => 'Ключ из 12 символов';

  @override
  String get separateCredentials => 'Отдельные логин и пароль';

  @override
  String get uploadKey => 'Ключ отправки';

  @override
  String get uploadKeyHint =>
      'Создайте или задайте ключ из 12 символов в настройках Kikoeta-LLS';

  @override
  String get uploadUsername => 'Логин для отправки';

  @override
  String get uploadPassword => 'Пароль для отправки';

  @override
  String get lyricsCache => 'Кэш текстов';

  @override
  String get lyricsCacheDescription =>
      'Отправьте LRC из кэша последних 5 задач Kikoeta с указанными выше адресом и авторизацией. Автосинхронизация не требуется. Одноимённые файлы заменяются; локальный кэш сохраняется.';

  @override
  String get pushingCache => 'Отправка…';

  @override
  String get pushCacheToLls => 'Отправить кэш в LLS';

  @override
  String get viewFailureDetails => 'Подробности ошибок';

  @override
  String get asrPresetSaved => 'Пресет ASR сохранён';

  @override
  String presetSwitchFailed(Object arg1) {
    return 'Не удалось сменить пресет: $arg1';
  }

  @override
  String get asrParametersDescription =>
      'Параметры CrispASR для распознавания медиа. При вводе субтитров этот этап пропускается.';

  @override
  String get basicSegmentation => 'Основные параметры и сегментация';

  @override
  String get startOffsetMs => 'Начальное смещение (мс)';

  @override
  String get segmentOffset => 'Смещение начального сегмента';

  @override
  String get processingDurationMs => 'Длительность обработки (мс)';

  @override
  String get zeroMeansAll => '0 — весь файл';

  @override
  String get maxTextContext => 'Максимальный текстовый контекст';

  @override
  String get maxSegmentLength => 'Максимальная длина сегмента';

  @override
  String get chunkSecondsWithoutVad => 'Длина фрагмента без VAD (с)';

  @override
  String get chunkOverlapSeconds => 'Перекрытие фрагментов (с)';

  @override
  String get forceAligner => 'Принудительное выравнивание';

  @override
  String get splitOnPunctuation => 'Разбивать по знакам препинания';

  @override
  String get splitOnWord => 'Разбивать по словам';

  @override
  String get vadAndPunctuation => 'VAD и пунктуация';

  @override
  String get disablePunctuation => 'Отключить пунктуацию';

  @override
  String get maxSpeechSeconds => 'Максимальная длительность речи (с)';

  @override
  String get minSilenceMs => 'Минимальная тишина (мс)';

  @override
  String get vadModel => 'Модель VAD';

  @override
  String get vadModelHint => 'Введите псевдоним модели или путь';

  @override
  String get vadThreshold => 'Порог VAD';

  @override
  String get hotwords => 'Ключевые слова через запятую';

  @override
  String get recognitionSensitivity => 'Чувствительность распознавания';

  @override
  String get punctuationModel => 'Модель пунктуации';

  @override
  String get leaveEmptyForDefault =>
      'Оставьте пустым для значения по умолчанию';

  @override
  String get truecaseModel => 'Модель регистра';

  @override
  String get truecaseModelHint => 'auto или путь к модели';

  @override
  String get flushSrtEveryN => 'Сохранять SRT каждые N сегментов';

  @override
  String get flushSrtHint => '1 — выводить журнал каждого сегмента';

  @override
  String get decoding => 'Декодирование';

  @override
  String get bestOf => 'Число кандидатов best-of';

  @override
  String get audioContext => 'Аудиоконтекст';

  @override
  String get wordTimestampThreshold => 'Порог временных меток слов';

  @override
  String get entropyThreshold => 'Порог энтропии';

  @override
  String get logProbabilityThreshold => 'Порог логарифма вероятности';

  @override
  String get noSpeechThreshold => 'Порог отсутствия речи';

  @override
  String get randomSeed => 'Случайное зерно';

  @override
  String get disableTemperatureFallback => 'Отключить резервную температуру';

  @override
  String get device => 'Устройство';

  @override
  String get disableGpu => 'Отключить GPU';

  @override
  String get threads => 'Потоки';

  @override
  String get processors => 'Процессоры';

  @override
  String get gpuDeviceIndex => 'Индекс устройства GPU';

  @override
  String get gpuBackend => 'Бэкенд GPU';

  @override
  String get advancedTemplate => 'Расширенный шаблон';

  @override
  String get restoreDefaults => 'Восстановить значения';

  @override
  String get editCommandTemplate => 'Изменить шаблон команды';

  @override
  String get fullCommandTemplate => 'Полный шаблон команды';

  @override
  String get commandTemplateHint =>
      'Создаётся из параметров выше; можно изменить вручную и сохранить';

  @override
  String get commandTemplateDescription =>
      'При сохранении ручных изменений известные параметры разбираются, а неизвестные сохраняются в шаблоне.';

  @override
  String get fileNotFound => 'Файл не существует';

  @override
  String openFileFailed(Object arg1) {
    return 'Не удалось открыть файл: $arg1';
  }

  @override
  String get deleteTranslationCacheTitle => 'Удалить кэш перевода?';

  @override
  String get deleteTranslationCacheDescription =>
      'Удаляется только рабочий кэш GalTransl этой задачи. Экспортированные файлы и кэш синхронизации текстов Kikoeta сохраняются.';

  @override
  String get deleteCache => 'Удалить кэш';

  @override
  String cacheFreed(Object arg1) {
    return 'Очищено кэша перевода: $arg1';
  }

  @override
  String cleanupFailed(Object arg1) {
    return 'Ошибка очистки: $arg1';
  }

  @override
  String get deleteRecentTitle => 'Удалить эту запись?';

  @override
  String get deleteRecentDescription =>
      'Удаляются рабочие файлы, кэш и запись задачи из списка недавних. Экспортированные файлы сохраняются.';

  @override
  String get deleteRecord => 'Удалить запись';

  @override
  String get recordDeleted =>
      'Запись удалена; экспортированные файлы сохранены';

  @override
  String deleteFailed(Object arg1) {
    return 'Ошибка удаления: $arg1';
  }

  @override
  String get deleteAllRecentTitle => 'Удалить все недавние записи?';

  @override
  String deleteAllRecentDescription(Object arg1) {
    return 'Удаляются рабочие файлы и кэш для записей: $arg1. Экспортированные файлы сохраняются.';
  }

  @override
  String get deleteAll => 'Удалить всё';

  @override
  String recordsDeleted(Object arg1) {
    return 'Удалено записей: $arg1; экспортированные файлы сохранены';
  }

  @override
  String get legacyTask => 'Старая задача';

  @override
  String get recentDescription =>
      'Недавние переводы и рабочий кэш GalTransl. Очистка кэша сохраняет экспортированные файлы.';

  @override
  String get deleteAllRecords => 'Удалить все записи';

  @override
  String get refresh => 'Обновить';

  @override
  String get loadFailed => 'Ошибка загрузки';

  @override
  String get translationHistory => 'История переводов';

  @override
  String get noTranslationCache => 'Кэша переводов нет';

  @override
  String get kikoetaSourceSuffix => ' · Из Kikoeta';

  @override
  String get statusCompleted => 'Завершено';

  @override
  String get statusFailed => 'Ошибка';

  @override
  String get statusCancelled => 'Отменено';

  @override
  String recentTaskDetails(Object arg1, Object arg2, Object arg3, Object arg4) {
    return '$arg1 · $arg2$arg3 · Кэш $arg4';
  }

  @override
  String get clearing => 'Очистка';

  @override
  String get deleteRecordKeepOutput => 'Удалить запись (сохранить экспорт)';

  @override
  String get noLyricsOutput => 'Нет готовых текстов для показа';

  @override
  String get open => 'Открыть';

  @override
  String get fileMoved => 'Файл перемещён';

  @override
  String get invalidRemoteCredentials =>
      'Недопустимый логин или пароль удалённого доступа';

  @override
  String get remoteRestartFailed =>
      'Не удалось перезапустить службу удалённого доступа';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get remoteCredentialsRequired =>
      'Укажите логин и пароль удалённого доступа';

  @override
  String get remoteUsernameColon =>
      'Логин удалённого доступа не может содержать двоеточие';

  @override
  String get remoteCredentialsReset =>
      'Данные удалённого доступа сброшены: admin / kikoeta';

  @override
  String get toolsRefreshed => 'Обнаружение инструментов обновлено';

  @override
  String get releaseMissingVersion => 'В GitHub Release не указана версия';

  @override
  String githubStatus(Object arg1) {
    return 'GitHub вернул $arg1';
  }

  @override
  String releaseFeedStatus(Object arg1) {
    return 'GitHub API вернул 403; лента выпусков вернула $arg1';
  }

  @override
  String get releaseFeedEmpty => 'В ленте нет выпусков';

  @override
  String get releaseFeedMissingVersion => 'В ленте выпусков не указана версия';

  @override
  String get invalidVersion => 'Неверный формат версии';

  @override
  String updateAvailable(Object arg1, Object arg2) {
    return 'Доступна версия $arg1 (текущая: $arg2)';
  }

  @override
  String alreadyLatest(Object arg1) {
    return 'Установлена последняя версия ($arg1)';
  }

  @override
  String updateCheckFailed(Object arg1) {
    return 'Ошибка проверки обновлений: $arg1';
  }

  @override
  String get tools => 'Инструменты';

  @override
  String get notDetected => 'Не обнаружено';

  @override
  String get executableNotFound => 'Исполняемый файл не найден';

  @override
  String get paths => 'Пути';

  @override
  String get ffmpegPath => 'Путь к ffmpeg';

  @override
  String get crispAsrDirectory => 'Папка CrispASR';

  @override
  String get httpProxy => 'HTTP-прокси';

  @override
  String get chooseCrispAsrDirectory => 'Выбрать папку CrispASR';

  @override
  String get interfaceAndService => 'Интерфейс и служба';

  @override
  String get theme => 'Тема';

  @override
  String get followSystem => 'Как в системе';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Тёмная';

  @override
  String get allowRemoteAccess => 'Разрешить удалённый доступ';

  @override
  String get remoteListenAll => 'Прослушивается 0.0.0.0:2370';

  @override
  String get remoteListenLocal => 'Прослушивается только 127.0.0.1:2370';

  @override
  String get remoteAuthentication => 'Авторизация удалённого доступа';

  @override
  String get username => 'Логин';

  @override
  String get password => 'Пароль';

  @override
  String get resetRemoteCredentials => 'Сбросить данные доступа';

  @override
  String get reset => 'Сбросить';

  @override
  String get about => 'О приложении';

  @override
  String get repository => 'Репозиторий проекта';

  @override
  String get checkingUpdate => 'Проверка…';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get exportLogs => 'Экспорт журнала';

  @override
  String get logsExported => 'Журнал экспортирован';

  @override
  String logExportFailed(Object arg1) {
    return 'Не удалось экспортировать журнал: $arg1';
  }

  @override
  String get statusQueued => 'В очереди';

  @override
  String get statusRunning => 'Обработка';

  @override
  String get statusPausing => 'Приостановка';

  @override
  String get statusPaused => 'Приостановлено';

  @override
  String get statusCancelling => 'Отмена';

  @override
  String get processingStages => 'Этапы обработки';

  @override
  String get transcodeAndAsr => 'Конвертация + ASR';

  @override
  String get transcodeDescription =>
      'Обязательно для аудио/видео; пропускается для субтитров';

  @override
  String get fixed => 'Обязательно';

  @override
  String get correctionStageDescription =>
      'Только исправление распознавания, без перевода';

  @override
  String get translationStageDescription =>
      'Используется настроенный переводчик';

  @override
  String get inputFiles => 'Входные файлы';

  @override
  String get clearFileList => 'Очистить список';

  @override
  String get dropFilesHint =>
      'Перетащите аудио, видео или субтитры либо нажмите для выбора';

  @override
  String selectedFiles(Object arg1) {
    return 'Выбрано файлов: $arg1; нажмите для добавления';
  }

  @override
  String get removeFile => 'Убрать файл';

  @override
  String get submitting => 'Отправка…';

  @override
  String get stopping => 'Остановка…';

  @override
  String get stopWorkflow => 'Остановить процесс';

  @override
  String get startProcessing => 'Начать обработку';

  @override
  String get currentWorkflow => 'Текущий процесс';

  @override
  String get fromKikoeta => 'Из Kikoeta';

  @override
  String get localTask => 'Локальная задача';

  @override
  String get logs => 'Журнал';

  @override
  String get noLogs => 'Журнал пока пуст';

  @override
  String get pythonNotFound => 'Подходящий интерпретатор Python 3 не найден';

  @override
  String get engineScriptNotFound => 'Файл engine/server.py не найден';

  @override
  String pythonStartFailed(Object arg1) {
    return 'Не удалось запустить Python: $arg1';
  }

  @override
  String get engineTimeout => 'Истекло время ожидания движка';

  @override
  String engineTimeoutDetails(Object arg1) {
    return 'Истекло время ожидания движка: $arg1';
  }

  @override
  String engineExitedCode(Object arg1) {
    return 'Движок завершился (код $arg1)';
  }

  @override
  String engineExitedDetails(Object arg1) {
    return 'Движок завершился: $arg1';
  }

  @override
  String get jobSubmitFailed => 'Не удалось отправить задачу';

  @override
  String get recentLoadFailed => 'Не удалось загрузить недавние задачи';

  @override
  String get cacheClearFailed => 'Не удалось очистить кэш';

  @override
  String get recentDeleteFailed => 'Не удалось удалить недавнюю запись';

  @override
  String get lyricsCacheLoadFailed => 'Не удалось загрузить кэш текстов';

  @override
  String get lyricsCachePushFailed => 'Не удалось отправить кэш текстов';

  @override
  String get ffmpegNotFound =>
      'ffmpeg не найден. Поместите ffmpeg.exe в bin/ffmpeg/bin.';

  @override
  String get autoDetectLanguage => 'auto · Автоопределение';

  @override
  String get forNovelTranslator => 'ForNovel · Романы / другой текст';

  @override
  String get galtranslSakuraTranslator => 'galtransl-v3 · API Sakura';

  @override
  String get sakuraTranslator => 'sakura-v1.0 · API Sakura';

  @override
  String get presetNameRequired => 'Введите имя пресета';

  @override
  String get presetNameExists => 'Такое имя уже существует; укажите другое';

  @override
  String get saveAsrPresetAs => 'Сохранить пресет ASR как';

  @override
  String get presetName => 'Имя пресета';

  @override
  String get comboInputHint => 'Введите или выберите из списка';

  @override
  String get openList => 'Открыть список';

  @override
  String get noPresetOptions => 'Готовых вариантов нет; введите значение';

  @override
  String get saveAs => 'Сохранить как';

  @override
  String get presets => 'Пресеты';

  @override
  String get asrPreset => 'Пресет ASR';

  @override
  String basePresetLabel(Object arg1) {
    return '$arg1 (встроенный)';
  }

  @override
  String get basePresetDescription =>
      'Изменения встроенных пресетов сохраняются под новым именем. При выходе со страницы создаётся пользовательский пресет.';

  @override
  String get restorePreset => 'Восстановить пресет';

  @override
  String get uiLanguage => 'Язык интерфейса';

  @override
  String get llamaStopped => 'Остановлено';

  @override
  String get llamaStarting => 'Запуск';

  @override
  String get llamaReady => 'Готово';
}
