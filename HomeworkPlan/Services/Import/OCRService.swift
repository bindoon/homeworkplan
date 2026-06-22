import Foundation
import UIKit
import Vision

enum OCRServiceError: LocalizedError {
    case noText
    case timedOut
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noText:
            return "未能从图片中识别到文字"
        case .timedOut:
            return "文字识别超时，请换一张更清晰的截图重试"
        case .recognitionFailed(let error):
            return "文字识别失败：\(error.localizedDescription)"
        }
    }
}

enum OCRService {
    private static let timeoutSeconds: TimeInterval = 45
    private static let maxPixelDimension: CGFloat = 2048

    static func recognizeText(from image: UIImage) async throws -> String {
        let prepared = image
            .fixedOrientation()
            .resized(maxDimension: maxPixelDimension)

        return try await withTimeout(seconds: timeoutSeconds) {
            try await Task.detached(priority: .userInitiated) {
                try performRecognition(on: prepared)
            }.value
        }
    }

    private static func performRecognition(on image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.noText
        }

        var recognizedText: String?
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                recognitionError = OCRServiceError.recognitionFailed(error)
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            recognizedText = lines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRServiceError.recognitionFailed(error)
        }

        if let recognitionError {
            throw recognitionError
        }

        guard let text = recognizedText, !text.isEmpty else {
            throw OCRServiceError.noText
        }

        return text
    }

    private static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw OCRServiceError.timedOut
            }

            guard let result = try await group.next() else {
                throw OCRServiceError.timedOut
            }
            group.cancelAll()
            return result
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    func resized(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
