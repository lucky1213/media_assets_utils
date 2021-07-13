import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:media_assets_utils/media_assets_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(context,
          requestType: RequestType.video, maxAssets: 1);
      if ((assets ?? []).isNotEmpty) {
        file = await assets!.first.file;
        setState(() {
          fileSize = file!.lengthSync();
        });
        Directory? directory;
        if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getExternalStorageDirectory();
        }
        outputFile = File(
            '${directory!.path}/thumbnail_${Random().nextInt(100000)}.jpg');
        return;
      } else {
        throw Exception("No files selected");
      }
    }
    throw Exception("Permission denied");
  }

  Future<void> initCompress(BuildContext context, RequestType type) async {
    final PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(context,
          requestType: type, maxAssets: 1);
      if ((assets ?? []).isNotEmpty) {
        file = await assets!.first.file;
        setState(() {
          fileSize = file!.lengthSync();
        });
        Directory? directory;
        if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getExternalStorageDirectory();
        }
        if (type == RequestType.video) {
          outputFile =
              File('${directory!.path}/video_${Random().nextInt(100000)}.mp4');
        } else {
          outputFile =
              File('${directory!.path}/image_${Random().nextInt(100000)}.jpg');
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
                height: 200,
                child: Column(
                  children: [
                    Text('当前选择: $file, 文件大小: $fileSize'),
                    Text('处理后: $outputFile, 文件大小: $outputFileSize'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.video);
                  outputFile = await MediaAssetsUtils.compressVideo(
                    file!,
                    outputFile: outputFile,
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
                  outputFile = await MediaAssetsUtils.getVideoThumbnail(
                    file!,
                    // thumbnailFile: outputFile!,
                  );
                  setState(() {
                    outputFileSize = outputFile!.lengthSync();
                  });
                },
                child: Text('Get Video Thumbnail'),
              ),
              TextButton(
                onPressed: () async {},
                child: Text('Get Video Metadata'),
              ),
              TextButton(
                onPressed: () async {
                  await initCompress(_, RequestType.image);
                  outputFile = await MediaAssetsUtils.compressImage(
                    file!,
                    // outputFile: outputFile,
                  );
                  setState(() {
                    outputFileSize = outputFile!.lengthSync();
                  });
                },
                child: Text('Compress Image'),
              ),
              TextButton(
                onPressed: () {
                  // MediaAssetsUtils.compressVideo(srcPath: srcPath, destPath: destPath)
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
