part of 'media_asset_utils.dart';

class MediaInfo {
  final String? path;
  final String? title;
  final String? author;
  final int? width;
  final int? height;
  final int? orientation;
  final int? filesize;

  /// microsecond
  final double? duration;
  final File? file;

  MediaInfo({
    required this.path,
    this.title,
    this.author,
    this.width,
    this.height,
    this.orientation,
    this.filesize,
    this.duration,
  }) : file = path == null ? null : File(path);

  factory MediaInfo.fromJson(String str) =>
      MediaInfo.fromMap(json.decode(str) as Map<String, dynamic>);

  factory MediaInfo.fromMap(Map<String, dynamic> json) => MediaInfo(
        path: json['path'],
        title: json['title'],
        author: json['author'],
        width: json['width'],
        height: json['height'],
        orientation: json['orientation'],
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
        'orientation': orientation,
        'filesize': filesize,
        'duration': duration,
      };
}
