import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 圈子：运动/学习打卡 + 互助社区
struct CircleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Post.createdAt, order: .reverse) private var cachedPosts: [Post]

    @State private var posts: [Post] = []
    @State private var selectedCategory = "全部"
    @State private var announcement: Announcement? = nil
    @State private var announcementExpanded = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMorePosts = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showNewPost = false
    @State private var showCheckIn = false
    @State private var showOnlyMine = false
    @State private var showLikedOnly = false
    @State private var showNicknameEditor = false
    @State private var nicknameInput = ""
    @State private var author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"

    let categories = ["全部", "运动", "学习", "搞钱", "教育", "树洞", "工作"]
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 公告横幅（站内信）
                    if let ann = announcement {
                        Button {
                            announcementExpanded.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: ann.isMaintenance ? "hammer.fill" : "megaphone.fill")
                                    .foregroundStyle(ann.isMaintenance ? .white : .orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ann.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ann.isMaintenance ? .white : .primary)
                                    if announcementExpanded {
                                        Text(ann.content)
                                            .font(.caption)
                                            .foregroundStyle(ann.isMaintenance ? .white.opacity(0.9) : .secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(ann.isMaintenance ? .white.opacity(0.8) : .secondary)
                                    .rotationEffect(.degrees(announcementExpanded ? 180 : 0))
                            }
                            .padding(12)
                            .background(ann.isMaintenance ? Color.orange : Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    // 打卡入口
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text(L("今日打卡"))
                                .font(.headline)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            NavigationLink {
                                WorkoutView()
                            } label: {
                                Label(L("运动"), systemImage: "figure.run")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            NavigationLink {
                                StudyView()
                            } label: {
                                Label(L("学习"), systemImage: "book.fill")
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
                            Text(L("互助圈子"))
                                .font(.headline)
                            Spacer()
                            Button {
                                showNewPost = true
                            } label: {
                                Label(L("发帖"), systemImage: "square.and.pencil")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button(L(cat)) {
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
                                Text(L("还没有帖子"))
                                    .foregroundStyle(.secondary)
                                Text(L("成为第一个发声的人吧"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 24)
                        } else {
                            ForEach(posts) { post in
                                PostCard(post: post, isMine: post.author == author, onDelete: {
                                    Task { await deletePost(post) }
                                }, onLike: {
                                    Task { await like(post) }
                                })
                            }
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
                                        Text(L("加载更多"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(isLoadingMore)
                        } else {
                            Text(L("— 没有更多帖子了 —"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
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
            .listStyle(.grouped)
        .scrollIndicators(.hidden)
        .navigationTitle("圈子")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(showOnlyMine ? "查看全部帖子" : "只看我的帖子") {
                            showOnlyMine.toggle()
                            if showOnlyMine { showLikedOnly = false }
                            Task { await loadPosts() }
                        }
                        Button(showLikedOnly ? "取消只看我点赞的帖子" : "只看我点赞的帖子") {
                            showLikedOnly.toggle()
                            if showLikedOnly { showOnlyMine = false }
                            Task { await loadPosts() }
                        }
                        Divider()
                        Button(L("自定义昵称…")) {
                            nicknameInput = author == "匿名" ? "" : author
                            showNicknameEditor = true
                        }
                        Button(L("匿名")) { setAuthor("匿名") }
                    } label: {
                        if showOnlyMine || showLikedOnly {
                            Label(L(author), systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                        } else {
                            Text(L(author))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewPost) {
                NewPostSheet(author: author) { category, title, content, imageURLs, location, salary, company, contact in
                    Task {
                        await createPost(category: category, title: title, content: content, imageURLs: imageURLs, location: location, salary: salary, company: company, contact: contact)
                    }
                }
            }
            .alert("加载失败", isPresented: $showError) {
                Button(L("好")) {}
            } message: {
                Text(errorMessage)
            }
            .alert("设置昵称", isPresented: $showNicknameEditor) {
                TextField("给自己起个名字（最多 12 字）", text: $nicknameInput)
                Button(L("确定")) {
                    let trimmed = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        setAuthor(String(trimmed.prefix(12)))
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(L("昵称只是显示名，不会影响你的身份"))
            }
        }
        .task {
            await loadPosts()
            // 拉取公告（失败静默，走本地缓存）
            if let ann = await CircleAPI.fetchAnnouncement() {
                announcement = ann
                if ann.isMaintenance { announcementExpanded = true }
            }
        }
    }

    private func setAuthor(_ name: String) {
        author = name
        UserDefaults.standard.set(name, forKey: "circle_author")
    }

    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if showLikedOnly {
                // 我点赞的帖子：后端按设备过滤（likes 表）
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, likedBy: CircleAPI.deviceID, offset: 0, limit: pageSize)
                posts = fetched
                hasMorePosts = fetched.count == pageSize
            } else {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, deviceId: showOnlyMine ? CircleAPI.deviceID : nil, offset: 0, limit: pageSize)
                posts = fetched
                hasMorePosts = fetched.count == pageSize
            }
        } catch {
            errorMessage = Lf("无法连接服务器（%@）。请稍后再试。", error.localizedDescription)
            showError = true
            posts = cachedPosts.filter { (selectedCategory == "全部" || $0.category == selectedCategory) && (!showLikedOnly || $0.isLikedByMe) }
            hasMorePosts = false
        }
    }

    private func refreshPosts() async {
        do {
            if showLikedOnly {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, likedBy: CircleAPI.deviceID, offset: 0, limit: pageSize)
                posts = fetched
                hasMorePosts = fetched.count == pageSize
            } else {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, deviceId: showOnlyMine ? CircleAPI.deviceID : nil, offset: 0, limit: pageSize)
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
            if showLikedOnly {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, likedBy: CircleAPI.deviceID, offset: posts.count, limit: pageSize)
                posts.append(contentsOf: fetched)
                hasMorePosts = fetched.count == pageSize
            } else {
                let fetched = try await CircleAPI.fetchPosts(category: selectedCategory, deviceId: showOnlyMine ? CircleAPI.deviceID : nil, offset: posts.count, limit: pageSize)
                posts.append(contentsOf: fetched)
                hasMorePosts = fetched.count == pageSize
            }
        } catch {
            // 加载更多失败静默
        }
    }

    private func deletePost(_ post: Post) async {
        do {
            try await CircleAPI.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
            modelContext.delete(post)
            try? modelContext.save()
        } catch {
            errorMessage = Lf("删除失败：%@", error.localizedDescription)
            showError = true
        }
    }

    private func createPost(category: String, title: String, content: String, imageURLs: [String], location: String, salary: String, company: String, contact: String) async {
        do {
            let post = try await CircleAPI.createPost(category: category, title: title, content: content, author: author, imageURLs: imageURLs, location: location.isEmpty ? nil : location, salary: salary.isEmpty ? nil : salary, company: company.isEmpty ? nil : company, contact: contact.isEmpty ? nil : contact)
            post.deviceId = CircleAPI.deviceID   // 本地缓存标记「我的帖子」
            modelContext.insert(post)
            try? modelContext.save()
            DailyPostCounter.increment(isWorkPost: category == "工作")  // 计入当日发帖数
            await loadPosts()
        } catch {
            errorMessage = Lf("发帖失败：%@", error.localizedDescription)
            showError = true
        }
    }

    private func like(_ post: Post) async {
        AnalyticsService.shared.track("action_like")
        do {
            let (updated, liked) = try await CircleAPI.likePost(id: post.id)
            post.likes = updated.likes
            post.isLikedByMe = liked
            try? modelContext.save()
            // 「只看我点赞的帖子」列表里取消点赞 → 立即移除
            if showLikedOnly && !liked {
                withAnimation {
                    posts.removeAll { $0.id == post.id }
                }
            }
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
            // 正文区：点击进详情
            NavigationLink {
                PostDetailView(post: post, onLike: onLike)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(post.category)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(categoryColor.opacity(0.15), in: .capsule)
                            .foregroundStyle(categoryColor)
                        Text(L(post.author))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Text(post.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

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
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            // 操作行：时间 / ⋯ 菜单 / 点赞（不在 NavigationLink 内，按钮可正常点击）
            HStack {
                Text(post.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    if isMine {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(L("删除"), systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showReport = true
                        } label: {
                            Label(L("举报"), systemImage: "exclamationmark.bubble")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button(action: onLike) {
                    Label("\(post.likes)", systemImage: post.isLikedByMe ? "heart.fill" : "heart")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(post.isLikedByMe ? .pink : .gray)
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
                    Label(L("删除"), systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label(L("举报"), systemImage: "exclamationmark.bubble")
                }
            }
        }
        .confirmationDialog("删除这个帖子？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(L("删除后无法恢复"))
        }
        .confirmationDialog("举报这个帖子？", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(["广告/营销", "人身攻击", "色情低俗", "诈骗信息", "其他"], id: \.self) { reason in
                Button(L(reason)) {
                    submitReport(reason)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(L("我们会审核处理，请勿恶意举报"))
        }
        .alert("已提交举报", isPresented: $showReported) {
            Button(L("好")) {}
        } message: {
            Text(L("感谢反馈，我们会尽快处理"))
        }
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
    let onPost: (String, String, String, [String], String, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category = "树洞"
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImages: [PickedImage] = []
    @State private var isUploading = false
    @State private var showPicker = false
    @State private var showLimitAlert = false
    @State private var uploadError = false
    @State private var location = ""
    @State private var salary = ""
    @State private var company = ""
    @State private var contact = ""
    @State private var showFieldError = false
    @State private var fieldErrorMessage = ""

    let categories = ["运动", "学习", "搞钱", "教育", "树洞", "工作"]
    private let maxImages = 9

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { Text(L($0)) }
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

                // 工作分类：公司/联系方式必填 + 地区/薪资选填
                if category == "工作" {
                    Section {
                        HStack {
                            Text(L("公司名称 *"))
                                .foregroundStyle(.secondary)
                            TextField("必填", text: $company)
                                
                        }
                        HStack {
                            Text(L("联系方式 *"))
                                .foregroundStyle(.secondary)
                            TextField("手机/微信/邮箱（展示时脱敏）", text: $contact)
                                
                        }
                        HStack {
                            Text(L("地区"))
                                .foregroundStyle(.secondary)
                            TextField("如：杭州", text: $location)
                                
                        }
                        HStack {
                            Text(L("薪资"))
                                .foregroundStyle(.secondary)
                            TextField("如：6-8k/月", text: $salary)
                                
                        }
                    } header: {
                        Text(L("职位信息"))
                    } footer: {
                        Text(L("为防招聘诈骗，公司名称和联系方式为必填；联系方式展示时会脱敏，正规招聘不会要求先交钱。"))
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
                    Text(L("社区规范：不发广告、不人身攻击、不传播虚假信息。违反将被删除。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !ProFeatures.circlePostLimit {
                        HStack(spacing: 4) {
                            if category == "工作" {
                                Text("今日还可发布 \(DailyPostCounter.remainingWork()) 条工作帖")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("今日还可发布 \(DailyPostCounter.remaining()) 次")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.grouped)
        .scrollIndicators(.hidden)
        .navigationTitle("发布帖子")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text(L("发布"))
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker(selectedImages: $selectedImages, maxCount: maxImages - selectedImages.count)
            }
            .alert("上传失败", isPresented: $uploadError) {
                Button(L("好")) {}
            } message: {
                Text(L("图片上传失败，请重试"))
            }
            .alert("今日发帖已达上限", isPresented: $showLimitAlert) {
                Button(L("好")) {}
            } message: {
                Text("免费用户每天可发布 \(DailyPostCounter.freeDailyLimit) 条。升级 Pro 后可不受限制地发帖。")
            }
            .alert("信息不完整", isPresented: $showFieldError) {
                Button(L("好")) {}
            } message: {
                Text(fieldErrorMessage)
            }
        }
    }

    private func submit() {
        // 免费用户每日发帖上限（工作帖单独 1 条）
        if category == "工作" {
            guard DailyPostCounter.canPostWorkToday() else {
                showLimitAlert = true
                return
            }
        } else {
            guard DailyPostCounter.canPostToday() else {
                showLimitAlert = true
                return
            }
        }
        // 工作帖必填校验
        if category == "工作" {
            guard !company.trimmingCharacters(in: .whitespaces).isEmpty else {
                fieldErrorMessage = "请填写公司名称"
                showFieldError = true
                return
            }
            guard !contact.trimmingCharacters(in: .whitespaces).isEmpty else {
                fieldErrorMessage = "请填写联系方式（手机/微信/邮箱）"
                showFieldError = true
                return
            }
        }
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedSalary = salary.trimmingCharacters(in: .whitespaces)
        guard !selectedImages.isEmpty else {
            onPost(category, title, content, [], trimmedLocation, trimmedSalary, company.trimmingCharacters(in: .whitespaces), contact.trimmingCharacters(in: .whitespaces))
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
                onPost(category, title, content, urls, trimmedLocation, trimmedSalary, company.trimmingCharacters(in: .whitespaces), contact.trimmingCharacters(in: .whitespaces))
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
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var showCommentError = false
    @State private var commentError = ""
    @State private var pageIndex = 0
    @State private var commentsInitialized = false

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
                    Text(L(post.author))
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

                // 工作帖：公司 + 未验证 + 地区/薪资 + 联系方式
                if post.category == "工作" {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if let company = post.company, !company.isEmpty {
                                Label(company, systemImage: "building.2.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.orange.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.orange)
                            }
                            // 未验证标签（阶段 2 做人工验证后变为已验证）
                            Text(L("未验证"))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.gray.opacity(0.15), in: .capsule)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            if let location = post.location, !location.isEmpty {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if let salary = post.salary, !salary.isEmpty {
                                Label(salary, systemImage: "yensign.circle")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if let contact = post.contactMasked, !contact.isEmpty {
                            Label("联系：\(contact)", systemImage: "phone.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // 防骗横幅（工作帖）
                if post.category == "工作" {
                    Label(L("凡要求先交押金、培训费、垫资的都是骗局；本平台不保证招聘信息真实性"), systemImage: "exclamationmark.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
                }

                Divider()

                // 完整内容
                Text(post.content)
                    .font(.body)
                    .lineSpacing(6)

                // 详情图片（多图横向滑动 + 页码；懒加载：只渲染当前页±1，避免一次请求全部）
                if !post.imageURLs.isEmpty {
                    let urls = post.imageURLs.compactMap { CircleAPI.absoluteURL($0) }
                    if !urls.isEmpty {
                        TabView(selection: $pageIndex) {
                            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                                Group {
                                    if abs(index - pageIndex) <= 1 {
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
                                    } else {
                                        Rectangle()
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                            .opacity(0.3)
                                    }
                                }
                                .tag(index)
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
                    Text(L("还没有评论，说点什么鼓励一下 Ta 吧"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L(comment.author))
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
                                Label(L("举报"), systemImage: "exclamationmark.bubble")
                            }
                        }
                        Divider()
                    }

                    // 加载更多评论
                    if hasMoreComments {
                        Button {
                            Task { await loadMoreComments() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoadingMoreComments {
                                    ProgressView()
                                } else {
                                    Text(L("加载更多评论"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(isLoadingMoreComments)
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

                // 点赞（toggle：再点取消）
                HStack {
                    Spacer()
                    Button(action: onLike) {
                        Label("\(post.likes) 人觉得暖心", systemImage: post.isLikedByMe ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(post.isLikedByMe ? .pink : .gray)
                    Spacer()
                }
            }
            .padding()
        }
        .listStyle(.grouped)
        .scrollIndicators(.hidden)
        .navigationTitle("帖子详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadComments()
        }
        .alert("评论失败", isPresented: $showCommentError) {
            Button(L("好")) {}
        } message: {
            Text(commentError)
        }
    }

    /// 评论加载：缓存优先 → 静默刷新第一页；无缓存 → loading 拉第一页
    private func loadComments() async {
        let pageSize = 20
        if let cached = CircleAPI.commentCache[post.id], !cached.isEmpty {
            comments = cached
            commentsInitialized = true
            hasMoreComments = cached.count == pageSize
            // 静默刷新第一页（合并新评论）
            if let fresh = try? await CircleAPI.fetchComments(postId: post.id, offset: 0, limit: pageSize) {
                comments = fresh
                CircleAPI.commentCache[post.id] = fresh
                hasMoreComments = fresh.count == pageSize
            }
            return
        }
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let fresh = try await CircleAPI.fetchComments(postId: post.id, offset: 0, limit: pageSize)
            comments = fresh
            CircleAPI.commentCache[post.id] = fresh
            hasMoreComments = fresh.count == pageSize
        } catch {
            commentError = "无法加载评论：\(error.localizedDescription)"
            showCommentError = true
        }
        commentsInitialized = true
    }

    /// 加载更多评论（分页追加）
    private func loadMoreComments() async {
        guard !isLoadingMoreComments, hasMoreComments else { return }
        isLoadingMoreComments = true
        defer { isLoadingMoreComments = false }
        do {
            let fresh = try await CircleAPI.fetchComments(postId: post.id, offset: comments.count, limit: 20)
            comments.append(contentsOf: fresh)
            CircleAPI.commentCache[post.id] = comments
            hasMoreComments = fresh.count == 20
        } catch {
            // 加载更多失败静默
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
                CircleAPI.commentCache[post.id] = comments   // 同步更新缓存
                commentText = ""
            } catch {
                commentError = "评论失败：\(error.localizedDescription)"
                showCommentError = true
            }
        }
    }
}
