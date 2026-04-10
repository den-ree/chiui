import Foundation

/// Represents a single diary entry
struct DiaryEntry: Identifiable, Equatable, Sendable {
  /// Unique identifier for the entry
  let id: UUID
  /// Title of the diary entry
  let title: String
  /// Content of the diary entry
  let content: String
  /// Date when the entry was created
  let createdAt: Date

  func new(title: String, content: String, createdAt: Date? = nil) -> Self {
    return .init(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt ?? self.createdAt
    )
  }
}
