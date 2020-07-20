import 'dart:async';

import 'package:flutter/services.dart';

class AmazonS3Cognito {
  static const MethodChannel _channel =
      const MethodChannel('amazon_s3_cognito');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> uploadImage(
      String filepath, String bucket, String identity) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'filePath': filepath,
      'bucket': bucket,
      'identity': identity,
    };
    final String imagePath =
        await _channel.invokeMethod('uploadImageToAmazon', params);
    return imagePath;
  }

  // uploads the file in the [filePath]
  static Future<String> upload(
    String filepath,
    String bucket,
    String identity,
    String imageName,
    String region,
    String subRegion,
    String userPoolId,
    String appClientId,
    String authToken,
  ) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'filePath': filepath,
      'bucket': bucket,
      'identity': identity,
      'imageName': imageName,
      'region': region,
      'subRegion': subRegion,
      'userPoolId': userPoolId,
      'appClientId': appClientId,
      'authToken': authToken,
    };
    final String imagePath = await _channel.invokeMethod('uploadImage', params);
    return imagePath;
  }

  // downloads the file to the [filePath]
  static Future<String> download(
    String filepath,
    String bucket,
    String identity,
    String imageName,
    String region,
    String subRegion,
  ) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'filePath': filepath,
      'bucket': bucket,
      'identity': identity,
      'imageName': imageName,
      'region': region,
      'subRegion': subRegion
    };
    final String imagePath =
        await _channel.invokeMethod('downloadImage', params);
    return imagePath;
  }

  static Future<String> delete(String bucket, String identity, String imageName,
      String region, String subRegion) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'bucket': bucket,
      'identity': identity,
      'imageName': imageName,
      'region': region,
      'subRegion': subRegion
    };
    final String imagePath = await _channel.invokeMethod('deleteImage', params);
    return imagePath;
  }
}
