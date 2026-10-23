import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads receipt photos directly to Cloudinary using an unsigned upload
/// preset, so no backend media storage code is needed.
///
/// Fill in [cloudName] and [uploadPreset] with values from your Cloudinary
/// dashboard (Settings > Upload > Upload presets, mode: Unsigned).
class CloudinaryService {
  static const String cloudName = 'YOUR_CLOUDINARY_CLOUD_NAME';
  static const String uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';

  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  bool get isConfigured =>
      cloudName != 'YOUR_CLOUDINARY_CLOUD_NAME' &&
      uploadPreset != 'YOUR_UNSIGNED_UPLOAD_PRESET';

  Future<XFile?> pickReceiptImage({bool fromCamera = false}) async {
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
  }

  /// Uploads [file] and returns the Cloudinary `secure_url`.
  Future<String> uploadReceipt(XFile file) async {
    if (!isConfigured) {
      throw StateError(
        'Cloudinary is not configured. Set cloudName/uploadPreset in '
        'CloudinaryService.',
      );
    }

    final formData = FormData.fromMap({
      'upload_preset': uploadPreset,
      // fromFile uses dart:io and breaks on web; bytes work everywhere.
      'file': MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: file.name,
      ),
    });

    final response = await _dio.post(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: formData,
    );

    return response.data['secure_url'] as String;
  }
}
