import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('ko'),
  ];

  /// No description provided for @aboutTooltip.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get aboutTooltip;

  /// No description provided for @aboutVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전 {version} (빌드 {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutRepository.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @aboutMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 정보'**
  String aboutMenuItem(String appName);

  /// No description provided for @themeMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get themeMenuTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageMenuTooltip;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기 / System'**
  String get languageSystem;

  /// No description provided for @languageSystemShort.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get languageSystemShort;

  /// No description provided for @aboutTagline.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트마다 알맞은 VS Code 프로필을 골라 줍니다'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'로컬 또는 SSH 프로젝트 폴더를 분석해 유형을 판정하고, VS Code 프로필과 설정을 추천한 뒤 code --profile 로 열어 줍니다.'**
  String get aboutDescription;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'시작하려면 프로젝트 폴더를 끌어다 놓으세요'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyAction.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트 추가'**
  String get homeEmptyAction;

  /// No description provided for @updateCheckMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 확인'**
  String get updateCheckMenuItem;

  /// No description provided for @updateChecking.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하는 중…'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 있습니다'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} {latest} 버전이 나왔습니다. (현재 {current})'**
  String updateAvailableBody(String appName, String current, String latest);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In ko, this message translates to:
  /// **'변경 내용'**
  String get updateReleaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateLater;

  /// No description provided for @updateSkipVersion.
  ///
  /// In ko, this message translates to:
  /// **'이 버전 건너뛰기'**
  String get updateSkipVersion;

  /// No description provided for @updateDownloading.
  ///
  /// In ko, this message translates to:
  /// **'내려받는 중…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In ko, this message translates to:
  /// **'파일을 확인하는 중…'**
  String get updateVerifying;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In ko, this message translates to:
  /// **'{received} / {total}'**
  String updateDownloadProgress(String received, String total);

  /// No description provided for @updateCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get updateCancel;

  /// No description provided for @updateFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트하지 못했습니다'**
  String get updateFailedTitle;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하지 못했습니다'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In ko, this message translates to:
  /// **'내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorInstall.
  ///
  /// In ko, this message translates to:
  /// **'설치를 시작하지 못했습니다.'**
  String get updateErrorInstall;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorGeneric;

  /// No description provided for @updateUpToDateTitle.
  ///
  /// In ko, this message translates to:
  /// **'최신 버전입니다'**
  String get updateUpToDateTitle;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In ko, this message translates to:
  /// **'{version} 버전을 사용 중입니다.'**
  String updateUpToDateBody(String version);

  /// No description provided for @updateUnavailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'직접 설치해 주세요'**
  String get updateUnavailableTitle;

  /// No description provided for @updateUnavailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{latest} 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.'**
  String updateUnavailableBody(String latest);

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In ko, this message translates to:
  /// **'릴리스 페이지 열기'**
  String get updateOpenReleasePage;

  /// No description provided for @updateBrowserDownloadTitle.
  ///
  /// In ko, this message translates to:
  /// **'브라우저에서 내려받습니다'**
  String get updateBrowserDownloadTitle;

  /// No description provided for @updateBrowserDownloadBody.
  ///
  /// In ko, this message translates to:
  /// **'브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateBrowserDownloadBody(String appName);

  /// No description provided for @updateMacosOpenedTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 창이 열렸습니다'**
  String get updateMacosOpenedTitle;

  /// No description provided for @updateMacosOpenedBody.
  ///
  /// In ko, this message translates to:
  /// **'열린 창에서 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateMacosOpenedBody(String appName);

  /// No description provided for @updateWindowsInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 프로그램을 열었습니다'**
  String get updateWindowsInstallTitle;

  /// No description provided for @updateWindowsInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'설치하려면 {appName} 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.'**
  String updateWindowsInstallBody(String appName);

  /// No description provided for @updateQuitApp.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 종료'**
  String updateQuitApp(String appName);

  /// No description provided for @updateLinuxInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치를 준비했습니다'**
  String get updateLinuxInstallTitle;

  /// No description provided for @updateLinuxInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.'**
  String updateLinuxInstallBody(String appName);

  /// No description provided for @updateQuitAndInstall.
  ///
  /// In ko, this message translates to:
  /// **'종료하고 설치'**
  String get updateQuitAndInstall;

  /// No description provided for @updateBusyTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금은 업데이트할 수 없습니다'**
  String get updateBusyTitle;

  /// No description provided for @updateBusyBody.
  ///
  /// In ko, this message translates to:
  /// **'작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.'**
  String get updateBusyBody;

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// No description provided for @commonCopy.
  ///
  /// In ko, this message translates to:
  /// **'복사'**
  String get commonCopy;

  /// No description provided for @appSettingsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get appSettingsTooltip;

  /// No description provided for @projectAdd.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트 추가'**
  String get projectAdd;

  /// No description provided for @projectPickFolderTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트 폴더 선택'**
  String get projectPickFolderTitle;

  /// No description provided for @projectDropHere.
  ///
  /// In ko, this message translates to:
  /// **'여기에 놓아 프로젝트 추가'**
  String get projectDropHere;

  /// No description provided for @projectDropNotFolder.
  ///
  /// In ko, this message translates to:
  /// **'폴더만 추가할 수 있습니다: {name}'**
  String projectDropNotFolder(String name);

  /// No description provided for @projectOpen.
  ///
  /// In ko, this message translates to:
  /// **'VS Code로 열기'**
  String get projectOpen;

  /// No description provided for @projectOpenNeedsProfile.
  ///
  /// In ko, this message translates to:
  /// **'먼저 분석하고 설정을 적용하세요'**
  String get projectOpenNeedsProfile;

  /// No description provided for @projectAnalyze.
  ///
  /// In ko, this message translates to:
  /// **'분석 · 추천'**
  String get projectAnalyze;

  /// No description provided for @projectRemove.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 제거'**
  String get projectRemove;

  /// No description provided for @projectRemoveTitle.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트를 목록에서 제거할까요?'**
  String get projectRemoveTitle;

  /// No description provided for @projectRemoveBody.
  ///
  /// In ko, this message translates to:
  /// **'{name} 은(는) 목록에서만 지워지고, 폴더와 파일은 그대로 남습니다.'**
  String projectRemoveBody(String name);

  /// No description provided for @projectNoAnalysis.
  ///
  /// In ko, this message translates to:
  /// **'분석 전'**
  String get projectNoAnalysis;

  /// No description provided for @projectNoProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필 없음'**
  String get projectNoProfile;

  /// No description provided for @projectLastOpened.
  ///
  /// In ko, this message translates to:
  /// **'마지막 열기 {date}'**
  String projectLastOpened(String date);

  /// No description provided for @projectNeverOpened.
  ///
  /// In ko, this message translates to:
  /// **'열어 본 적 없음'**
  String get projectNeverOpened;

  /// No description provided for @projectLoadError.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트 목록을 읽지 못했습니다: {message}'**
  String projectLoadError(String message);

  /// No description provided for @projectLocal.
  ///
  /// In ko, this message translates to:
  /// **'로컬'**
  String get projectLocal;

  /// No description provided for @openFailed.
  ///
  /// In ko, this message translates to:
  /// **'VS Code를 열지 못했습니다: {message}'**
  String openFailed(String message);

  /// No description provided for @analysisTitle.
  ///
  /// In ko, this message translates to:
  /// **'분석 결과'**
  String get analysisTitle;

  /// No description provided for @analysisRunning.
  ///
  /// In ko, this message translates to:
  /// **'폴더를 분석하는 중…'**
  String get analysisRunning;

  /// No description provided for @analysisFailed.
  ///
  /// In ko, this message translates to:
  /// **'분석에 실패했습니다'**
  String get analysisFailed;

  /// No description provided for @analysisNoTypes.
  ///
  /// In ko, this message translates to:
  /// **'판정된 프로젝트 유형이 없습니다. 폴더 구성을 확인하거나 사용자 규칙을 추가하세요.'**
  String get analysisNoTypes;

  /// No description provided for @analysisPrimaryBadge.
  ///
  /// In ko, this message translates to:
  /// **'주 유형'**
  String get analysisPrimaryBadge;

  /// No description provided for @analysisPriority.
  ///
  /// In ko, this message translates to:
  /// **'우선순위 {value}'**
  String analysisPriority(String value);

  /// No description provided for @analysisCompetitorsTitle.
  ///
  /// In ko, this message translates to:
  /// **'근접 경쟁 후보'**
  String get analysisCompetitorsTitle;

  /// No description provided for @analysisCompetitorsBody.
  ///
  /// In ko, this message translates to:
  /// **'{names} 도 비슷한 우선순위로 맞았지만 다른 프로필을 씁니다. 추천 편집 화면에서 바꿀 수 있습니다.'**
  String analysisCompetitorsBody(String names);

  /// No description provided for @analysisStats.
  ///
  /// In ko, this message translates to:
  /// **'스캔한 파일 {count}개'**
  String analysisStats(String count);

  /// No description provided for @analysisTruncated.
  ///
  /// In ko, this message translates to:
  /// **'파일 수 상한에서 스캔을 멈췄습니다. 작업 모듈 폴더만 여는 것을 권장합니다.'**
  String get analysisTruncated;

  /// No description provided for @analysisSkippedDirs.
  ///
  /// In ko, this message translates to:
  /// **'들어가지 않은 폴더: {names}'**
  String analysisSkippedDirs(String names);

  /// No description provided for @analysisVariables.
  ///
  /// In ko, this message translates to:
  /// **'해석된 변수'**
  String get analysisVariables;

  /// No description provided for @analysisNext.
  ///
  /// In ko, this message translates to:
  /// **'추천 보기'**
  String get analysisNext;

  /// No description provided for @recommendTitle.
  ///
  /// In ko, this message translates to:
  /// **'추천 편집'**
  String get recommendTitle;

  /// No description provided for @recommendPrimaryType.
  ///
  /// In ko, this message translates to:
  /// **'주 유형'**
  String get recommendPrimaryType;

  /// No description provided for @recommendProfile.
  ///
  /// In ko, this message translates to:
  /// **'프로필 이름'**
  String get recommendProfile;

  /// No description provided for @recommendProfileHelp.
  ///
  /// In ko, this message translates to:
  /// **'VS Code 프로필 이름입니다. 없으면 새로 만들어집니다.'**
  String get recommendProfileHelp;

  /// No description provided for @recommendProfileSuggestions.
  ///
  /// In ko, this message translates to:
  /// **'추천 이름'**
  String get recommendProfileSuggestions;

  /// No description provided for @recommendProfileEmpty.
  ///
  /// In ko, this message translates to:
  /// **'프로필 이름을 입력하세요'**
  String get recommendProfileEmpty;

  /// No description provided for @recommendProfileInvalid.
  ///
  /// In ko, this message translates to:
  /// **'프로필 이름에 쓸 수 없는 문자가 있습니다'**
  String get recommendProfileInvalid;

  /// No description provided for @recommendExtensionsRequired.
  ///
  /// In ko, this message translates to:
  /// **'추천 확장'**
  String get recommendExtensionsRequired;

  /// No description provided for @recommendExtensionsOptional.
  ///
  /// In ko, this message translates to:
  /// **'선택 확장 (다른 유형)'**
  String get recommendExtensionsOptional;

  /// No description provided for @recommendSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 패치'**
  String get recommendSettings;

  /// No description provided for @recommendSettingsCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 항목'**
  String recommendSettingsCount(String count);

  /// No description provided for @recommendNotes.
  ///
  /// In ko, this message translates to:
  /// **'안내'**
  String get recommendNotes;

  /// No description provided for @recommendNone.
  ///
  /// In ko, this message translates to:
  /// **'추천할 내용이 없습니다'**
  String get recommendNone;

  /// No description provided for @recommendNext.
  ///
  /// In ko, this message translates to:
  /// **'설정 비교'**
  String get recommendNext;

  /// No description provided for @diffTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정 비교'**
  String get diffTitle;

  /// No description provided for @diffLoading.
  ///
  /// In ko, this message translates to:
  /// **'비교하는 중…'**
  String get diffLoading;

  /// No description provided for @diffFailed.
  ///
  /// In ko, this message translates to:
  /// **'비교하지 못했습니다'**
  String get diffFailed;

  /// No description provided for @diffNewFile.
  ///
  /// In ko, this message translates to:
  /// **'settings.json 이 새로 만들어집니다.'**
  String get diffNewFile;

  /// No description provided for @diffNoChange.
  ///
  /// In ko, this message translates to:
  /// **'settings.json 은 바뀌지 않습니다.'**
  String get diffNoChange;

  /// No description provided for @diffCommentsWarning.
  ///
  /// In ko, this message translates to:
  /// **'기존 settings.json 의 주석이 사라집니다. 적용하기 전에 .bak 백업이 만들어집니다.'**
  String get diffCommentsWarning;

  /// No description provided for @diffAdded.
  ///
  /// In ko, this message translates to:
  /// **'추가 ({count})'**
  String diffAdded(String count);

  /// No description provided for @diffConflicts.
  ///
  /// In ko, this message translates to:
  /// **'충돌 — 기존 값 유지 ({count})'**
  String diffConflicts(String count);

  /// No description provided for @diffUnchanged.
  ///
  /// In ko, this message translates to:
  /// **'변경 없음 ({count})'**
  String diffUnchanged(String count);

  /// No description provided for @diffReplace.
  ///
  /// In ko, this message translates to:
  /// **'패치 값으로 교체'**
  String get diffReplace;

  /// No description provided for @diffExisting.
  ///
  /// In ko, this message translates to:
  /// **'기존'**
  String get diffExisting;

  /// No description provided for @diffPatch.
  ///
  /// In ko, this message translates to:
  /// **'패치'**
  String get diffPatch;

  /// No description provided for @diffMergedPreview.
  ///
  /// In ko, this message translates to:
  /// **'적용 후 파일 내용'**
  String get diffMergedPreview;

  /// No description provided for @diffApply.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get diffApply;

  /// No description provided for @applyTitle.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get applyTitle;

  /// No description provided for @applyStepExtensions.
  ///
  /// In ko, this message translates to:
  /// **'확장 설치'**
  String get applyStepExtensions;

  /// No description provided for @applyStepSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 쓰기'**
  String get applyStepSettings;

  /// No description provided for @applyNoExtensions.
  ///
  /// In ko, this message translates to:
  /// **'설치할 확장이 없습니다.'**
  String get applyNoExtensions;

  /// No description provided for @applyExtSkipped.
  ///
  /// In ko, this message translates to:
  /// **'이미 설치됨: {id}'**
  String applyExtSkipped(String id);

  /// No description provided for @applyExtInstalling.
  ///
  /// In ko, this message translates to:
  /// **'설치 중: {id}'**
  String applyExtInstalling(String id);

  /// No description provided for @applyExtFailed.
  ///
  /// In ko, this message translates to:
  /// **'설치 실패: {id} (종료 코드 {code})'**
  String applyExtFailed(String id, String code);

  /// No description provided for @applySettingsWritten.
  ///
  /// In ko, this message translates to:
  /// **'settings.json 을 갱신했습니다.'**
  String get applySettingsWritten;

  /// No description provided for @applySettingsBackup.
  ///
  /// In ko, this message translates to:
  /// **'백업: {path}'**
  String applySettingsBackup(String path);

  /// No description provided for @applySettingsUnchanged.
  ///
  /// In ko, this message translates to:
  /// **'바뀐 내용이 없어 파일을 쓰지 않았습니다.'**
  String get applySettingsUnchanged;

  /// No description provided for @applyDone.
  ///
  /// In ko, this message translates to:
  /// **'적용을 마쳤습니다'**
  String get applyDone;

  /// No description provided for @applyFailedStep.
  ///
  /// In ko, this message translates to:
  /// **'{step} 단계에서 실패했습니다: {message}'**
  String applyFailedStep(String step, String message);

  /// No description provided for @applySaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'프로젝트 정보를 저장하지 못했습니다: {message}'**
  String applySaveFailed(String message);

  /// No description provided for @applyBackToList.
  ///
  /// In ko, this message translates to:
  /// **'목록으로'**
  String get applyBackToList;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsCodePath.
  ///
  /// In ko, this message translates to:
  /// **'VS Code 실행 파일(code) 경로'**
  String get settingsCodePath;

  /// No description provided for @settingsCodePathHint.
  ///
  /// In ko, this message translates to:
  /// **'비워 두면 자동으로 찾습니다'**
  String get settingsCodePathHint;

  /// No description provided for @settingsDetect.
  ///
  /// In ko, this message translates to:
  /// **'자동 탐지'**
  String get settingsDetect;

  /// No description provided for @settingsBrowse.
  ///
  /// In ko, this message translates to:
  /// **'찾아보기'**
  String get settingsBrowse;

  /// No description provided for @settingsTest.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get settingsTest;

  /// No description provided for @settingsSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get settingsSave;

  /// No description provided for @settingsDetected.
  ///
  /// In ko, this message translates to:
  /// **'찾은 경로: {path}'**
  String settingsDetected(String path);

  /// No description provided for @settingsNotFound.
  ///
  /// In ko, this message translates to:
  /// **'VS Code를 찾지 못했습니다. 경로를 직접 지정하세요.'**
  String get settingsNotFound;

  /// No description provided for @settingsTestOk.
  ///
  /// In ko, this message translates to:
  /// **'VS Code {version}'**
  String settingsTestOk(String version);

  /// No description provided for @settingsTestFailed.
  ///
  /// In ko, this message translates to:
  /// **'실행하지 못했습니다: {message}'**
  String settingsTestFailed(String message);

  /// No description provided for @settingsSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장했습니다'**
  String get settingsSaved;
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
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
