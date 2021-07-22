//
//  Lubannie.swift
//  media_asset_utils
//
//  Created by iMac on 2021/7/14.
//

import UIKit

/// 尺寸类型
///
/// - square: 矩形
/// - rectangle: 长方形
/// - other: 其他
enum SizeType {
    case square(minValue: CGFloat, maxValue: CGFloat)
    case rectangle(minValue: CGFloat, maxValue: CGFloat)
    case other(minValue: CGFloat, maxValue: CGFloat)
    
    init?(size: CGSize) {
        let minV = min(size.width, size.height)
        let maxV = max(size.width, size.height)
        
        let ratio = minV / maxV
        
        if ratio > 0 && ratio <= 0.5 {
            // [1:1 ~ 9:16)
            self = .square(minValue: minV, maxValue: maxV)
        } else if ratio > 0.5 && ratio < 0.5625 {
            // [9:16 ~ 1:2)
            self = .other(minValue: minV, maxValue: maxV)
        } else if ratio >= 0.5625 && ratio <= 1 {
            // [1:2 ~ 1:∞)
            self = .rectangle(minValue: minV, maxValue: maxV)
        } else {
            return nil
        }
    }
    
    var size: (minV: CGFloat, maxV: CGFloat, size: CGFloat) {
        switch self {
        case .square(let minV, let maxV):
            let widthType = WidthType.init(minV: minV, maxV: maxV)
            return widthType.size
        case .rectangle(let minV, let maxV):
            let multiple = ((maxV / 1280) == 0) ? 1 : (maxV / 1280)
            let size = max(100, ((minV / multiple) * (maxV / multiple)) / (1440 * 2560) * 400)
            return (minV: minV / multiple, maxV: maxV / multiple, size: size)
        case .other(let minV, let maxV):
            let ratio = minV / maxV
            let multiple = CGFloat(ceilf(Float(maxV / (1280 / ratio))))
            let size = max(100, ((minV / multiple) * (maxV / multiple)) / (1280 * (1280 / ratio)) * 500)
            return (minV: minV / multiple, maxV: maxV / multiple, size: size)
        }
    }
}

/// 宽度类型
///
/// - small: 小
/// - middle: 中
/// - large: 大
/// - giant: 巨大
/// - 0..<1664::小区间
/// - 1664..<4990:: 中区间
/// - 4990..<10240:: 大区间
enum WidthType {
    case small(minValue: CGFloat, maxValue: CGFloat)
    case middle(minValue: CGFloat, maxValue: CGFloat)
    case large(minValue: CGFloat, maxValue: CGFloat)
    case giant(minValue: CGFloat, maxValue: CGFloat)
    
    init(minV: CGFloat, maxV: CGFloat) {
        switch maxV {
        case 0..<1664:
            self = .small(minValue: minV, maxValue: maxV)
        case 1664..<4990:
            self = .middle(minValue: minV, maxValue: maxV)
        case 4990..<10240:
            self = .large(minValue: minV, maxValue: maxV)
        default:
            self = .giant(minValue: minV, maxValue: maxV)
        }
    }
    
    var size: (minV: CGFloat, maxV: CGFloat, size: CGFloat) {
        switch self {
        case .small(let minV, let maxV):
            return (minV: minV, maxV: maxV, size: max(60, minV * maxV / pow(1664, 2) * 150))
        case .middle(let minV, let maxV):
            return (minV: minV / 2, maxV: maxV / 2, size: max(60, ((minV / 2) * (maxV / 2)) / pow(4990 / 2, 2) * 300))
        case .large(let minV, let maxV):
            return (minV: minV / 4, maxV: maxV / 4, size: max(100, ((minV / 4) * (maxV / 4)) / pow(10240 / 4, 2) * 300))
        case .giant(let minV, let maxV):
            let multiple = ((maxV / 1280) == 0) ? 1 : (maxV / 1280)
            return (minV: minV / multiple, maxV: maxV / multiple, size: max(100, ((minV / multiple) * (maxV / multiple)) / pow(2560, 2) * 300))
        }
    }
}

extension UIImage {
    
