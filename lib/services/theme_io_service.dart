import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/theme_pack.dart';

class ThemeIoService {
  /// Writes the theme to a .lockforge.json file and opens the share sheet.
  /// A photo background is embedded (base64) so the file is self-contained
  /// — a bare file path would be meaningless on someone else's phone.
  Future<void> exportTheme(ThemePack theme) async {
    final json = theme.toJson();
    final imagePath = theme.backgroundImagePath;
    if (theme.backgroundType == BackgroundType.image && imagePath != null && File(imagePath).existsSync()) {
      json['backgroundImageBase64'] = base64Encode(await File(imagePath).readAsBytes());
    }
    json.remove('backgroundImagePath');

    final dir = await getTemporaryDirectory();
    final safeName = theme.name.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/$safeName.lockforge.json');
    await file.writeAsString(jsonEncode(json));
    await Share.shareXFiles([XFile(file.path)], text: 'LockForge theme: ${theme.name}');
  }

  /// Opens the system file picker and parses the chosen file into a new
  /// ThemePack (with a fresh id, so importing never overwrites a theme).
  /// Throws [FormatException] if the file isn't a LockForge theme.
  Future<ThemePack?> importTheme() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return null;

    final content = await File(result.files.single.path!).readAsString();
    final Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(jsonDecode(content));
      if (json['widgets'] is! List) throw const FormatException();
    } catch (_) {
      throw const FormatException('That file isn\'t a LockForge theme.');
    }

    final embedded = json['backgroundImageBase64'];
    if (embedded is String) {
      json['backgroundImagePath'] = await saveBackgroundBytes(base64Decode(embedded), 'jpg');
    }
    return ThemePack.fromJson(json).copyWith(name: json['name'] ?? 'Imported theme');
  }

  /// Lets the user pick a photo and copies it into app storage (the picker's
  /// own cache copy can be cleaned up by the system at any time).
  Future<String?> pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return null;
    final ext = path.split('.').last.toLowerCase();
    return saveBackgroundBytes(await File(path).readAsBytes(), ext.length <= 4 ? ext : 'jpg');
  }

  static Future<String> saveBackgroundBytes(List<int> bytes, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/backgrounds');
    await folder.create(recursive: true);
    final file = File('${folder.path}/${const Uuid().v4()}.$ext');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
