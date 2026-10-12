String? microchipNumberError(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return 'Enter your dog\'s 15-digit microchip number.';
  if (!RegExp(r'^\d{15}$').hasMatch(value)) {
    return 'Please write 15 digits';
  }
  if (value.startsWith('999')) {
    return 'Numbers starting with 999 are test codes, not registered chips.';
  }
  return null;
}
