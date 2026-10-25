class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

String joinTextRows(List<OcrLine> lines) {
  final List<OcrLine> sorted = lines
      .where(
        (OcrLine line) =>
            line.text.trim().isNotEmpty &&
            line.height > 0 &&
            line.height <= line.width * 4,
      )
      .toList()
    ..sort((OcrLine a, OcrLine b) => a.centerY.compareTo(b.centerY));

  final List<List<OcrLine>> rows = <List<OcrLine>>[];
  for (final OcrLine line in sorted) {
    if (rows.isNotEmpty && _sameRow(rows.last, line)) {
      rows.last.add(line);
    } else {
      rows.add(<OcrLine>[line]);
    }
  }

  return rows.map((List<OcrLine> row) {
    row.sort((OcrLine a, OcrLine b) => a.left.compareTo(b.left));
    return row.map((OcrLine line) => line.text.trim()).join('   ');
  }).join('\n');
}

bool _sameRow(List<OcrLine> row, OcrLine line) {
  double centerSum = 0;
  double minHeight = line.height;
  for (final OcrLine member in row) {
    centerSum += member.centerY;
    if (member.height < minHeight) minHeight = member.height;
  }
  final double rowCenter = centerSum / row.length;
  return (line.centerY - rowCenter).abs() < minHeight * 0.6;
}
