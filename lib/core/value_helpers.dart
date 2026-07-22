typedef JsonMap = Map<String, dynamic>;

String textOf(Object? value, [String fallback = '']) {
  final valueText = value?.toString().trim() ?? '';
  return valueText.isEmpty ? fallback : valueText;
}

double numberOf(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int intOf(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool yesOf(Object? value) => const {
  'yes',
  'true',
  '1',
  'active',
  'activo',
  'si',
  'sí',
  'oui',
  'y',
}.contains(textOf(value).toLowerCase());

List<JsonMap> mapsOf(Object? value) => value is List
    ? value.whereType<Map>().map((row) {
        return row.map((key, value) => MapEntry(key.toString(), value));
      }).toList()
    : <JsonMap>[];

JsonMap mapOf(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

String money(Object? value) => '\$${numberOf(value).toStringAsFixed(2)} CAD';

String normalizeTime12(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final twelve = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (twelve != null) {
    final hour = int.parse(twelve.group(1)!);
    final minute = int.parse(twelve.group(2)!);
    final suffix = twelve.group(3)!.toUpperCase();
    if (hour < 1 || hour > 12 || minute > 59) return value;
    return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
  }
  final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  if (twentyFour == null) return value;
  var hour = int.parse(twentyFour.group(1)!);
  final minute = int.parse(twentyFour.group(2)!);
  if (hour > 23 || minute > 59) return value;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour %= 12;
  if (hour == 0) hour = 12;
  return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
}

String statusEs(Object? raw) => switch (textOf(raw)) {
  'Pending' => 'Pendiente',
  'Confirmed' => 'Confirmada',
  'Client arrived' => 'Clienta llegó',
  'In service' => 'En servicio',
  'Completed' => 'Completada',
  'Cancelled' => 'Cancelada',
  final other => other.isEmpty ? 'Sin estado' : other,
};
