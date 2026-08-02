import Foundation

// MARK: - 圈子后端 API 客户端
enum CircleAPI {
    static var baseURL = URL(string: "http://127.0.0.1:8900/api")!

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
    static func createPost(category: String, title: String, content: String, author: String) async throws -> Post {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PostDTO(
            id: nil, category: category, title: title, content: content,
            author: author, likes: nil, createdAt: nil
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PostDTO.self, from: data).toPost()
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

    func toPost() -> Post {
        let date = createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return Post(
            id: id ?? UUID().uuidString,
            category: category,
            title: title,
            content: content,
            author: author,
            likes: likes ?? 0,
            createdAt: date
        )
    }
}
