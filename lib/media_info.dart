part of 'media_asset_utils.dart';

abstract class MediaInfo {
  final String path;
  final int? width;
  final int? height;
  final int? filesize;

  final File? file;

  MediaInfo({
    required this.path,
    this.width,
    this.height,
    this.filesize,
  }) : file = File(path);

  String toJson() => json.encode(toMap());

  Map<String, dynamic> toMap();
}

class VideoInfo extends MediaInfo {
  final String? title;
  final String? author;

  /// microsecond
  final double? duration;
  final int? rotation;

  VideoInfo({
    required String path,
    this.title,
    this.author,
    int? width,
    int? height,
    int? orientation,
    int? filesize,
    this.duration,
    this.rotation,
  }) : super(
          path: path,
          width: width,
          height: height,
          filesize: filesize,
        );

  factory VideoInfo.fromJson(String str) =>
      VideoInfo.fromMap(json.decode(str) as Map<String, dynamic>);

  factory VideoInfo.fromMap(Map<String, dynamic> json) => VideoInfo(
        path: json['path'],
        title: json['title'],
        author: json['author'],
        width: json['width'],
        height: json['height'],
        rotation: json['rotation'],
        filesize: json['filesize'],
        duration: double.tryParse('${json['duration']}'),
      );

  String toJson() => json.encode(toMap());

  Map<String, dynamic> toMap() => <String, dynamic>{
        'path': path,
        'title': title,
        'author': author,
        'width': width,
        'height': height,
        'rotation': rotation,
        'filesize': filesize,
        'duration': duration,
      };
}

class ImageInfo extends MediaInfo {
  final int? orientation;
  ImageInfo({
    required String path,
    int? width,
    int? height,
    int? filesize,
    this.orientation,
  }) : super(
          path: path,
          width: width,
          height: height,
          filesize: filesize,
        );

  factory ImageInfo.fromJson(String str) =>
      ImageInfo.fromMap(json.decode(str) as Map<String, dynamic>);

  factory ImageInfo.fromMap(Map<String, dynamic> json) => ImageInfo(
        path: json['path'],
        width: json['width'],
        height: json['height'],
        orientation: json['orientation'],
        filesize: json['filesize'],
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'path': path,
        'width': width,
        'height': height,
        'filesize': filesize,
        'orientation': orientation,
      };
}
