import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_asset_utils/media_asset_utils.dart';
import 'package:media_asset_utils_example/permission_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? outputFile;
  File? file;
  int? outputFileSize;
  int? fileSize;

  @override
  void initState() {
    super.initState();
  }

  Future<void> initThumbnail(BuildContext context) async {
    final bool isGranted = await GGPermissionUtil.album();
    if (isGranted) {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.video,
          maxAssets: 1,
        ),
      );
      if ((assets ?? []).isNotEmpty) {
        file = await assets!.first.file;
        setState(() {
          fileSize = file!.lengthSync();
        });
        Directory? directory;
        // if (Platform.isIOS) {

        // } else {
        //   directory = (await getExternalStorageDirectories())!.first;
        // }
        directory = await getApplicationDocumentsDirectory();
        outputFile =
            File('${directory.path}/thumbnail_${Random().nextInt(100000)}.jpg');
        return;
      } else {
        throw Exception("No files selected");
      }
    }
    throw Exception("Permission denied");
  }

  Future<void> initCompress(BuildContext context, RequestType type) async {
    final bool isGranted = await GGPermissionUtil.album();
    if (isGranted) {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: type,
          maxAssets: 1,
        ),
      );
      if ((assets ?? []).isNotEmpty) {
        Directory? directory;

        directory = await getApplicationDocumentsDirectory();
        if (Platform.isIOS) {
          // directory = await getApplicationDocumentsDirectory();
          file = await assets!.first.originFile;
        } else {
          // directory = (await getExternalStorageDirectories())!.first;
          file = await assets!.first.file;
        }
        setState(() {
          fileSize = file!.lengthSync();
        });
        if (type == RequestType.video) {
          outputFile =
              File('${directory.path}/video_${Random().nextInt(100000)}.mp4');
        } else {
          Directory('${directory.path}/abdd/12233').createSync(recursive: true);
          outputFile = File('${directory.path}/abdd/12233/image_1.jpg');
        }
        return;
      } else {
        throw Exception("No files selected");
      }
    }
    throw Exception("Permission denied");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Builder(builder: (_) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: 200),
                child: Column(
                  children: [
                    Text(
                        '当前选择: $file, 文件大小: ${fileSize != null ? (fileSize! / 1024 / 1024).toStringAsFixed(2) : 0}'),
                    Text(
                        '处理后: $outputFile, 文件大小: ${outputFileSize != null ? (outputFileSize! / 1024 / 1024).toStringAsFixed(2) : 0}'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.video);
                  outputFile = await MediaAssetUtils.compressVideo(
                    file!,
                    saveToLibrary: true,
                    quality: VideoQuality.very_low,
                    thumbnailConfig: ThumbnailConfig(),
                    onVideoCompressProgress: (double progress) {
                      print(progress);
                    },
                  );
                  setState(() {
                    outputFileSize = outputFile!.lengthSync();
                  });
                },
                child: Text('Compress Video'),
              ),
              TextButton(
                onPressed: () async {
                  await initThumbnail(_);
                  outputFile = await MediaAssetUtils.getVideoThumbnail(
                    file!,
                    quality: 50,
                    saveToLibrary: true,
                    thumbnailFile: outputFile!,
                  );
                  setState(() {
                    outputFileSize = outputFile!.lengthSync();
                  });
                },
                child: Text('Get Video Thumbnail'),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.video);
                  final result = await MediaAssetUtils.getVideoInfo(file!);
                  print(result.toJson());
                },
                child: Text('Get Video Info'),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.image);
                  final result = await MediaAssetUtils.getImageInfo(file!);
                  print(result.toJson());
                },
                child: Text('Get Image Info'),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.image);
                  print(outputFile);
                  final result = await MediaAssetUtils.compressImage(
                    file!,
                    saveToLibrary: true,
                    outputFile: outputFile,
                  );
                  print(result);
                  setState(() {
                    outputFileSize = outputFile!.lengthSync();
                  });
                },
                child: Text('Compress Image'),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.image);
                  await MediaAssetUtils.saveToGallery(file!);
                },
                child: Text('Save To Media Store'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
