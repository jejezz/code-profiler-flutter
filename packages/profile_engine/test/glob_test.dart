import 'package:profile_engine/src/analyzer/glob.dart';
import 'package:test/test.dart';

void main() {
  bool m(String glob, String path) => Glob(glob).matches(path);

  test('plain name matches only at the root', () {
    expect(m('sdkconfig', 'sdkconfig'), isTrue);
    expect(m('sdkconfig', 'main/sdkconfig'), isFalse);
    expect(m('sdkconfig', 'sdkconfig.old'), isFalse);
  });

  test('**/ matches zero or more directories', () {
    expect(m('**/idf_component.yml', 'idf_component.yml'), isTrue);
    expect(m('**/idf_component.yml', 'main/idf_component.yml'), isTrue);
    expect(m('**/idf_component.yml', 'a/b/idf_component.yml'), isTrue);
    expect(m('**/idf_component.yml', 'xidf_component.yml'), isFalse);
  });

  test('* does not cross directories, ** does', () {
    expect(m('*.c', 'main.c'), isTrue);
    expect(m('*.c', 'src/main.c'), isFalse);
    expect(m('src/**', 'src/a/b.c'), isTrue);
  });

  test('? matches exactly one non-separator character', () {
    expect(m('a?c', 'abc'), isTrue);
    expect(m('a?c', 'a/c'), isFalse);
    expect(m('a?c', 'ac'), isFalse);
  });

  test('regex metacharacters are literal', () {
    expect(m('a.b', 'a.b'), isTrue);
    expect(m('a.b', 'axb'), isFalse);
    expect(m('[x]+', '[x]+'), isTrue);
  });
}
