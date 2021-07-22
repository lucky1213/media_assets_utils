//
//  UIimageExtension.swift
//  media_asset_utils
//
//  Created by iMac on 2021/7/14.
//

import UIKit

extension UIImage {
    public func storeImageToFile(_ path: String, quality: CGFloat = 1.0) -> String? {
        let fileURL = URL(fileURLWithPath: path)
        guard let data = imageToData(quality) else {
            return nil
        }
        do {
            try data.write(to: fileURL)
            return path
        } catch {
            return nil
        }
    }
    
    public func imageToData(_ quality: CGFloat = 1.0) -> Data? {
        guard let data = self.jpegData(compressionQuality: quality) else {
            return nil
        }
        return data
    }
}
