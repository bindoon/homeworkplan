import Foundation
import Photos
import UIKit

struct DetectedScreenshot: Identifiable, Sendable {
    let id: String
    let image: UIImage
}

enum ScreenshotDetectService {
    private static let lastHandledKey = "app.homeworkplan.last-screenshot-id"
    private static let recentWindow: TimeInterval = 180

    static func detectRecentScreenshot() async -> DetectedScreenshot? {
        guard await hasPhotoAccess() else { return nil }
        guard let asset = await fetchLatestScreenshotAsset() else { return nil }

        let lastHandled = UserDefaults.standard.string(forKey: lastHandledKey)
        guard asset.localIdentifier != lastHandled else { return nil }

        guard let createdAt = asset.creationDate else { return nil }
        guard Date().timeIntervalSince(createdAt) <= recentWindow else { return nil }

        guard let image = await loadImage(from: asset) else { return nil }
        return DetectedScreenshot(id: asset.localIdentifier, image: image)
    }

    static func markHandled(id: String) {
        UserDefaults.standard.set(id, forKey: lastHandledKey)
    }

    private static func hasPhotoAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let updated = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return updated == .authorized || updated == .limited
        default:
            return false
        }
    }

    private static func fetchLatestScreenshotAsset() async -> PHAsset? {
        await Task.detached(priority: .userInitiated) {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            )
            guard let collection = collections.firstObject else { return nil }

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1

            let assets = PHAsset.fetchAssets(in: collection, options: options)
            return assets.firstObject
        }.value
    }

    private static func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
                let error = info?[PHImageErrorKey] as? Error
                if cancelled || error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}
