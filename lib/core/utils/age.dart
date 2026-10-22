/// "under a minute", "40 min", or "2 h 5 min", for "retrieved … ago" labels.
String formatAge(Duration age) {
  final minutes = age.inMinutes;
  if (minutes < 1) return 'under a minute';
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${age.inHours} h' : '${age.inHours} h $rest min';
}
