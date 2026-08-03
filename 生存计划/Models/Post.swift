import Foundation
import SwiftData

// MARK: - 圈子帖子（云端同步缓存）
@Model
final class Post {
    var id: String = UUID().uuidString
    var category: String = ""
    var title: String = ""
    var content: String = ""
    var author: String = ""
    var likes: Int = 0
    var imageURL: String? = nil
    var imageURLs: [String] = []
    var location: String? = nil
    var salary: String? = nil
    var createdAt: Date = Date()

    init(id: String = UUID().uuidString, category: String, title: String, content: String, author: String, likes: Int = 0, imageURL: String? = nil, imageURLs: [String] = [], location: String? = nil, salary: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.title = title
        self.content = content
        self.author = author
        self.likes = likes
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.location = location
        self.salary = salary
        self.createdAt = createdAt
    }
}
