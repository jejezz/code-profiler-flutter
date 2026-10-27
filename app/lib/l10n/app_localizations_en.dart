// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystem => 'System / 시스템 설정 따르기';

  @override
  String get languageSystemShort => 'System';

  @override
  String get aboutTagline => 'Pick the right VS Code profile for every project';

  @override
  String get aboutDescription =>
      'Analyzes a local or SSH project folder, detects its type, and recommends a VS Code profile and settings, then opens it with code --profile.';

  @override
  String get homeEmptyTitle => 'Drop a project folder to get started';

  @override
  String get homeEmptyAction => 'Add project';

  @override
  String get updateCheckMenuItem => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest is available. You have $current.';
  }

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying the file…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateFailedTitle => 'Couldn\'t update';

  @override
  String get updateCheckFailedTitle => 'Couldn\'t check for updates';

  @override
  String get updateErrorNetwork =>
      'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric =>
      'The update server sent an unexpected response. Please try again later.';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'You\'re using version $version.';
  }

  @override
  String get updateUnavailableTitle => 'Install it manually';

  @override
  String updateUnavailableBody(String latest) {
    return 'Version $latest is available, but the app can\'t install it automatically. Please download it from the release page.';
  }

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateBrowserDownloadTitle => 'Downloading in your browser';

  @override
  String updateBrowserDownloadBody(String appName) {
    return 'Your browser is downloading the new version. Open the DMG and drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateMacosOpenedTitle => 'The installer window is open';

  @override
  String updateMacosOpenedBody(String appName) {
    return 'In the window that opened, drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateWindowsInstallTitle => 'The installer is open';

  @override
  String updateWindowsInstallBody(String appName) {
    return '$appName must quit before it can be updated. Follow the installer\'s instructions.';
  }

  @override
  String updateQuitApp(String appName) {
    return 'Quit $appName';
  }

  @override
  String get updateLinuxInstallTitle => 'Ready to install';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName will quit and install the update, then start again automatically.';
  }

  @override
  String get updateQuitAndInstall => 'Quit and install';

  @override
  String get updateBusyTitle => 'Can\'t update right now';

  @override
  String get updateBusyBody =>
      'A task is in progress. Please try again when it has finished.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy';

  @override
  String get appSettingsTooltip => 'Settings';

  @override
  String get projectAdd => 'Add project';

  @override
  String get projectPickFolderTitle => 'Choose a project folder';

  @override
  String get projectDropHere => 'Drop to add a project';

  @override
  String projectDropNotFolder(String name) {
    return 'Only folders can be added: $name';
  }

  @override
  String get projectOpen => 'Open in VS Code';

  @override
  String get projectOpenNeedsProfile =>
      'Analyze the project and apply the settings first';

  @override
  String get projectAnalyze => 'Analyze & recommend';

  @override
  String get projectRemove => 'Remove from list';

  @override
  String get projectRemoveTitle => 'Remove this project from the list?';

  @override
  String projectRemoveBody(String name) {
    return '$name is only removed from the list. The folder and its files are left untouched.';
  }

  @override
  String get projectNoAnalysis => 'Not analyzed';

  @override
  String get projectNoProfile => 'No profile';

  @override
  String projectLastOpened(String date) {
    return 'Last opened $date';
  }

  @override
  String get projectNeverOpened => 'Never opened';

  @override
  String projectLoadError(String message) {
    return 'Could not read the project list: $message';
  }

  @override
  String get projectLocal => 'Local';

  @override
  String openFailed(String message) {
    return 'Could not open VS Code: $message';
  }

  @override
  String get analysisTitle => 'Analysis';

  @override
  String get analysisRunning => 'Analyzing the folder…';

  @override
  String get analysisFailed => 'The analysis failed';

  @override
  String get analysisNoTypes =>
      'No project type was detected. Check the folder contents or add a user rule.';

  @override
  String get analysisPrimaryBadge => 'Primary';

  @override
  String analysisPriority(String value) {
    return 'Priority $value';
  }

  @override
  String get analysisCompetitorsTitle => 'Close competitors';

  @override
  String analysisCompetitorsBody(String names) {
    return '$names also matched with a similar priority but uses a different profile. You can switch on the next screen.';
  }

  @override
  String analysisStats(String count) {
    return '$count files scanned';
  }

  @override
  String get analysisTruncated =>
      'The scan stopped at the file limit. Opening only the module folder you work in is recommended.';

  @override
  String analysisSkippedDirs(String names) {
    return 'Folders not entered: $names';
  }

  @override
  String get analysisVariables => 'Resolved variables';

  @override
  String get analysisNext => 'View recommendation';

  @override
  String get recommendTitle => 'Edit recommendation';

  @override
  String get recommendPrimaryType => 'Primary type';

  @override
  String get recommendProfile => 'Profile name';

  @override
  String get recommendProfileHelp =>
      'The VS Code profile name. It is created if it does not exist.';

  @override
  String get recommendProfileSuggestions => 'Suggested names';

  @override
  String get recommendProfileEmpty => 'Enter a profile name';

  @override
  String get recommendProfileInvalid =>
      'The profile name contains a character that is not allowed';

  @override
  String get recommendExtensionsRequired => 'Recommended extensions';

  @override
  String get recommendExtensionsOptional => 'Optional extensions (other types)';

  @override
  String get recommendSettings => 'Settings patch';

  @override
  String recommendSettingsCount(String count) {
    return '$count entries';
  }

  @override
  String get recommendNotes => 'Notes';

  @override
  String get recommendNone => 'There is nothing to recommend';

  @override
  String get recommendNext => 'Compare settings';

  @override
  String get diffTitle => 'Compare settings';

  @override
  String get diffLoading => 'Comparing…';

  @override
  String get diffFailed => 'Could not compare';

  @override
  String get diffNewFile => 'settings.json will be created.';

  @override
  String get diffNoChange => 'settings.json will not change.';

  @override
  String get diffCommentsWarning =>
      'Comments in the existing settings.json will be lost. A .bak backup is made before applying.';

  @override
  String diffAdded(String count) {
    return 'Added ($count)';
  }

  @override
  String diffConflicts(String count) {
    return 'Conflicts — existing value kept ($count)';
  }

  @override
  String diffUnchanged(String count) {
    return 'Unchanged ($count)';
  }

  @override
  String get diffReplace => 'Replace with the patch value';

  @override
  String get diffExisting => 'Existing';

  @override
  String get diffPatch => 'Patch';

  @override
  String get diffMergedPreview => 'File after applying';

  @override
  String get diffApply => 'Apply';

  @override
  String get applyTitle => 'Apply';

  @override
  String get applyStepExtensions => 'Install extensions';

  @override
  String get applyStepSettings => 'Write settings';

  @override
  String get applyNoExtensions => 'There are no extensions to install.';

  @override
  String applyExtSkipped(String id) {
    return 'Already installed: $id';
  }

  @override
  String applyExtInstalling(String id) {
    return 'Installing: $id';
  }

  @override
  String applyExtFailed(String id, String code) {
    return 'Install failed: $id (exit code $code)';
  }

  @override
  String get applySettingsWritten => 'settings.json was updated.';

  @override
  String applySettingsBackup(String path) {
    return 'Backup: $path';
  }

  @override
  String get applySettingsUnchanged =>
      'Nothing changed, so the file was not written.';

  @override
  String get applyDone => 'Applied successfully';

  @override
  String applyFailedStep(String step, String message) {
    return 'Failed at “$step”: $message';
  }

  @override
  String applySaveFailed(String message) {
    return 'Could not save the project: $message';
  }

  @override
  String get applyBackToList => 'Back to list';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCodePath => 'VS Code executable (code) path';

  @override
  String get settingsCodePathHint => 'Leave empty to detect it automatically';

  @override
  String get settingsDetect => 'Detect';

  @override
  String get settingsBrowse => 'Browse';

  @override
  String get settingsTest => 'Check';

  @override
  String get settingsSave => 'Save';

  @override
  String settingsDetected(String path) {
    return 'Found: $path';
  }

  @override
  String get settingsNotFound =>
      'VS Code was not found. Set the path yourself.';

  @override
  String settingsTestOk(String version) {
    return 'VS Code $version';
  }

  @override
  String settingsTestFailed(String message) {
    return 'Could not run it: $message';
  }

  @override
  String get settingsSaved => 'Saved';
}
