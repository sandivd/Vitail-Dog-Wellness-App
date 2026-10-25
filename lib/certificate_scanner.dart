import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

Future<String> extractCertificateText(String path, {String? fileName}) async {
  final bool isPdf =
      (fileName ?? path).toLowerCase().endsWith('.pdf');
  final TextRecognizer recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final List<File> tempFiles = <File>[];
  try {
    final List<String> imagePaths =
        isPdf ? await _renderPdfPages(path, tempFiles) : <String>[path];
    final StringBuffer text = StringBuffer();
    for (final String imagePath in imagePaths) {
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      text.writeln(result.text);
    }
    return text.toString();
  } finally {
    await recognizer.close();
    for (final File temp in tempFiles) {
      if (await temp.exists()) await temp.delete();
    }
  }
}

Future<List<String>> _renderPdfPages(String path, List<File> tempFiles) async {
  final PdfDocument document = await PdfDocument.openFile(path);
  try {
    final Directory dir = await getTemporaryDirectory();
    final int pages = document.pagesCount < 2 ? document.pagesCount : 2;
    final List<String> paths = <String>[];
    for (int number = 1; number <= pages; number++) {
      final PdfPage page = await document.getPage(number);
      try {
        final PdfPageImage? image = await page.render(
          width: page.width * 3,
          height: page.height * 3,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (image == null) continue;
        final File out = File(
          '${dir.path}/vitail_cert_${DateTime.now().microsecondsSinceEpoch}_$number.png',
        );
        await out.writeAsBytes(image.bytes, flush: true);
        tempFiles.add(out);
        paths.add(out.path);
      } finally {
        await page.close();
      }
    }
    return paths;
  } finally {
    await document.close();
  }
}