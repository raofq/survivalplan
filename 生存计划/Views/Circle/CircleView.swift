import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 圈子：运动/学习打卡 + 互助社区
struct CircleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var cachedPosts: [Post]

    @State private var posts: [Post] = []
    @State private var selectedCategory = "全部"
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMorePosts = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showNewPost = false
    @State private var showCheckIn = false
    @State private var showOnlyMine = false
    @State private var showFavoritesOnly = false
    @State private var author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"

    let categories = ["全部", "运动", "学习", "搞钱", "教育", "树洞", "工作"]
    private let pageSize = 20

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
                                    PostCard(post: post, isMine: post.author == author, onDelete: {
                                        Task { await deletePost(post) }
                                    }) {
                                        Task { await like(post) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // 加载更多
                            if hasMorePosts {
                                Button {
                                    Task { await loadMore() }
                                } label: {
                                    HStack {
                                        Spacer()
                                        if isLoadingMore {
                                            ProgressView()
                                        } else {
                                            Text("加载更多")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .disabled(isLoadingMore)
                            } else {
                                Text("— 没有更多帖子了 —")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .padding()
            }
            .refreshable {
                await refreshPosts()
            }
            .navigationTitle("圈子")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(showOnlyMine ? "查看全部帖子" : "只看我的帖子") {
                            showOnlyMine.toggle()
                            if showOnlyMine { showFavoritesOnly = false }
                            Task { await loadPosts() }
                        }
                        Button(showFavoritesOnly ? "取消只看收藏" : "只看收藏") {
                            showFavoritesOnly.toggle()
                            if showFavoritesOnly { showOnlyMine = false }
                            Task { await loadPosts() }
                        }
                        Divider()
                        Button("匿名") { author = "匿名"; UserDefaults.standard.set("匿名", forKey: "circle_author") }
                        Button("匿名用户\(Int.random(in: 100...999))") {
                            author = "匿名用户\(Int.random(in: 100...999))"
                            UserDefaults.standard.set(author, forKey: "circle_author")
                        }
                    } label: {
                        if showOnlyMine || showFavoritesOnly {
                            Label(author, systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                        } else {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewPost) {
                NewPostSheet(author: author) { category, title, content, imageURLs, location, salary in
                    Task {
                        await createPost(category: category, title: title, content: content, imageURLs: imageURLs, location: location, salary: salary)
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
            if showFavoritesOnly {
                // 收藏是本地状态：从本地缓存过滤
                posts = cachedPosts.filter { $0.isFavorited }
                hasMorePosts = false
            } else {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, author: showOnlyMine ? author : nil, offset: 0, limit: pageSize)
                posts = fetched
                hasMorePosts = fetched.count == pageSize
            }
        } catch {
            errorMessage = "无法连接服务器（\(error.localizedDescription)）。请确认后端服务已启动。"
            showError = true
            posts = cachedPosts.filter { (selectedCategory == "全部" || $0.category == selectedCategory) && (!showOnlyMine || $0.author == author) && (!showFavoritesOnly || $0.isFavorited) }
            hasMorePosts = false
        }
    }

    private func refreshPosts() async {
        do {
            if showFavoritesOnly {
                posts = cachedPosts.filter { $0.isFavorited }
                hasMorePosts = false
            } else {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, author: showOnlyMine ? author : nil, offset: 0, limit: pageSize)
                posts = fetched
                hasMorePosts = fetched.count == pageSize
            }
        } catch {
            // 下拉刷新失败静默，保留现有列表
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMorePosts else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, author: showOnlyMine ? author : nil, offset: posts.count, limit: pageSize)
            posts.append(contentsOf: fetched)
            hasMorePosts = fetched.count == pageSize
        } catch {
            // 加载更多失败静默
        }
    }

    private func deletePost(_ post: Post) async {
        do {
            try await CircleAPI.deletePost(id: post.id, author: author)
            posts.removeAll { $0.id == post.id }
            modelContext.delete(post)
            try? modelContext.save()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func createPost(category: String, title: String, content: String, imageURLs: [String], location: String, salary: String) async {
        do {
            let post = try await CircleAPI.createPost(category: category, title: title, content: content, author: author, imageURLs: imageURLs, location: location.isEmpty ? nil : location, salary: salary.isEmpty ? nil : salary)
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
    let isMine: Bool
    let onDelete: () -> Void
    let onLike: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showReport = false
    @State private var showReported = false
    @State private var showDeleteConfirm = false

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
                // 收藏（显式按钮）
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: post.isFavorited ? "bookmark.fill" : "bookmark")
                        .font(.caption)
                        .foregroundStyle(post.isFavorited ? .orange : .secondary)
                }
                .buttonStyle(.bordered)
                .tint(post.isFavorited ? .orange : .gray)
                // 更多（举报 / 删除）
                Menu {
                    if isMine {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showReport = true
                        } label: {
                            Label("举报", systemImage: "exclamationmark.bubble")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Text(post.title)
                .font(.subheadline)
                .fontWeight(.semibold)

            // 工作帖：地区 + 薪资标签
            if post.category == "工作" {
                HStack(spacing: 8) {
                    if let location = post.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: .capsule)
                            .foregroundStyle(.orange)
                    }
                    if let salary = post.salary, !salary.isEmpty {
                        Label(salary, systemImage: "yensign.circle")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: .capsule)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if let url = CircleAPI.absoluteURL(post.imageURLs.first) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .bottomTrailing) {
                                if post.imageURLs.count > 1 {
                                    Text("\(post.imageURLs.count) 张")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.black.opacity(0.6), in: .capsule)
                                        .foregroundStyle(.white)
                                        .padding(6)
                                }
                            }
                    case .failure:
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 160)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    default:
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 160)
                            .overlay(ProgressView())
                    }
                }
            }

            Text(post.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Text(post.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(post.category == "工作" ? Color.orange.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("举报", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .confirmationDialog("删除这个帖子？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复")
        }
        .confirmationDialog("举报这个帖子？", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(["广告/营销", "人身攻击", "色情低俗", "诈骗信息", "其他"], id: \.self) { reason in
                Button(reason) {
                    submitReport(reason)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("我们会审核处理，请勿恶意举报")
        }
        .alert("已提交举报", isPresented: $showReported) {
            Button("好") {}
        } message: {
            Text("感谢反馈，我们会尽快处理")
        }
    }

    private func toggleFavorite() {
        post.isFavorited.toggle()
        try? modelContext.save()
    }

    private func submitReport(_ reason: String) {
        let author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"
        Task {
            do {
                try await CircleAPI.reportTarget(targetType: "post", targetId: post.id, reason: reason, reportedBy: author)
                showReported = true
            } catch {
                // 失败静默
            }
        }
    }
}

// MARK: - 已选图片（稳定 id，避免 offset 越界）
struct PickedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - 发帖
struct NewPostSheet: View {
    let author: String
    let onPost: (String, String, String, [String], String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category = "树洞"
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImages: [PickedImage] = []
    @State private var isUploading = false
    @State private var showPicker = false
    @State private var uploadError = false
    @State private var location = ""
    @State private var salary = ""

    let categories = ["运动", "学习", "搞钱", "教育", "树洞", "工作"]
    private let maxImages = 9

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
                        .frame(height: 120)
                }

                // 工作分类：地区 + 薪资（选填）
                if category == "工作" {
                    Section("职位信息（选填）") {
                        HStack {
                            Text("地区")
                                .foregroundStyle(.secondary)
                            TextField("如：杭州", text: $location)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("薪资")
                                .foregroundStyle(.secondary)
                            TextField("如：6-8k/月", text: $salary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("图片（选填，最多 \(maxImages) 张）") {
                    // 九宫格预览
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(selectedImages) { picked in
                            Image(uiImage: picked.image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        selectedImages.removeAll { $0.id == picked.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .padding(2)
                                    }
                                }
                        }
                        if selectedImages.count < maxImages {
                            Button {
                                showPicker = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title2)
                                    Text("\(selectedImages.count)/\(maxImages)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 90)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(isUploading)
                        }
                    }
                    if isUploading {
                        ProgressView("上传中…")
                    }
                }

                Section {
                    Text("社区规范：不发广告、不人身攻击、不传播虚假信息。违反将被删除。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("发布帖子")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("发布")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker(selectedImages: $selectedImages, maxCount: maxImages - selectedImages.count)
            }
            .alert("上传失败", isPresented: $uploadError) {
                Button("好") {}
            } message: {
                Text("图片上传失败，请重试")
            }
        }
    }

    private func submit() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedSalary = salary.trimmingCharacters(in: .whitespaces)
        guard !selectedImages.isEmpty else {
            onPost(category, title, content, [], trimmedLocation, trimmedSalary)
            dismiss()
            return
        }
        isUploading = true
        Task {
            var urls: [String] = []
            do {
                for picked in selectedImages {
                    urls.append(try await CircleAPI.uploadImage(picked.image))
                }
                onPost(category, title, content, urls, trimmedLocation, trimmedSalary)
                dismiss()
            } catch {
                uploadError = true
            }
            isUploading = false
        }
    }
}

// MARK: - 相册选择（多选，PHPicker）
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [PickedImage]
    let maxCount: Int

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = max(1, maxCount)   // 一次最多选 maxCount 张
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            for result in results {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self, let image = image as? UIImage else { return }
                    DispatchQueue.main.async {
                        if self.parent.selectedImages.count < self.parent.maxCount {
                            self.parent.selectedImages.append(PickedImage(image: image))
                        }
                    }
                }
            }
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 帖子详情
struct PostDetailView: View {
    let post: Post
    let onLike: () -> Void

    @State private var comments: [CircleComment] = []
    @State private var commentText = ""
    @State private var isLoadingComments = false
    @State private var showCommentError = false
    @State private var commentError = ""
    @State private var pageIndex = 0

    private var author: String {
        UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"
    }

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

                // 工作帖：地区 + 薪资
                if post.category == "工作" {
                    HStack(spacing: 8) {
                        if let location = post.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15), in: .capsule)
                                .foregroundStyle(.orange)
                        }
                        if let salary = post.salary, !salary.isEmpty {
                            Label(salary, systemImage: "yensign.circle")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15), in: .capsule)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Divider()

                // 完整内容
                Text(post.content)
                    .font(.body)
                    .lineSpacing(6)

                // 详情图片（多图横向滑动 + 页码）
                if !post.imageURLs.isEmpty {
                    let urls = post.imageURLs.compactMap { CircleAPI.absoluteURL($0) }
                    if !urls.isEmpty {
                        TabView {
                            ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure:
                                        Rectangle()
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                                    default:
                                        Rectangle()
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                            .overlay(ProgressView())
                                    }
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 260)
                        .overlay(alignment: .bottomTrailing) {
                            if urls.count > 1 {
                                Text("\(pageIndex + 1)/\(urls.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.6), in: .capsule)
                                    .foregroundStyle(.white)
                                    .padding(8)
                            }
                        }
                    }
                }

                Divider()

                // 评论区
                HStack {
                    Text("评论 \(comments.count)")
                        .font(.headline)
                    Spacer()
                    if isLoadingComments {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if comments.isEmpty && !isLoadingComments {
                    Text("还没有评论，说点什么鼓励一下 Ta 吧")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.author)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                                Spacer()
                                Text(comment.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(comment.content)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button(role: .destructive) {
                                reportComment(comment)
                            } label: {
                                Label("举报", systemImage: "exclamationmark.bubble")
                            }
                        }
                        Divider()
                    }
                }

                // 回复输入
                VStack(alignment: .leading, spacing: 6) {
                    // 常用 emoji 快捷栏
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["👍", "❤️", "💪", "😄", "😭", "🙏", "🤝", "✨", "加油", "抱抱"], id: \.self) { emoji in
                                Button(emoji) {
                                    commentText += emoji
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("说点什么…", text: $commentText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                        Button {
                            submitComment()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

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
        .task {
            await loadComments()
        }
        .alert("评论失败", isPresented: $showCommentError) {
            Button("好") {}
        } message: {
            Text(commentError)
        }
    }

    private func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            comments = try await CircleAPI.fetchComments(postId: post.id)
        } catch {
            commentError = "无法加载评论：\(error.localizedDescription)"
            showCommentError = true
        }
    }

    private func reportComment(_ comment: CircleComment) {
        let author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"
        Task {
            do {
                try await CircleAPI.reportTarget(targetType: "comment", targetId: comment.id, reason: "人身攻击", reportedBy: author)
            } catch {
                // 失败静默
            }
        }
    }

    private func submitComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            do {
                let comment = try await CircleAPI.createComment(postId: post.id, content: text, author: author)
                comments.append(comment)
                commentText = ""
            } catch {
                commentError = "评论失败：\(error.localizedDescription)"
                showCommentError = true
            }
        }
    }
}
