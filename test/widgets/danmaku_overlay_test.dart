import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/widgets/danmaku_overlay.dart';

void main() {
  group('DanmakuItem', () {
    test('stores user, text, self', () {
      const item = DanmakuItem(user: 'Alice', text: 'gg', self: true);
      expect(item.user, 'Alice');
      expect(item.text, 'gg');
      expect(item.self, true);
    });
  });
}
