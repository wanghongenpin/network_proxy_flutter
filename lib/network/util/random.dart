import 'dart:math';

class RandomUtil {
  static const _characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String randomString(int length) {
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => _characters.codeUnitAt(random.nextInt(_characters.length)),
    ));
  }
}
