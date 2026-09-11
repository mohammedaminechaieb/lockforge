import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/theme_pack.dart';

class ThemeIoService {
  /// Writes the theme to a temp .lockforge.json file and opens the native
  /// share sheet — lets the user save it to Drive, send it to a friend, etc.
  Future<void> exportTheme(ThemePack theme) async {
    final dir = await getTemporaryDirectory();
    final safeName = theme.name.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/$safeName.lockforge.json');
    await file.writeAsString(jsonEncode(theme.toJson()));
    await Share.shareXFiles([XFile(file.path)], text: 'LockForge theme: ${theme.name}');
  }

  /// Opens the system file picker filtered to .json and parses whatever
  /// the user selects back into a ThemePack.
  Future<ThemePack?> importTheme() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    return ThemePack.fromJson(jsonDecode(content));
  }
}
