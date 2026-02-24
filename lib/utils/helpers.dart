List<String> extractVariables(String text) {
  final RegExp regex = RegExp(r'\{\{(\d+)\}\}');
  final matches = regex.allMatches(text);
  return matches.map((m) => m.group(0)!).toSet().toList();
}
