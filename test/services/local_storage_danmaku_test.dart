import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('danmakuEnabled defaults to true', () {
    expect(LocalStore.danmakuEnabled, true);
  });

  test('setDanmakuEnabled persists false then true', () async {
    await LocalStore.setDanmakuEnabled(false);
    expect(LocalStore.danmakuEnabled, false);
    await LocalStore.setDanmakuEnabled(true);
    expect(LocalStore.danmakuEnabled, true);
  });
}
