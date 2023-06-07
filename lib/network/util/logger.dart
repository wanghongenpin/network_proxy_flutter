import 'package:logger/logger.dart';

final log = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      excludeBox: {Level.info: true, Level.debug: true},
    ));
