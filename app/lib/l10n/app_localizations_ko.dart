// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutTooltip => '정보';

  @override
  String aboutVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get aboutOpenSourceLicenses => '오픈소스 라이선스';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => '닫기';

  @override
  String aboutMenuItem(String appName) {
    return '$appName 정보';
  }

  @override
  String get themeMenuTooltip => '테마';

  @override
  String get themeSystem => '시스템 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get languageMenuTooltip => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기 / System';

  @override
  String get languageSystemShort => '시스템';

  @override
  String get aboutTagline => '프로젝트마다 알맞은 VS Code 프로필을 골라 줍니다';

  @override
  String get aboutDescription =>
      '로컬 또는 SSH 프로젝트 폴더를 분석해 유형을 판정하고, VS Code 프로필과 설정을 추천한 뒤 code --profile 로 열어 줍니다.';

  @override
  String get homeEmptyTitle => '시작하려면 프로젝트 폴더를 끌어다 놓으세요';

  @override
  String get homeEmptyAction => '프로젝트 추가';

  @override
  String get updateCheckMenuItem => '업데이트 확인';

  @override
  String get updateChecking => '업데이트를 확인하는 중…';

  @override
  String get updateAvailableTitle => '새 버전이 있습니다';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest 버전이 나왔습니다. (현재 $current)';
  }

  @override
  String get updateReleaseNotes => '변경 내용';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateDownloading => '내려받는 중…';

  @override
  String get updateVerifying => '파일을 확인하는 중…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => '취소';

  @override
  String get updateFailedTitle => '업데이트하지 못했습니다';

  @override
  String get updateCheckFailedTitle => '업데이트를 확인하지 못했습니다';

  @override
  String get updateErrorNetwork =>
      '업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get updateErrorChecksum =>
      '내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateErrorInstall => '설치를 시작하지 못했습니다.';

  @override
  String get updateErrorGeneric =>
      '업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateUpToDateTitle => '최신 버전입니다';

  @override
  String updateUpToDateBody(String version) {
    return '$version 버전을 사용 중입니다.';
  }

  @override
  String get updateUnavailableTitle => '직접 설치해 주세요';

  @override
  String updateUnavailableBody(String latest) {
    return '$latest 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.';
  }

  @override
  String get updateOpenReleasePage => '릴리스 페이지 열기';

  @override
  String get updateBrowserDownloadTitle => '브라우저에서 내려받습니다';

  @override
  String updateBrowserDownloadBody(String appName) {
    return '브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateMacosOpenedTitle => '설치 창이 열렸습니다';

  @override
  String updateMacosOpenedBody(String appName) {
    return '열린 창에서 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateWindowsInstallTitle => '설치 프로그램을 열었습니다';

  @override
  String updateWindowsInstallBody(String appName) {
    return '설치하려면 $appName 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.';
  }

  @override
  String updateQuitApp(String appName) {
    return '$appName 종료';
  }

  @override
  String get updateLinuxInstallTitle => '설치를 준비했습니다';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.';
  }

  @override
  String get updateQuitAndInstall => '종료하고 설치';

  @override
  String get updateBusyTitle => '지금은 업데이트할 수 없습니다';

  @override
  String get updateBusyBody => '작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.';

  @override
  String get commonCancel => '취소';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonCopy => '복사';

  @override
  String get appSettingsTooltip => '설정';

  @override
  String get projectAdd => '프로젝트 추가';

  @override
  String get projectPickFolderTitle => '프로젝트 폴더 선택';

  @override
  String get projectDropHere => '여기에 놓아 프로젝트 추가';

  @override
  String projectDropNotFolder(String name) {
    return '폴더만 추가할 수 있습니다: $name';
  }

  @override
  String get projectOpen => 'VS Code로 열기';

  @override
  String get projectOpenNeedsProfile => '먼저 분석하고 설정을 적용하세요';

  @override
  String get projectAnalyze => '분석 · 추천';

  @override
  String get projectRemove => '목록에서 제거';

  @override
  String get projectRemoveTitle => '프로젝트를 목록에서 제거할까요?';

  @override
  String projectRemoveBody(String name) {
    return '$name 은(는) 목록에서만 지워지고, 폴더와 파일은 그대로 남습니다.';
  }

  @override
  String get projectNoAnalysis => '분석 전';

  @override
  String get projectNoProfile => '프로필 없음';

  @override
  String projectLastOpened(String date) {
    return '마지막 열기 $date';
  }

  @override
  String get projectNeverOpened => '열어 본 적 없음';

  @override
  String projectLoadError(String message) {
    return '프로젝트 목록을 읽지 못했습니다: $message';
  }

  @override
  String get projectLocal => '로컬';

  @override
  String openFailed(String message) {
    return 'VS Code를 열지 못했습니다: $message';
  }

  @override
  String get analysisTitle => '분석 결과';

  @override
  String get analysisRunning => '폴더를 분석하는 중…';

  @override
  String get analysisFailed => '분석에 실패했습니다';

  @override
  String get analysisNoTypes =>
      '판정된 프로젝트 유형이 없습니다. 폴더 구성을 확인하거나 사용자 규칙을 추가하세요.';

  @override
  String get analysisPrimaryBadge => '주 유형';

  @override
  String analysisPriority(String value) {
    return '우선순위 $value';
  }

  @override
  String get analysisCompetitorsTitle => '근접 경쟁 후보';

  @override
  String analysisCompetitorsBody(String names) {
    return '$names 도 비슷한 우선순위로 맞았지만 다른 프로필을 씁니다. 추천 편집 화면에서 바꿀 수 있습니다.';
  }

  @override
  String analysisStats(String count) {
    return '스캔한 파일 $count개';
  }

  @override
  String get analysisTruncated => '파일 수 상한에서 스캔을 멈췄습니다. 작업 모듈 폴더만 여는 것을 권장합니다.';

  @override
  String analysisSkippedDirs(String names) {
    return '들어가지 않은 폴더: $names';
  }

  @override
  String get analysisVariables => '해석된 변수';

  @override
  String get analysisNext => '추천 보기';

  @override
  String get recommendTitle => '추천 편집';

  @override
  String get recommendPrimaryType => '주 유형';

  @override
  String get recommendProfile => '프로필 이름';

  @override
  String get recommendProfileHelp => 'VS Code 프로필 이름입니다. 없으면 새로 만들어집니다.';

  @override
  String get recommendProfileSuggestions => '추천 이름';

  @override
  String get recommendProfileEmpty => '프로필 이름을 입력하세요';

  @override
  String get recommendProfileInvalid => '프로필 이름에 쓸 수 없는 문자가 있습니다';

  @override
  String get recommendExtensionsRequired => '추천 확장';

  @override
  String get recommendExtensionsOptional => '선택 확장 (다른 유형)';

  @override
  String get recommendSettings => '설정 패치';

  @override
  String recommendSettingsCount(String count) {
    return '$count개 항목';
  }

  @override
  String get recommendNotes => '안내';

  @override
  String get recommendNone => '추천할 내용이 없습니다';

  @override
  String get recommendNext => '설정 비교';

  @override
  String get diffTitle => '설정 비교';

  @override
  String get diffLoading => '비교하는 중…';

  @override
  String get diffFailed => '비교하지 못했습니다';

  @override
  String get diffNewFile => 'settings.json 이 새로 만들어집니다.';

  @override
  String get diffNoChange => 'settings.json 은 바뀌지 않습니다.';

  @override
  String get diffCommentsWarning =>
      '기존 settings.json 의 주석이 사라집니다. 적용하기 전에 .bak 백업이 만들어집니다.';

  @override
  String diffAdded(String count) {
    return '추가 ($count)';
  }

  @override
  String diffConflicts(String count) {
    return '충돌 — 기존 값 유지 ($count)';
  }

  @override
  String diffUnchanged(String count) {
    return '변경 없음 ($count)';
  }

  @override
  String get diffReplace => '패치 값으로 교체';

  @override
  String get diffExisting => '기존';

  @override
  String get diffPatch => '패치';

  @override
  String get diffMergedPreview => '적용 후 파일 내용';

  @override
  String get diffApply => '적용';

  @override
  String get applyTitle => '적용';

  @override
  String get applyStepExtensions => '확장 설치';

  @override
  String get applyStepSettings => '설정 쓰기';

  @override
  String get applyNoExtensions => '설치할 확장이 없습니다.';

  @override
  String applyExtSkipped(String id) {
    return '이미 설치됨: $id';
  }

  @override
  String applyExtInstalling(String id) {
    return '설치 중: $id';
  }

  @override
  String applyExtFailed(String id, String code) {
    return '설치 실패: $id (종료 코드 $code)';
  }

  @override
  String get applySettingsWritten => 'settings.json 을 갱신했습니다.';

  @override
  String applySettingsBackup(String path) {
    return '백업: $path';
  }

  @override
  String get applySettingsUnchanged => '바뀐 내용이 없어 파일을 쓰지 않았습니다.';

  @override
  String get applyDone => '적용을 마쳤습니다';

  @override
  String applyFailedStep(String step, String message) {
    return '$step 단계에서 실패했습니다: $message';
  }

  @override
  String applySaveFailed(String message) {
    return '프로젝트 정보를 저장하지 못했습니다: $message';
  }

  @override
  String get applyBackToList => '목록으로';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionAppearance => '외형';

  @override
  String get settingsMode => '모드';

  @override
  String get settingsModeSystem => '시스템';

  @override
  String get settingsPalette => '색 구성';

  @override
  String get settingsPaletteSaturn => '새턴';

  @override
  String get settingsPaletteTeal => '청록';

  @override
  String get settingsPaletteAmber => '호박';

  @override
  String get settingsPaletteRose => '장미';

  @override
  String get settingsPaletteSlate => '슬레이트';

  @override
  String get settingsPaletteHighContrast => '고대비';

  @override
  String get settingsCodePath => 'VS Code 실행 파일(code) 경로';

  @override
  String get settingsCodePathHint => '비워 두면 자동으로 찾습니다';

  @override
  String get settingsDetect => '자동 탐지';

  @override
  String get settingsBrowse => '찾아보기';

  @override
  String get settingsTest => '확인';

  @override
  String get settingsSave => '저장';

  @override
  String settingsDetected(String path) {
    return '찾은 경로: $path';
  }

  @override
  String get settingsNotFound => 'VS Code를 찾지 못했습니다. 경로를 직접 지정하세요.';

  @override
  String settingsTestOk(String version) {
    return 'VS Code $version';
  }

  @override
  String settingsTestFailed(String message) {
    return '실행하지 못했습니다: $message';
  }

  @override
  String get settingsSaved => '저장했습니다';

  @override
  String get applyStepProfile => '프로필 준비';

  @override
  String applyProfileExists(String name) {
    return '프로필이 이미 있습니다: $name';
  }

  @override
  String applyProfileCreating(String name) {
    return '프로필이 없어 VS Code를 열어 새로 만듭니다: $name (수십 초 걸릴 수 있습니다)';
  }

  @override
  String applyProfileCreated(String name) {
    return '프로필을 만들었습니다: $name';
  }
}
