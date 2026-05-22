import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../local_db/models/trip_model.dart';

class DataExportService {
  static Future<void> exportData(List<TripModel> trips) async {
    final data = {
      'app': 'rides_out',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'trips': trips.map((t) => t.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rides_out_backup.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<List<TripModel>?> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    if (data['app'] != 'rides_out') {
      throw FormatException('Not a valid Rides Out backup file');
    }

    final tripsList = data['trips'] as List<dynamic>;
    return tripsList
        .map((t) => TripModel.fromJson(t as Map<String, dynamic>))
        .toList();
  }
}
