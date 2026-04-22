import Foundation

enum DiaryEntryMood: String, CaseIterable, Equatable, Sendable {
  case awful
  case bad
  case meh
  case okay
  case good
  case great
  case amazing

  var title: String {
    switch self {
    case .awful: "Awful"
    case .bad: "Bad"
    case .meh: "Meh"
    case .okay: "Okay"
    case .good: "Good"
    case .great: "Great"
    case .amazing: "Amazing"
    }
  }
}

struct DiaryEntry: Identifiable, Equatable, Sendable {
  let id: UUID
  let title: String
  let content: String
  let createdAt: Date
  let mood: DiaryEntryMood
  let location: String

  init(
    id: UUID,
    title: String,
    content: String,
    createdAt: Date,
    mood: DiaryEntryMood = .okay,
    location: String = ""
  ) {
    self.id = id
    self.title = title
    self.content = content
    self.createdAt = createdAt
    self.mood = mood
    self.location = location
  }

  func new(
    title: String,
    content: String,
    createdAt: Date? = nil,
    mood: DiaryEntryMood? = nil,
    location: String? = nil
  ) -> Self {
    return .init(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt ?? self.createdAt,
      mood: mood ?? self.mood,
      location: location ?? self.location
    )
  }
}
