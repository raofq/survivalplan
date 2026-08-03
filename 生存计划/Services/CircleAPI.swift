import Foundation
import UIKit

// MARK: - 圈子后端 API 客户端
enum CircleAPI {
    static var baseURL = URL(string: "http://127.0.0.1:8900/api")!
    /// 服务器根（uploads 静态目录挂在根下）
    static var serverRoot: URL { baseURL.deletingLastPathComponent() }

    /// 设备身份：首次启动生成 UUID，持久存储；发帖/评论/举报/我的帖子用它区分用户
    static var deviceID: String {
        let key = "circle_device_id"
        if let id = UserDefaults.standard.string(forKey: key) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// 统一网络会话：10s 请求超时，避免请求挂起导致界面无限加载
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// 相对路径（/uploads/x.png）→ 完整 URL
    static func absoluteURL(_ path: String?) -> URL? {
        guard let path, path.hasPrefix("/") else { return nil }
        return URL(string: path, relativeTo: serverRoot)?.absoluteURL
    }

    // 拉取帖子（可选按分类/作者/设备，分页）
    static func fetchPosts(category: String? = nil, author: String? = nil, deviceId: String? = nil, offset: Int = 0, limit: Int = 20) async throws -> [Post] {
        var url = baseURL.appendingPathComponent("posts")
        var query: [URLQueryItem] = []
        if let category, category != "全部" {
            query.append(URLQueryItem(name: "category", value: category))
        }
        if let author {
            query.append(URLQueryItem(name: "author", value: author))
        }
        if let deviceId {
            query.append(URLQueryItem(name: "device_id", value: deviceId))
        }
        query.append(URLQueryItem(name: "offset", value: String(offset)))
        query.append(URLQueryItem(name: "limit", value: String(limit)))
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PostDTO].self, from: data).map { $0.toPost() }
    }

    // 删除自己的帖子
    static func deletePost(id: String, author: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts/\(id)").appending(queryItems: [URLQueryItem(name: "author", value: author)]))
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    // 发布帖子
    static func createPost(category: String, title: String, content: String, author: String, imageURLs: [String] = [], location: String? = nil, salary: String? = nil) async throws -> Post {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PostDTO(
            id: nil, category: category, title: title, content: content,
            author: author, likes: nil, createdAt: nil, imageURLs: imageURLs,
            location: location, salary: salary, deviceId: deviceID
        ))
        let (data, response) = try await session.data(for: request)
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

        let (data2, response) = try await session.data(for: request)
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
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PostDTO.self, from: data).toPost()
    }

    /// 评论内存缓存（postID → 已加载的评论），避免反复进出详情页重复请求
    static var commentCache: [String: [CircleComment]] = [:]

    // 拉取帖子评论（分页）
    static func fetchComments(postId: String, offset: Int = 0, limit: Int = 20) async throws -> [CircleComment] {
        var url = baseURL.appendingPathComponent("posts/\(postId)/comments")
        url = url.appending(queryItems: [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
        let (data, response) = try await session.data(from: url)
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
            id: nil, postId: postId, content: content, author: author, createdAt: nil, deviceId: deviceID
        ))
        let (data, response) = try await session.data(for: request)
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
            targetType: targetType, targetId: targetId, reason: reason, reportedBy: reportedBy, deviceId: deviceID
        ))
        let (_, response) = try await session.data(for: request)
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
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetId = "target_id"
        case reason
        case reportedBy = "reported_by"
        case deviceId = "device_id"
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
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id, content, author
        case postId = "post_id"
        case createdAt = "created_at"
        case deviceId = "device_id"
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
    let location: String?
    let salary: String?
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id, category, title, content, author, likes, location, salary
        case createdAt = "created_at"
        case imageURLs = "image_urls"
        case deviceId = "device_id"
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
            location: location,
            salary: salary,
            createdAt: date
        )
    }
}
