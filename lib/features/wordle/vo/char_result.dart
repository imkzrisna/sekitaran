abstract class CharResult {
  final String char;
  const CharResult(this.char);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharResult &&
          runtimeType == other.runtimeType &&
          char == other.char;

  @override
  int get hashCode => char.hashCode;
}