    /// 压缩图片方法
    ///
    /// - Returns: 返回压缩后的图片
    public func compressedImage(_ quality: CGFloat = 1.0) -> UIImage {
        if let imgData = self.jpegData(compressionQuality: quality) {
            let imgFileSize = imgData.count
            print("origin file size: \(ByteCountFormatter.string(fromByteCount: Int64(imgFileSize), countStyle: .binary))")
            
            if let type = SizeType.init(size: self.size) {
                let compressSize = type.size.size
                let resizedImage = resizeTo(size: CGSize(width: type.size.minV, height: type.size.maxV))
                if let data = resizedImage.compressTo(size: compressSize) {
                    print("compressed file size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary))")
                    return UIImage(data: data) ?? self
                }
            }
        }
        return self
    }
    
    
    /// 压缩数据方法
    ///
    /// - Returns: 返回压缩后的数据
    public func compressedData(_ quality: CGFloat = 1.0) -> Data? {
        if let imgData = self.jpegData(compressionQuality: quality) {
            let imgFileSize = imgData.count
            print("origin file size: \(ByteCountFormatter.string(fromByteCount: Int64(imgFileSize), countStyle: .binary))")
            
            if let type = SizeType.init(size: self.size) {
                let compressSize = type.size.size
                let resizedImage = resizeTo(size: CGSize(width: type.size.minV, height: type.size.maxV))
                if let data = resizedImage.compressTo(size: compressSize) {
                    print("compressed file size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary))")
                    return data
                }
            }
        }
        return nil
    }
    
    
    /// 调整大小方法
    ///
    /// - Parameter size: 尺寸
    /// - Returns: 返回调整后的图片
    public func resizeTo(size: CGSize) -> UIImage {
        let ratio = self.size.height / self.size.width
        var factor: CGFloat = 1.0
        if ratio > 1 {
            factor = size.height / size.width
        } else {
            factor = size.width / size.height
        }
        let toSize = CGSize(width: self.size.width * factor, height: self.size.height * factor)
        
        UIGraphicsBeginImageContext(toSize)
        draw(in: CGRect.init(origin: CGPoint(x: 0, y: 0), size: toSize))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image ?? self
    }
    
    
    /// 压缩方法
    ///
    /// - Parameter size: 压缩率
    /// - Returns: 返回压缩后的数据
    public func compressTo(size: CGFloat) -> Data? {
        var compression: CGFloat = 1.0
        let maxCompression: CGFloat = 0.1
        guard var data = self.jpegData(compressionQuality: compression) else {
            return nil
        }
        while CGFloat(data.count) > size && compression > maxCompression {
            compression -= 0.1
            if let temp = self.jpegData(compressionQuality: compression) {
                data = temp
            } else {
                return data
            }
        }
        return data
    }
    
    /// 添加水印文字方法
    ///
    /// - Parameters:
    ///   - text: 水印文字
    ///   - position: 水印文字坐标
    ///   - attributes: 水印文字属性
    /// - Returns: 返回添加水印后的图片
    public func addTextMark(text: NSString, position: CGPoint, attributes: NSDictionary) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        self.draw(in: CGRect.init(x: 0, y: 0, width: self.size.width, height: self.size.height))
        text.draw(at: position, withAttributes: (attributes as! [NSAttributedString.Key : Any]))
        let newImg = UIGraphicsGetImageFromCurrentImageContext() as UIImage?
        UIGraphicsEndImageContext()
        
        return newImg!
    }
    
    /// 添加水印图片方法
    ///
    /// - Parameters:
    ///   - markImage: 水印图片素材
    ///   - position: 水印图片坐标尺寸
    /// - Returns: 返回添加水印后的图片
    public func addImageMark(markImage: UIImage, position: CGRect) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        self.draw(in: CGRect.init(x: 0, y: 0, width: self.size.width, height: self.size.height))
        markImage.draw(in: position)
        let newImage = UIGraphicsGetImageFromCurrentImageContext() as UIImage?
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    /// 截图方法
    ///
    /// - Parameter view: 要截取的视图
    /// - Returns: 返回截取的图片
    public func shortCut(view: UIView) -> UIImage {
        UIGraphicsBeginImageContext(view.bounds.size)
        let currContext = UIGraphicsGetCurrentContext()
        view.layer.render(in: currContext!)
        let image = UIGraphicsGetImageFromCurrentImageContext() as UIImage?
        UIGraphicsEndImageContext()
        
        return image!
    }
}
