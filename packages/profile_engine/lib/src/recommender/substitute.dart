final _variablePattern = RegExp(r'\$\{([^}]+)\}');

/// VS Code가 직접 해석하는 변수. 치환하지 않고 그대로 둔다.
const _reservedNames = {
  'workspaceFolder',
  'workspaceFolderBasename',
  'userHome',
};

bool _isReserved(String name) =>
    _reservedNames.contains(name) || name.startsWith('env:');

/// [value] 안의 `${이름}`을 [variables]로 치환한다.
///
/// Map/List는 재귀로 들어가고 문자열만 치환한다. 예약 변수는 그대로 두고, 해석할 수 없는
/// 변수의 이름은 [unresolved]에 모은다(그 자리에는 원문이 남는다).
Object? substituteVariables(
  Object? value,
  Map<String, String> variables,
  Set<String> unresolved,
) {
  return switch (value) {
    String s => s.replaceAllMapped(_variablePattern, (m) {
      final name = m[1]!;
      if (_isReserved(name)) return m[0]!;
      final resolved = variables[name];
      if (resolved == null) {
        unresolved.add(name);
        return m[0]!;
      }
      return resolved;
    }),
    Map<String, Object?> m => {
      for (final e in m.entries)
        e.key: substituteVariables(e.value, variables, unresolved),
    },
    List<Object?> l => [
      for (final e in l) substituteVariables(e, variables, unresolved),
    ],
    _ => value,
  };
}
