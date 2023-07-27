import 'package:flutter/material.dart';

enum ColorTheme {
  light(
      background: Color(0xffffffff),
      propertyKey: Color(0xff871094),
      colon: Colors.black,
      string: Color(0xff067d17),
      number: Color(0xff1750eb),
      keyword: Color(0xff0033b3)),
  dark(
      background: Color(0xff2b2b2b),
      propertyKey: Color(0xff9876aa),
      colon: Color(0xffcc7832),
      string: Color(0xff6a8759),
      number: Color(0xff6897bb),
      keyword: Color(0xffcc7832));

  final Color background;
  final Color propertyKey;
  final Color colon;
  final Color string;
  final Color number;
  final Color keyword;

  const ColorTheme(
      {required this.background,
      required this.propertyKey,
      required this.colon,
      required this.string,
      required this.number,
      required this.keyword});

  static ColorTheme of(Brightness brightness) {
    return brightness == Brightness.dark ? ColorTheme.dark : ColorTheme.light;
  }
}
