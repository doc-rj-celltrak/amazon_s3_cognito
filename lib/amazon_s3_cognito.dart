import 'dart:async';

import 'package:flutter/services.dart';

class AmazonS3Cognito {
  static const MethodChannel _channel =
      const MethodChannel('amazon_s3_cognito');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  // uploads the file in the [filePath]
  static Future<String> upload(
    String filepath,
    String imageName,
    String authToken,
  ) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'filePath': filepath,
      'imageName': imageName,
      'authToken': authToken,
    };
    final String imagePath = await _channel.invokeMethod('uploadImage', params);
    return imagePath;
  }

  // downloads the file to the [filePath]
  static Future<String> download(
    String filepath,
    String imageName,
  ) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'filePath': filepath,
      'imageName': imageName,
    };
    final String imagePath =
        await _channel.invokeMethod('downloadImage', params);
    return imagePath;
  }

  static Future<String> delete(String imageName) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'imageName': imageName,
    };
    final String imagePath = await _channel.invokeMethod('deleteImage', params);
    return imagePath;
  }
}
