/// 프로젝트 유형을 분석해 VS Code 프로필·설정을 추천하는 엔진. Flutter에 의존하지 않는다.
library;

export 'src/analyzer/analyzer.dart' show analyze, analyzeSync;
export 'src/model/analysis.dart';
export 'src/model/project.dart';
export 'src/model/project_location.dart';
export 'src/model/recommendation.dart';
export 'src/recommender/recommender.dart' show recommend;
export 'src/recommender/substitute.dart' show substituteVariables;
export 'src/result.dart';
export 'src/rules/rules_loader.dart' show loadDefaultRules, loadRules;
export 'src/rules/rules_model.dart';
export 'src/rules/rules_parser.dart' show parseRules, validateRules;
export 'src/settings/jsonc.dart' show JsoncDocument, parseJsonc;
export 'src/settings/merge.dart'
    show
        ChangeKind,
        MergeResult,
        SettingChange,
        SettingsDiff,
        computeSettingsDiff,
        deepEquals,
        mergeSettings;
export 'src/settings/settings_file.dart'
    show SettingsWriteResult, applySettingsFile, diffSettingsFile;
