import Foundation

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLine = trimmed.components(separatedBy: .newlines).joined(separator: " ")
        if singleLine.count <= 80 {
            return singleLine
        }
        return String(singleLine.prefix(80)) + "..."
    }
}
