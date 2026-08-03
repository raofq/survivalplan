import SwiftUI
import SwiftData

// MARK: - 圈子：运动/学习打卡 + 互助社区
struct CircleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var cachedPosts: [Post]

    @State private var posts: [Post] = []
    @State private var selectedCategory = "全部"
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showNewPost = false
    @State private var showCheckIn = false
    @State private var author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"

    let categories = ["全部", "运动", "学习", "搞钱", "教育", "树洞", "工作"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 打卡入口
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("今日打卡")
                                .font(.headline)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            NavigationLink {
                                WorkoutView()
                            } label: {
                                Label("运动", systemImage: "figure.run")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            NavigationLink {
                                StudyView()
                            } label: {
                                Label("学习", systemImage: "book.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // 发帖 + 分类
                    VStack(spacing: 12) {
                        HStack {
                            Text("互助圈子")
                                .font(.headline)
                            Spacer()
                            Button {
                                showNewPost = true
                            } label: {
                                Label("发帖", systemImage: "square.and.pencil")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button(cat) {
                                        selectedCategory = cat
                                        Task { await loadPosts() }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedCategory == cat ? .orange : .gray)
                                    .font(.caption)
                                }
                            }
                        }

                        if isLoading {
                            ProgressView("加载中…")
                                .padding()
                        } else if posts.isEmpty {
                            VStack(spacing: 8) {
                                Text("还没有帖子")
                                    .foregroundStyle(.secondary)
                                Text("成为第一个发声的人吧")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 24)
                        } else {
                            ForEach(posts) { post in
                                NavigationLink {
                                    PostDetailView(post: post) {
                                        Task { await like(post) }
                                    }
                                } label: {
                                    PostCard(post: post) {
                                        Task { await like(post) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("圈子")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("匿名") { author = "匿名"; UserDefaults.standard.set("匿名", forKey: "circle_author") }
                        Button("匿名用户\(Int.random(in: 100...999))") {
                            author = "匿名用户\(Int.random(in: 100...999))"
                            UserDefaults.standard.set(author, forKey: "circle_author")
                        }
                    } label: {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showNewPost) {
                NewPostSheet(author: author) { category, title, content in
                    Task {
                        await createPost(category: category, title: title, content: content)
                    }
                }
            }
            .alert("加载失败", isPresented: $showError) {
                Button("好") {}
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await loadPosts()
        }
    }

    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await CircleAPI.fetchPosts(category: selectedCategory)
            posts = fetched
        } catch {
            errorMessage = "无法连接服务器（\(error.localizedDescription)）。请确认后端服务已启动。"
            showError = true
            posts = cachedPosts.filter { selectedCategory == "全部" || $0.category == selectedCategory }
        }
    }

    private func createPost(category: String, title: String, content: String) async {
        do {
            let post = try await CircleAPI.createPost(category: category, title: title, content: content, author: author)
            modelContext.insert(post)
            try? modelContext.save()
            await loadPosts()
        } catch {
            errorMessage = "发帖失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func like(_ post: Post) async {
        do {
            let updated = try await CircleAPI.likePost(id: post.id)
            post.likes = updated.likes
            try? modelContext.save()
        } catch {
            // 点赞失败静默（离线可容忍）
        }
    }
}

// MARK: - 帖子卡片
struct PostCard: View {
    let post: Post
    let onLike: () -> Void

    private var categoryColor: Color {
        switch post.category {
        case "运动": return .green
        case "学习": return .blue
        case "搞钱": return .orange
        case "教育": return .purple
        case "树洞": return .pink
        case "工作": return .teal
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(post.category)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.15), in: .capsule)
                    .foregroundStyle(categoryColor)
                Text(post.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(post.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(post.title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(post.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Spacer()
                Button(action: onLike) {
                    Label("\(post.likes)", systemImage: "heart")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.pink)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }
}

// MARK: - 发帖
struct NewPostSheet: View {
    let author: String
    let onPost: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category = "树洞"
    @State private var title = ""
    @State private var content = ""

    let categories = ["运动", "学习", "搞钱", "教育", "树洞", "工作"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("标题") {
                    TextField("一句话说出你想说的", text: $title)
                }

                Section("内容") {
                    TextEditor(text: $content)
                        .frame(height: 140)
                }
            }
            .navigationTitle("发布帖子")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        onPost(category, title, content)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - 帖子详情
struct PostDetailView: View {
    let post: Post
    let onLike: () -> Void

    private var categoryColor: Color {
        switch post.category {
        case "运动": return .green
        case "学习": return .blue
        case "搞钱": return .orange
        case "教育": return .purple
        case "树洞": return .pink
        case "工作": return .teal
        default: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 分类 + 作者 + 时间
                HStack(spacing: 8) {
                    Text(post.category)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15), in: .capsule)
                        .foregroundStyle(categoryColor)
                    Text(post.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(post.createdAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // 标题
                Text(post.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Divider()

                // 完整内容
                Text(post.content)
                    .font(.body)
                    .lineSpacing(6)

                Spacer(minLength: 24)

                // 点赞
                HStack {
                    Spacer()
                    Button(action: onLike) {
                        Label("\(post.likes) 人觉得暖心", systemImage: "heart.fill")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle("帖子详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
