import Foundation
import UIKit

enum ImportImageStore {
    private static let folderName = "ImportImages"

    static func save(_ image: UIImage, recordID: UUID) throws -> String {
        let directory = try imagesDirectory()
        let filename = "\(recordID.uuidString).jpg"
        let fileURL = directory.appendingPathComponent(filename)

        guard let data = image.fixedOrientation().jpegData(compressionQuality: 0.85) else {
            throw ImportImageStoreError.encodingFailed
        }

        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    static func load(relativePath: String) -> UIImage? {
        guard !relativePath.isEmpty,
              let url = fileURL(for: relativePath),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func fileURL(for relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        return try? imagesDirectory().appendingPathComponent(relativePath)
    }

    private static func imagesDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

enum ImportImageStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "无法保存导入图片"
        }
    }
}
