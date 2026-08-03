import Foundation
import UIKit

// MARK: - 圈子后端 API 客户端
enum CircleAPI {
    static var baseURL = URL(string: "http://127.0.0.1:8900/api")!
    /// 服务器根（uploads 静态目录挂在根下）
    static var serverRoot: URL { baseURL.deletingLastPathComponent() }

    /// 相对路径（/uploads/x.png）→ 完整 URL
    static func absoluteURL(_ path: String?) -> URL? {
        guard let path, path.hasPrefix("/") else { return nil }
        return URL(string: path, relativeTo: serverRoot)?.absoluteURL
    }

    // 拉取帖子（可选按分类）
    static func fetchPosts(category: String? = nil) async throws -> [Post] {
        var url = baseURL.appendingPathComponent("posts")
        if let category, category != "全部" {
            url = url.appending(queryItems: [URLQueryItem(name: "category", value: category)])
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PostDTO].self, from: data).map { $0.toPost() }
    }

    // 发布帖子
    static func createPost(category: String, title: String, content: String, author: String, imageURLs: [String] = []) async throws -> Post {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PostDTO(
            id: nil, category: category, title: title, content: content,
            author: author, likes: nil, createdAt: nil, imageURLs: imageURLs
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PostDTO.self, from: data).toPost()
    }

    // 上传图片，返回服务器相对路径
    static func uploadImage(_ image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw URLError(.cannotDecodeContentData)
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data2, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        struct UploadResult: Codable { let url: String }
        return try JSONDecoder().decode(UploadResult.self, from: data2).url
    }

    // 点赞
    static func likePost(id: String) async throws -> Post {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts/\(id)/like"))
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PostDTO.self, from: data).toPost()
    }

    // 拉取帖子评论
    static func fetchComments(postId: String) async throws -> [CircleComment] {
        let url = baseURL.appendingPathComponent("posts/\(postId)/comments")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([CommentDTO].self, from: data).map { $0.toComment() }
    }

    // 发表评论
    static func createComment(postId: String, content: String, author: String) async throws -> CircleComment {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts/\(postId)/comments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CommentDTO(
            id: nil, postId: postId, content: content, author: author, createdAt: nil
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommentDTO.self, from: data).toComment()
    }

    // 举报帖子或评论
    static func reportTarget(targetType: String, targetId: String, reason: String, reportedBy: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("reports"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ReportDTO(
            targetType: targetType, targetId: targetId, reason: reason, reportedBy: reportedBy
        ))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - 举报 DTO
struct ReportDTO: Codable {
    let targetType: String
    let targetId: String
    let reason: String
    let reportedBy: String

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetId = "target_id"
        case reason
        case reportedBy = "reported_by"
    }
}

// MARK: - 评论
struct CircleComment: Identifiable {
    let id: String
    let postId: String
    let content: String
    let author: String
    let createdAt: Date
}

struct CommentDTO: Codable {
    let id: String?
    let postId: String?
    let content: String
    let author: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content, author
        case postId = "post_id"
        case createdAt = "created_at"
    }

    func toComment() -> CircleComment {
        let date = createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return CircleComment(
            id: id ?? UUID().uuidString,
            postId: postId ?? "",
            content: content,
            author: author,
            createdAt: date
        )
    }
}

// MARK: - DTO（与后端 JSON 对齐）
struct PostDTO: Codable {
    let id: String?
    let category: String
    let title: String
    let content: String
    let author: String
    let likes: Int?
    let createdAt: String?
    let imageURLs: [String]?

    enum CodingKeys: String, CodingKey {
        case id, category, title, content, author, likes
        case createdAt = "created_at"
        case imageURLs = "image_urls"
    }

    func toPost() -> Post {
        let date = createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        let urls = imageURLs ?? []
        return Post(
            id: id ?? UUID().uuidString,
            category: category,
            title: title,
            content: content,
            author: author,
            likes: likes ?? 0,
            imageURL: urls.first,
            imageURLs: urls,
            createdAt: date
        )
    }
}
