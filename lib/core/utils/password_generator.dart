import 'dart:math';

class PasswordGenerator {
  static String generate({int length = 14}) {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const special = '!@#\$%^&*-_=+';
    const all = uppercase + lowercase + numbers + special;

    final random = Random.secure();
    final password = <String>[
      uppercase[random.nextInt(uppercase.length)],
      lowercase[random.nextInt(lowercase.length)],
      numbers[random.nextInt(numbers.length)],
      special[random.nextInt(special.length)],
    ];

    for (int i = password.length; i < length; i++) {
      password.add(all[random.nextInt(all.length)]);
    }

    password.shuffle(random);
    return password.join();
  }
}
