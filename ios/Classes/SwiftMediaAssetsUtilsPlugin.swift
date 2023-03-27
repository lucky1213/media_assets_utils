import AVFoundation
import Flutter
import UIKit
import Photos

enum FileError: Error {
    case write
    case load
}

public enum DirectoryType: String {
    case movies = ".video"
    case pictures = ".image"
}

extension VideoQuality {
    var value: CGFloat {
        switch self {
        case .very_low:
            return 640
        case .low:
            return 640
        case .medium:
            return 960
        case .high:
            return 1280
        case .very_high:
            return 1920
        }
    }
}
public class SwiftMediaAssetsUtilsPlugin: NSObject, FlutterPlugin {
    
    
    private var videoExtension: [String] = ["mp4", "mov", "m4v", "3gp", "avi"]
    private var imageExtension: [String] = ["jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "heic", "heif"]
    
    private var channel: FlutterMethodChannel
    private var compressor: LightCompressor
    private var compression: Compression? = nil
    fileprivate var library: PHPhotoLibrary
    
    init(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "media_asset_utils", binaryMessenger: registrar.messenger())
        compressor = LightCompressor()
        library = PHPhotoLibrary.shared()
        super.init()
        channel.setMethodCallHandler(handle)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        _ = SwiftMediaAssetsUtilsPlugin(with: registrar)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        var dict: NSDictionary? = nil
        if (call.arguments != nil) {
            dict = (call.arguments as! NSDictionary)
        }
        switch call.method {
        case "compressVideo":
            let path: String = dict!.value(forKey: "path") as! String
            let outputPath: String = dict?.value(forKey: "outputPath") as? String ?? generatePath(type: DirectoryType.movies)
            let quality = VideoQuality.withLabel((dict?.value(forKey: "quality") as? String)?.lowercased() ?? "medium") ?? VideoQuality.medium
            
            let saveToLibrary: Bool = dict!.value(forKey: "saveToLibrary") as? Bool ?? false
            let storeThumbnail: Bool = dict!.value(forKey: "storeThumbnail") as? Bool ?? true
            let thumbnailPath: String? = dict!.value(forKey: "thumbnailPath") as? String
            let thumbnailQuality: CGFloat = CGFloat(dict!.value(forKey: "thumbnailQuality") as! Int ) / 100
            
            compressVideo(path, outputPath: outputPath, quality: quality) { compressionResult in
                switch compressionResult {
                case .onSuccess(let url):
                    if (storeThumbnail) {
                        let _ = self.storeThumbnailToFile(url: url, thumbnailPath: thumbnailPath, quality: thumbnailQuality, saveToLibrary: false)
                    }
                    result(url.path)
                    if (saveToLibrary) {
                        self.library.save(videoAtURL: url)
                    }
                    
                case .onStart: break
                    
                case .onFailure(let error):
                    result(FlutterError(code: "VideoCompress", message: error.errorDescription, details: nil))
                    
                case .onCancelled:
                    result(FlutterError(code: "VideoCompress", message: "The transcoding operation was canceled.", details: nil))
                }
            }
        case "compressImage":
            let path: String = dict!.value(forKey: "path") as! String
            let outputPath: String = dict?.value(forKey: "outputPath") as? String ?? generatePath(type: DirectoryType.pictures)
            let saveToLibrary: Bool = dict!.value(forKey: "saveToLibrary") as? Bool ?? false
            let originalData: Data
            do {
                originalData = try Data(contentsOf: URL(fileURLWithPath: path))
            } catch {
                result(FlutterError(code: "ImageCompress", message: "Cannot load image data.", details: nil))
                return
            }
            guard let originalImage = UIImage(data: originalData) else {
                result(FlutterError(code: "ImageCompress", message: "Load image Failed.", details: nil))
                return
            }
            guard let data = originalImage.compressedData() else {
                result(FlutterError(code: "ImageCompress", message: "Compress image failed.", details: nil))
                return
            }
            
            do {
                let url = URL(fileURLWithPath: outputPath)
                createDirectory(url.deletingLastPathComponent())
                try data.write(to: url)
                result(url.path)
                if (saveToLibrary) {
                    library.save(imageAtURL: url)
                }
            } catch {
                result(FlutterError(code: "ImageCompress", message: "Store compress image failed.", details: nil))
            }
        case "getVideoThumbnail":
            let path: String = dict!.value(forKey: "path") as! String
            let thumbnailPath: String? = dict?.value(forKey: "thumbnailPath") as? String
            let quality: CGFloat = CGFloat(dict!.value(forKey: "quality") as! Int ) / 100
            let saveToLibrary: Bool = dict!.value(forKey: "saveToLibrary") as? Bool ?? false
            
            guard let thumbnail = storeThumbnailToFile(url: URL(fileURLWithPath: path), thumbnailPath: thumbnailPath, quality: quality, saveToLibrary: saveToLibrary) else {
                result(FlutterError(code: "VideoThumbnail", message: "Get video thumbnil failed.", details: nil))
                return
            }
            result(thumbnail)
        case "getVideoInfo":
            let path: String = dict!.value(forKey: "path") as! String
            let source = URL(fileURLWithPath: path)
            let asset = AVURLAsset(url: source)
            
            DispatchQueue(label: "getImageInfo", attributes: .concurrent).async {
                guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "ExtractMetadata", message: "Cannot find video track.", details: nil))
                    }
                    return
                }
                let title = self.getMetaDataByTag(asset,key: "title")
                let author = self.getMetaDataByTag(asset,key: "author")
                let txf = videoTrack.preferredTransform
                let rotation = self.getVideoRotation(txf)
                let size = videoTrack.naturalSize.applying(txf)
                
                let dictionary = [
                    "path": path.replacingOccurrences(of: "file://", with: ""),
                    "title": title,
                    "author": author,
                    "width": abs(size.width),
                    "height": abs(size.height),
                    "duration": Int((CGFloat(asset.duration.value) / CGFloat(asset.duration.timescale)) * 1000),
                    "filesize": videoTrack.totalSampleDataLength,
                    "rotation": rotation,
                ] as [String : Any?]
                let data = try! JSONSerialization.data(withJSONObject: dictionary as NSDictionary, options: [])
                let jsonString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
                DispatchQueue.main.async {
                    result(jsonString! as String)
                }
            }
        case "getImageInfo":
            let path: String = dict!.value(forKey: "path") as! String
            let source = URL(fileURLWithPath: path)
            DispatchQueue(label: "getImageInfo", attributes: .concurrent).async {
                let imageSourceRef = CGImageSourceCreateWithURL(source as CFURL, nil)
                var width: CGFloat?
                var height: CGFloat?
                var orientation: NSInteger?
                let filesize = try? source.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).allValues.first?.value as? Int
                if let imageSRef = imageSourceRef {
                    let imageInfo = CGImageSourceCopyPropertiesAtIndex(imageSRef, 0, nil)
                    if let imageP = imageInfo {
                        let imageDict = imageP as Dictionary
                        width = imageDict[kCGImagePropertyPixelWidth] as? CGFloat
                        height = imageDict[kCGImagePropertyPixelHeight] as? CGFloat
                        orientation = imageDict[kCGImagePropertyOrientation] as? NSInteger
                        if (orientation == 5 || orientation == 6 || orientation == 7 || orientation == 8) {
                            let temp = width
                            width = height
                            height = temp
                        }
                        //                    if (orientation == 1 || orientation == 2) {
                        //                        degress = 0
                        //                    } else if (orientation == 3 || orientation == 4) {
                        //                        degress = 180
                        //                    } else if (orientation == 6 || orientation == 5) {
                        //                        degress = 90
                        //                    } else if (orientation == 8 || orientation == 7) {
                        //                        degress = 270
                        //                    }
                        //                    ismirror = orientation == 2 || orientation == 4 || orientation == 5 || orientation == 7
                    }
                }
                let dictionary = [
                    "path": path.replacingOccurrences(of: "file://", with: ""),
                    "width": width,
                    "height": height,
                    "filesize": filesize,
                    "orientation": orientation,
                ] as [String : Any?]
                let data = try! JSONSerialization.data(withJSONObject: dictionary as NSDictionary, options: [])
                let jsonString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
                DispatchQueue.main.async {
                    result(jsonString! as String)
                }
            }
        case "saveFileToGallery":
          let path: String = dict!.value(forKey: "path") as! String
          saveFileToGallery(path)
          result(true)
        case "saveImageToGallery":
            guard let imageData = (dict!["data"] as? FlutterStandardTypedData)?.data,
                        let image = UIImage(data: imageData)
                        else { return }
            guard let path = image.storeImageToFile(generatePath(type: DirectoryType.pictures)) else {
                result(false)
                return
            }
          saveFileToGallery(path)
          result(true)
        default:
            result(FlutterError(code: "NoImplemented", message: "Handles a call to an unimplemented method.", details: nil))
        }
    }

    private func saveFileToGallery(_ path: String) ->Void {
      let url = URL(fileURLWithPath: path)
      let pathExtension = url.pathExtension.lowercased()
      
      if (imageExtension.contains(pathExtension)) {
          library.save(imageAtURL: url)
      } else if (videoExtension.contains(pathExtension)) {
          library.save(videoAtURL: url)
      }
    }
    
    private func getVideoRotation(_ txf: CGAffineTransform) -> Int {
        var rotation = 0
        if (txf.a == 0 && txf.b == 1.0 && txf.c == -1.0 && txf.d == 0) {
            // Portrait
            rotation = 90;
        } else if (txf.a == 0 && txf.b == -1.0 && txf.c == 1.0 && txf.d == 0){
            // PortraitUpsideDown
            rotation = 270;
        } else if (txf.a == 1.0 && txf.b == 0 && txf.c == 0 && txf.d == 1.0){
            // LandscapeRight
            rotation = 0;
        } else if (txf.a == -1.0 && txf.b == 0 && txf.c == 0 && txf.d == -1.0){
            // LandscapeLeft
            rotation = 180;
        }
        return rotation
    }
    
    private func getMetaDataByTag(_ asset:AVAsset, key:String)->String {
        for item in asset.commonMetadata {
            if item.commonKey?.rawValue == key {
                return item.stringValue ?? "";
            }
        }
        return ""
    }
    
    private func createDirectory(_ url: URL) -> Void {
        let manager = FileManager.default
        if (!manager.fileExists(atPath: url.path)) {
            try! manager.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func checkAVTracks(asset: AVAsset, completion: ((AVKeyValueStatus) -> Void)? = nil) {
        let status:AVKeyValueStatus = asset.statusOfValue(forKey: #keyPath(AVAsset.tracks), error: nil)
        print(status.rawValue)
        if (status == .failed) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.checkAVTracks(asset: asset)
            }
        }
        if (status == .loaded) {
            completion?(status)
        }
    }
    
    private func loadTracks(asset: AVAsset, completion: ((AVKeyValueStatus) -> Void)? = nil) {
        asset.loadValuesAsynchronously(forKeys: [#keyPath(AVAsset.tracks)]) {
            DispatchQueue.main.async {
                self.checkAVTracks(asset: asset, completion: completion)
            }
        }
    }
    
    private func compressVideo(_ path: String, outputPath: String, quality: VideoQuality = VideoQuality.medium, completion: @escaping (CompressionResult) -> ()) -> Void {
        let source = URL(fileURLWithPath: path)
        let destination = URL(fileURLWithPath: outputPath)
        createDirectory(destination.deletingLastPathComponent())
        
        let asset = AVURLAsset(url: source)
        //        loadTracks(asset: asset) {
        //            status in
        //
        //        }
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
            completion(.onFailure(CompressionError(title: "Cannot find video track.")))
            return
        }
        
        // 文件小于1M
        if (videoTrack.totalSampleDataLength < 1048576) {
            completion(.onSuccess(source))
            return
        }
        
        let bitrate = videoTrack.estimatedDataRate
        let videoSize = videoTrack.naturalSize
        var width = abs(videoSize.width)
        var height = abs(videoSize.height)
        
        // 码率小于164kb/s
        if (bitrate < 1351680) {
            completion(.onSuccess(source))
            return
        }
        if width >= quality.value || height >= quality.value {
            if (width > height) {
                height = height * quality.value / width
                width = quality.value
            } else if (height > width) {
                width = width * quality.value / height
                height = quality.value
            } else {
                width = quality.value
                height = quality.value
            }
        }
        
        self.compression = self.compressor.compressVideo(source: source, destination: destination, progressQueue: .main, progressHandler: { progress in
            DispatchQueue.main.async { [unowned self] in
                let v = Float(progress.fractionCompleted * 100)
                channel.invokeMethod("onVideoCompressProgress", arguments: v > 100 ? 100 : v)
            }
        }, configuration: Configuration(
            quality: quality, isMinBitRateEnabled: false, keepOriginalResolution: false, videoHeight: Int(height), videoWidth: Int(width), videoBitrate: Int(width * height * 25 * 0.07)
        ), completion: completion)
        
    }
    
    func getThumbnailImage(url: URL) -> UIImage? {
        let asset: AVURLAsset = AVURLAsset.init(url: url)
        let gen: AVAssetImageGenerator = AVAssetImageGenerator.init(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let time: CMTime = CMTimeMakeWithSeconds(0, preferredTimescale: 600)
        do {
            let image: CGImage = try gen.copyCGImage(at: time, actualTime: nil)
            let thumb: UIImage = UIImage(cgImage: image)
            return thumb
        } catch {
            return nil
        }
    }
    
    func storeThumbnailToFile(url: URL, thumbnailPath: String? = nil, quality: CGFloat = 1.0, saveToLibrary: Bool = true) -> String? {
        // .mp4 -> .jpg
        var thumbURL: URL
        if (thumbnailPath != nil) {
            thumbURL = URL(fileURLWithPath: thumbnailPath!).deletingLastPathComponent()
        } else {
            thumbURL = url.deletingLastPathComponent()
        }
        createDirectory(thumbURL)
        if (thumbnailPath == nil) {
            let filename: String = url.deletingPathExtension().lastPathComponent
            thumbURL.appendPathComponent(filename + "_thumbnail.jpg")
        } else {
            thumbURL = URL(fileURLWithPath: thumbnailPath!)
        }
        // get thumb UIImage
        let thumbImage = self.getThumbnailImage(url: url)
        if (thumbImage != nil) {
            // store to file
            if let _ = thumbImage!.storeImageToFile(thumbURL.path, quality: quality) {
                if (saveToLibrary) {
                    library.save(imageAtURL: thumbURL)
                }
                return thumbURL.path
            }
        }
        return nil
    }
    
    private func generatePath(type: DirectoryType, filename: String? = nil) -> String {
        let ext = type == .movies ? ".mp4" : ".jpg"
        
        let manager = FileManager.default
        
        //        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let paths = NSTemporaryDirectory()
        var cachesDir: URL = URL(fileURLWithPath: paths).appendingPathComponent( type.rawValue, isDirectory: true)
        
        if (!manager.fileExists(atPath: cachesDir.path)) {
            try! manager.createDirectory(atPath: cachesDir.path, withIntermediateDirectories: true, attributes: nil)
        }
        var name: String
        if (filename != nil) {
            name = filename!;
        } else {
            name = String(Int(Date().timeIntervalSince1970));
        }
        cachesDir.appendPathComponent(name + ext)
        
        return cachesDir.path
    }
}
