import 'dart:typed_data' as unit;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:mrz_scanner/mrz_scanner.dart';

import 'camera_view.dart';
import 'mrz_helper.dart';

class MRZScanner extends StatefulWidget {
  const MRZScanner({
    Key? controller,
    required this.onSuccess,
    this.initialDirection = CameraLensDirection.back,
    this.showOverlay = true,
  }) : super(key: controller);
  final Function(MRZResult mrzResult, List<String> lines) onSuccess;
  final CameraLensDirection initialDirection;
  final bool showOverlay;

  @override
  // ignore: library_private_types_in_public_api
  MRZScannerState createState() => MRZScannerState();
}

class MRZScannerState extends State<MRZScanner> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _canProcess = true;
  bool _isBusy = false;
  List result = [];

  void resetScanning() => _isBusy = false;

  @override
  void dispose() async {
    _canProcess = false;
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MRZCameraView(
      showOverlay: widget.showOverlay,
      initialDirection: widget.initialDirection,
      onImage: _processImage,
    );
  }

  void _parseScannedText(List<String> lines) {
    try {
      final data = MRZParser.parse(lines);
      _isBusy = true;

      widget.onSuccess(data, lines);
    } catch (e) {
      _isBusy = false;
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    final recognizedText = await _textRecognizer.processImage(inputImage);
    String fullText = recognizedText.text;
    String trimmedText = fullText.replaceAll(' ', '');
    List allText = trimmedText.split('\n');

    List<String> ableToScanText = [];
    for (var e in allText) {
      if (MRZHelper.testTextLine(e).isNotEmpty) {
        ableToScanText.add(MRZHelper.testTextLine(e));
      }
    }
    List<String>? result = MRZHelper.getFinalListToParse([...ableToScanText]);
    if (result != null) {
      debugPrint('$result');
      final format = inputImage.metadata?.format;

      if (format == InputImageFormat.nv21) {
        saveNV21Image(inputImage);
      }

      if (format == InputImageFormat.bgra8888) {
        saveBGRAImage(inputImage);
      }

      _parseScannedText([...result]);
    } else {
      _isBusy = false;
    }
  }

  Future<void> saveNV21Image(InputImage inputImage) async {
    if (inputImage.type != InputImageType.bytes) {
      return;
    }

    unit.Uint8List bytes = inputImage.bytes!;

    final size = inputImage.metadata?.size;
    // **步骤 1：转换 NV21 (YUV) 数据到 RGB**
    img.Image rgbImage = convertNV21ToImage(bytes, size?.width.toInt() ?? 0, size?.height.toInt() ?? 0);

    // 根据相机方向旋转图片
    final orientation = inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg;
    rgbImage = rotateImage(rgbImage, orientation);

    // **步骤 2：将 RGB 转换为 JPEG**
    unit.Uint8List jpegBytes = unit.Uint8List.fromList(img.encodeJpg(rgbImage));

    // **步骤 3：保存 JPEG 文件**
    final String fileName = "image_${DateTime.now().millisecondsSinceEpoch}.jpg";

    // **步骤 4：存入图库**
    final result = await ImageGallerySaverPlus.saveImage(jpegBytes, name: fileName);
    debugPrint("result: $result");
  }

  Future<void> saveBGRAImage(InputImage inputImage) async {
    if (inputImage.type != InputImageType.bytes) {
      return;
    }

    unit.Uint8List bytes = inputImage.bytes!;

    final size = inputImage.metadata?.size;
    // **步骤 1：转换 BGRA8888 到 RGB**
    img.Image rgbImage = convertBGRA8888ToImage(bytes, size?.width.toInt() ?? 0, size?.height.toInt() ?? 0);

    // 根据相机方向旋转图片
    final orientation = inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg;
    rgbImage = rotateImage(rgbImage, orientation);

    // **步骤 2：将 RGB 转换为 JPEG**
    unit.Uint8List jpegBytes = unit.Uint8List.fromList(img.encodeJpg(rgbImage));

    // **步骤 3：保存 JPEG 文件**
    final String fileName = "image_${DateTime.now().millisecondsSinceEpoch}.jpg";

    // **步骤 4：存入图库**
    final result = await ImageGallerySaverPlus.saveImage(jpegBytes, name: fileName);
    debugPrint(" $result");
  }

  /// 根据相机方向旋转图片
  img.Image rotateImage(img.Image image, InputImageRotation rotation) {
    // 先进行旋转
    img.Image rotatedImage;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        rotatedImage = img.copyRotate(image, angle: 90);
        break;
      case InputImageRotation.rotation180deg:
        rotatedImage = img.copyRotate(image, angle: 180);
        break;
      case InputImageRotation.rotation270deg:
        rotatedImage = img.copyRotate(image, angle: 270);
        break;
      default:
        rotatedImage = image;
    }

    // 计算正方形裁剪区域
    int size = rotatedImage.width < rotatedImage.height ? rotatedImage.width : rotatedImage.height;
    int x = (rotatedImage.width - size) ~/ 2;
    int y = (rotatedImage.height - size) ~/ 2;

    // 裁剪成正方形
    return img.copyCrop(rotatedImage, x: x, y: y, width: size, height: size);
  }

  /// **NV21 (YUV420) 转 RGB**
  img.Image convertNV21ToImage(unit.Uint8List bytes, int width, int height) {
    img.Image image = img.Image(width: width, height: height);

    final int frameSize = width * height;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int yIndex = y * width + x;
        int uvIndex = frameSize + (y >> 1) * width + (x & ~1);

        int Y = bytes[yIndex] & 0xFF;
        int V = bytes[uvIndex] & 0xFF;
        int U = bytes[uvIndex + 1] & 0xFF;

        // YUV 转 RGB 计算
        int R = (Y + 1.402 * (V - 128)).clamp(0, 255).toInt();
        int G = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).clamp(0, 255).toInt();
        int B = (Y + 1.772 * (U - 128)).clamp(0, 255).toInt();

        image.setPixel(x, y, img.ColorInt8.rgb(R, G, B));
      }
    }
    return image;
  }

  /// **BGRA8888 转 RGB**
  img.Image convertBGRA8888ToImage(unit.Uint8List bytes, int width, int height) {
    img.Image image = img.Image(width: width, height: height);

    int index = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int B = bytes[index++];
        int G = bytes[index++];
        int R = bytes[index++];

        image.setPixel(x, y, img.ColorInt8.rgb(R, G, B));
      }
    }
    return image;
  }
}
