import Foundation
import UIKit

// MARK: - 公告（站内信）
struct Announcement: Codable, Equatable {
    let title: String
    let content: String
    let level: String   // normal | maintenance
    let createdAt: String?

    var isMaintenance: Bool { level == "maintenance" }
}

extension CircleAPI {
    /// 拉取当前公告；失败返回 nil（静默，不打扰用户）。
    /// 成功时缓存到 UserDefaults——停服/断网期间横幅依然显示（告知维护中）。
    static func fetchAnnouncement() async -> Announcement? {
        var request = URLRequest(url: baseURL.appendingPathComponent("announcement"))
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let ann = try? JSONDecoder().decode(Announcement.self, from: data) else { return nil }
            if let cached = try? JSONEncoder().encode(ann) {
                UserDefaults.standard.set(cached, forKey: "circle_announcement")
            }
            return ann
        } catch {
            // 失败：用本地缓存的公告（如维护期间后端不可达）
            if let cached = UserDefaults.standard.data(forKey: "circle_announcement"),
               let ann = try? JSONDecoder().decode(Announcement.self, from: cached) {
                return ann
            }
            return nil
        }
    }
}

// MARK: - 圈子后端 API 客户端
enum CircleAPI {
    /// 生产环境（自定义域名 → Render，自动 HTTPS；比直连 onrender.com 国内访问更稳）
    static let productionBaseURL = URL(string: "https://survivalplan.bbroot.com/api")!
    /// 本地开发后端
    static let localBaseURL = URL(string: "http://127.0.0.1:8900/api")!

    /// 当前使用的后端地址：
    /// - DEBUG 构建默认本地（开发方便），可设 UserDefaults `circle_custom_base` 指向任意测试后端
    ///   （例：cpolar 隧道 https://xxx.cpolar.top/api），或 `circle_use_production=true` 切公网
    /// - Release 构建固定生产
    static var baseURL: URL {
        #if DEBUG
        if let custom = UserDefaults.standard.string(forKey: "circle_custom_base"),
           let url = URL(string: custom) {
            return url
        }
        return UserDefaults.standard.bool(forKey: "circle_use_production") ? productionBaseURL : localBaseURL
        #else
        return productionBaseURL
        #endif
    }

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

    // 拉取帖子（可选按分类/作者/设备/点赞者，分页）
    static func fetchPosts(category: String? = nil, author: String? = nil, deviceId: String? = nil, likedBy: String? = nil, offset: Int = 0, limit: Int = 20) async throws -> [Post] {
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
        if let likedBy {
            query.append(URLQueryItem(name: "liked_by", value: likedBy))
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
    // 删除帖子（按设备鉴权：只能删本机发的帖）
    static func deletePost(id: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts/\(id)").appending(queryItems: [URLQueryItem(name: "device_id", value: deviceID)]))
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    // 发布帖子
    static func createPost(category: String, title: String, content: String, author: String, imageURLs: [String] = [], location: String? = nil, salary: String? = nil, company: String? = nil, contact: String? = nil) async throws -> Post {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PostDTO(
            id: nil, category: category, title: title, content: content,
            author: author, likes: nil, createdAt: nil, imageURLs: imageURLs,
            location: location, salary: salary, company: company, contact: contact, contactMasked: nil, liked: nil, deviceId: deviceID
        ))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PostDTO.self, from: data).toPost()
    }

    // 上传图片，返回服务器相对路径
    static func uploadImage(_ image: UIImage) async throws -> String {
        // 压缩：最长边 ≤ 1600px（圈子展示足够），12MP 原图压到 ~300-500KB，
        // 慢速隧道/弱网下也能在超时前传完
        let maxDim: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDim / longest)
        let resized: UIImage
        if scale < 1 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            resized = UIGraphicsImageRenderer(size: newSize).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            resized = image
        }
        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            throw URLError(.cannotDecodeContentData)
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60  // 覆盖 session 的 10s 请求超时（上传走慢隧道/弱网）
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

    // 点赞/取消点赞（toggle）：返回最新帖子 + 是否已赞
    static func likePost(id: String) async throws -> (Post, Bool) {
        var request = URLRequest(url: baseURL.appendingPathComponent("posts/\(id)/like").appending(queryItems: [URLQueryItem(name: "device_id", value: deviceID)]))
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let dto = try JSONDecoder().decode(PostDTO.self, from: data)
        return (dto.toPost(), dto.liked ?? false)
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
    let company: String?
    let contact: String?          // 仅编码（发帖请求传给后端）；响应不返回
    let contactMasked: String?    // 仅解码（后端返回的脱敏联系方式）
    let liked: Bool?              // 仅点赞接口返回（是否已赞）
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id, category, title, content, author, likes, location, salary, company, contact, liked
        case createdAt = "created_at"
        case imageURLs = "image_urls"
        case contactMasked = "contact_masked"
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
            company: company,
            contactMasked: contactMasked,
            createdAt: date
        )
    }
}

// MARK: - 功能使用统计（匿名埋点）
/// 只上报事件名 + 轻量参数（页面/操作类型），不采集用户输入内容；
/// 设备身份复用 CircleAPI.deviceID（匿名 UUID）；离线缓冲 + 批量上报，失败不打扰用户。
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let lock = NSLock()   // 任意线程可调（非 MainActor 隔离）
    private var queue: [[String: Any]] = []
    private var flushing = false
    private let batchSize = 20
    private let maxQueue = 200   // 离线上限，防无限膨胀

    private init() {
        lock.lock()
        if let saved = UserDefaults.standard.data(forKey: "analytics_queue"),
           let arr = try? JSONSerialization.jsonObject(with: saved) as? [[String: Any]] {
            queue = Array(arr.prefix(maxQueue))
        }
        lock.unlock()
        // 兜底：每 60 秒尝试清一次队列
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.flush() }
        }
    }

    func track(_ event: String, params: [String: Any]? = nil) {
        lock.lock()
        var item: [String: Any] = ["event": event, "ts": Int(Date().timeIntervalSince1970)]
        if let params { item["params"] = params }
        queue.append(item)
        if queue.count > maxQueue { queue.removeFirst(queue.count - maxQueue) }
        let shouldFlush = queue.count >= 10   // 满 10 条立即上报
        lock.unlock()
        if shouldFlush {
            Task { await flush() }
        }
    }

    func flush() async {
        lock.lock()
        guard !queue.isEmpty, !flushing else { lock.unlock(); return }
        flushing = true
        let batch = Array(queue.prefix(batchSize))
        lock.unlock()
        var req = URLRequest(url: CircleAPI.baseURL.appendingPathComponent("analytics"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let payload: [String: Any] = ["device_id": CircleAPI.deviceID, "events": batch]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        if let (_, resp) = try? await CircleAPI.session.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200 {
            lock.lock()
            queue.removeFirst(batch.count)   // 成功清队列
            lock.unlock()
        }
        lock.lock()
        flushing = false
        persistLocked()
        lock.unlock()
    }

    private func persistLocked() {
        if let d = try? JSONSerialization.data(withJSONObject: queue) {
            UserDefaults.standard.set(d, forKey: "analytics_queue")
        }
    }
}
