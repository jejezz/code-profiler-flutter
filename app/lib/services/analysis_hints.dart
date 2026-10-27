import 'package:profile_engine/profile_engine.dart';

/// 주 유형과 priority 차이가 [threshold] 이하이면서 **다른 프로필**을 쓰는 후보.
///
/// 판정은 항상 최고 priority를 자동 선택하고, 이런 후보가 있으면 화면에 "근접 경쟁 후보"로
/// 알리기만 한다(선택을 강제하지 않는다). 같은 프로필을 쓰는 유형은 확장이 합쳐지므로
/// 경쟁이 아니다.
List<DetectedType> closeCompetitors(
  AnalysisResult analysis,
  Rules rules, {
  int threshold = 10,
}) {
  if (analysis.types.length < 2) return const [];
  final profileOf = {for (final t in rules.types) t.id: t.profile};
  final primary = analysis.types.first;
  final primaryProfile = profileOf[primary.typeId];
  return [
    for (final t in analysis.types.skip(1))
      if (primary.priority - t.priority <= threshold &&
          profileOf[t.typeId] != primaryProfile)
        t,
  ];
}

/// JSON Pointer(RFC 6901)를 사람이 읽을 키 경로로 바꾼다. `/a.b/c~1d` → `['a.b', 'c/d']`.
List<String> pointerSegments(String pointer) {
  if (pointer.isEmpty || pointer == '/') return const [];
  return [
    for (final s in pointer.substring(1).split('/'))
      s.replaceAll('~1', '/').replaceAll('~0', '~'),
  ];
}

/// 값을 한 줄 미리보기로. 길면 줄인다.
String previewValue(Object? value, {int max = 90}) {
  final text = switch (value) {
    String s => '"$s"',
    _ => '$value',
  }.replaceAll('\n', ' ');
  return text.length <= max ? text : '${text.substring(0, max - 1)}…';
}

/// VS Code CLI에 넘기기 곤란한 문자(셸 특수문자, 줄바꿈)가 프로필 이름에 있는지.
/// 엔진의 `VsCodeCli`가 Windows에서 같은 문자를 거부하므로, 화면에서 먼저 알린다.
bool hasUnsafeProfileChars(String name) =>
    RegExp(r'[&|<>^%"`\r\n]').hasMatch(name);
