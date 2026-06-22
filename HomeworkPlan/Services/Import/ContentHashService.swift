import CryptoKit
import Foundation

enum ContentHashService {
    static func sha256(_ text: String) -> String {
        sha256(data: Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }

    static func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
