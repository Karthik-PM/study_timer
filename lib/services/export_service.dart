import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/study_session.dart';

class ExportService {
  static Future<void> exportToExcel(List<StudySession> sessions) async {
    final excel = Excel.createExcel();
    final sheet = excel['Study Sessions'];
    excel.delete('Sheet1');

    // Header row
    final headers = ['Date', 'Subject', 'Emoji', 'Start Time', 'End Time', 'Duration (min)', 'Notes'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4A90D9'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final rowIdx = i + 1;
      final values = [
        dateFormat.format(s.startTime),
        s.tagName,
        s.tagEmoji,
        timeFormat.format(s.startTime),
        timeFormat.format(s.endTime),
        (s.durationSeconds / 60).toStringAsFixed(1),
        s.notes,
      ];
      for (var j = 0; j < values.length; j++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIdx))
            .value = TextCellValue(values[j]);
      }
    }

    // Column widths
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 8);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 30);

    // Summary sheet
    final summary = excel['Summary'];
    final tagTotals = <String, int>{};
    for (final s in sessions) {
      tagTotals[s.tagName] = (tagTotals[s.tagName] ?? 0) + s.durationSeconds;
    }

    summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Subject');
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('Total (min)');
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
        TextCellValue('Total (hours)');

    var row = 1;
    for (final entry in tagTotals.entries) {
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(entry.key);
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue((entry.value / 60).toStringAsFixed(1));
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue((entry.value / 3600).toStringAsFixed(2));
      row++;
    }

    final bytes = excel.encode()!;
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'study_sessions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Study Timer Export',
      text: 'Study session data exported from Study Timer.',
    );
  }
}
