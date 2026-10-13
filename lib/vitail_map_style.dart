import 'package:flutter/material.dart';

/// Null restores Google's default light map when the theme changes back.
String? vitailMapStyle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _darkMapStyle : null;

const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242321"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#d6d0c6"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242321"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#55514b"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#302e2b"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#293523"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#aec568"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#49443e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#242321"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#766252"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#35322e"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#1d2e39"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#8ebbd7"}]}
]
''';
