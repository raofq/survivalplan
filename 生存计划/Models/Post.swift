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
    var company: String? = nil      // 工作帖公司名
    var contactMasked: String? = nil // 工作帖联系方式（脱敏后）
    var deviceId: String? = nil
    var isLikedByMe: Bool = false
    var createdAt: Date = Date()

    init(id: String = UUID().uuidString, category: String, title: String, content: String, author: String, likes: Int = 0, imageURL: String? = nil, imageURLs: [String] = [], location: String? = nil, salary: String? = nil, company: String? = nil, contactMasked: String? = nil, deviceId: String? = nil, isLikedByMe: Bool = false, createdAt: Date = Date()) {
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
        self.company = company
        self.contactMasked = contactMasked
        self.deviceId = deviceId
        self.isLikedByMe = isLikedByMe
        self.createdAt = createdAt
    }
}
