import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct MediaLibraryScreen: View {
    var onCancel: () -> Void
    var onImport: (MediaPayload) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: LibraryTab = .media
    @State private var mediaItems: [MediaLibraryItem] = []
    @State private var fileItems: [FileLibraryItem] = []
    @State private var selectedMediaId: UUID?
    @State private var selectedFileId: UUID?
    @State private var isFileImporterPresented = false
    @State private var fileImportContext: FileImportContext = .all
    @State private var isGalleryPickerPresented = false
    @State private var galleryPickerItems: [PhotosPickerItem] = []
    @State private var selectedMediaFilter: MediaFilter = .recent
    @State private var isFilterMenuPresented = false
    @State private var photoAuthorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                LibraryHeader(
                    onCancel: onCancel,
                    onManage: manageAction,
                    title: headerTitle,
                    filterLabel: selectedTab == .media ? selectedMediaFilter.title : nil,
                    onFilterTap: selectedTab == .media ? { isFilterMenuPresented = true } : nil
                )
                Group {
                    switch selectedTab {
                    case .media:
                        mediaContent
                    case .audio:
                        audioContent
                    case .files:
                        filesContent
                    }
                }
            }

            VStack(spacing: 12) {
                if selectionAvailable {
                    LibraryFooter(
                        detailText: footerDetail,
                        importTitle: footerTitle,
                        isEnabled: selectionAvailable,
                        onImport: handleImport
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    LibrarySegmentedControl(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: selectionAvailable)
            .padding(.bottom, 8)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: fileImportContext.allowedTypes,
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .photosPicker(
            isPresented: $isGalleryPickerPresented,
            selection: $galleryPickerItems,
            matching: .any(of: [.images, .videos])
        )
        .confirmationDialog("Media", isPresented: $isFilterMenuPresented) {
            ForEach(MediaFilter.allCases) { filter in
                Button(filter.title) {
                    selectedMediaFilter = filter
                }
            }
        }
        .onChange(of: galleryPickerItems) { newItems in
            guard !newItems.isEmpty else {
                return
            }
            Task {
                let additions = await buildMediaItems(from: newItems)
                await MainActor.run {
                    mergeMediaItems(additions)
                    galleryPickerItems.removeAll()
                }
            }
        }
        .onAppear {
            loadCache()
        }
        .onChange(of: selectedMediaFilter) { _ in
            if !filteredMediaItems.contains(where: { $0.id == selectedMediaId }) {
                selectedMediaId = nil
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else {
                return
            }
            photoAuthorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if hasPhotoAccess && mediaItems.isEmpty {
                loadCache()
            }
        }
    }

    private var mediaContent: some View {
        VStack(spacing: 0) {
            PermissionBanner(message: mediaBannerMessage, onManage: handleGalleryManageTap)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if filteredMediaItems.isEmpty {
                if hasPhotoAccess {
                    LibraryEmptyState(
                        iconName: "photo.on.rectangle",
                        title: "No Media Yet",
                        message: "Grant access or add media to see it here.",
                        actionTitle: mediaAccessActionTitle
                    ) {
                        handleMediaAccessAction()
                    }
                } else {
                    LibraryEmptyState(
                        iconName: "lock.shield",
                        title: "Allow Photos Access",
                        message: "SwiftCut needs access to your library to browse media.",
                        actionTitle: mediaAccessActionTitle
                    ) {
                        handleMediaAccessAction()
                    }
                }
            } else {
                LibraryGrid(
                    items: filteredMediaItems,
                    selectedItemId: selectedMediaId,
                    onSelect: { selectedMediaId = selectedMediaId == $0 ? nil : $0 }
                )
            }
        }
    }

    private var filesContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                FileSelectPanel(onSelect: {
                    fileImportContext = .all
                    isFileImporterPresented = true
                })

                if fileItems.isEmpty {
                    FileEmptyState()
                } else {
                    FileRecentSection(
                        items: fileItems,
                        selectedItemId: selectedFileId,
                        onSelect: { selectedFileId = selectedFileId == $0 ? nil : $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 140)
        }
    }

    private var audioContent: some View {
        let audioItems = fileItems.filter { $0.isAudio }
        return ScrollView {
            VStack(spacing: 16) {
                PermissionBanner(message: "Manage your audio files.") {
                    fileImportContext = .audio
                    isFileImporterPresented = true
                }

                if audioItems.isEmpty {
                    FileEmptyState(message: "No audio files yet.")
                } else {
                    FileRecentSection(
                        items: audioItems,
                        selectedItemId: selectedFileId,
                        onSelect: { selectedFileId = selectedFileId == $0 ? nil : $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 140)
        }
    }

    private var hasPhotoAccess: Bool {
        photoAuthorization == .authorized || photoAuthorization == .limited
    }

    private var selectedMediaItem: MediaLibraryItem? {
        guard let selectedMediaId else {
            return nil
        }
        return mediaItems.first { $0.id == selectedMediaId }
    }

    private var filteredMediaItems: [MediaLibraryItem] {
        let filtered: [MediaLibraryItem]
        switch selectedMediaFilter {
        case .recent:
            filtered = mediaItems
        case .screenshots:
            filtered = mediaItems.filter { $0.isScreenshot }
        case .favorites:
            filtered = mediaItems.filter { $0.isFavorite }
        case .videos:
            filtered = mediaItems.filter { $0.isVideo }
        }
        return filtered.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    private var selectedFileItem: FileLibraryItem? {
        guard let selectedFileId else {
            return nil
        }
        return fileItems.first { $0.id == selectedFileId }
    }

    private var selectionAvailable: Bool {
        switch selectedTab {
        case .media:
            return selectedMediaItem != nil
        case .audio, .files:
            return selectedFileItem != nil
        }
    }

    private var footerDetail: String {
        switch selectedTab {
        case .media:
            return selectedMediaItem?.duration ?? ""
        case .audio, .files:
            return selectedFileItem?.detail ?? ""
        }
    }

    private var footerTitle: String {
        switch selectedTab {
        case .media:
            guard let selectedMediaItem else {
                return "Select a media"
            }
            return selectedMediaItem.isVideo ? "Import Video" : "Import Photo"
        case .audio:
            guard let selectedFileItem else {
                return "Select an audio"
            }
            return selectedFileItem.isVideo ? "Import Video" : "Import Audio"
        case .files:
            guard let selectedFileItem else {
                return "Select a file"
            }
            return selectedFileItem.isVideo ? "Import Video" : "Import File"
        }
    }

    private var manageAction: (() -> Void)? {
        switch selectedTab {
        case .media:
            return nil
        case .audio:
            return nil
        case .files:
            return nil
        }
    }

    private var mediaAccessActionTitle: String {
        switch photoAuthorization {
        case .authorized, .limited:
            return "Select More"
        case .denied, .restricted:
            return "Open Settings"
        case .notDetermined:
            return "Allow Access"
        @unknown default:
            return "Allow Access"
        }
    }

    private var headerTitle: String {
        switch selectedTab {
        case .media:
            return "Library"
        case .audio:
            return "Audio"
        case .files:
            return "Files"
        }
    }

    private var mediaBannerMessage: String {
        switch photoAuthorization {
        case .limited:
            return "You have limited access to your photos."
        case .denied, .restricted:
            return "You have denied access to your photos."
        case .notDetermined:
            return "Allow access to browse your photos."
        case .authorized:
            return "Manage your photo access."
        @unknown default:
            return "Manage your photo access."
        }
    }

    private func handleMediaAccessAction() {
        switch photoAuthorization {
        case .authorized, .limited:
            isGalleryPickerPresented = true
        case .denied, .restricted:
            openSettings()
        case .notDetermined:
            requestPhotoAccess()
        @unknown default:
            requestPhotoAccess()
        }
    }

    private func handleGalleryManageTap() {
        switch photoAuthorization {
        case .authorized, .limited:
            isGalleryPickerPresented = true
        case .denied, .restricted:
            openSettings()
        case .notDetermined:
            requestPhotoAccess(openPicker: true)
        @unknown default:
            requestPhotoAccess(openPicker: true)
        }
    }

    private func handleImport() {
        switch selectedTab {
        case .media:
            guard let selectedMediaItem else {
                return
            }
            if let data = try? Data(contentsOf: selectedMediaItem.fileUrl) {
                let payload = MediaPayload(
                    data: data,
                    fileExtension: selectedMediaItem.fileExtension,
                    isVideo: selectedMediaItem.isVideo
                )
                onImport(payload)
            }
        case .audio, .files:
            guard let payload = selectedFileItem?.payload else {
                return
            }
            onImport(payload)
        }
    }

    private func requestPhotoAccess(openPicker: Bool = false) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                photoAuthorization = status
            }
            if status == .authorized || status == .limited {
                await MainActor.run {
                    loadCache()
                }
            }
            if status == .limited {
                await MainActor.run {
                    presentLimitedLibraryPicker()
                }
            } else if openPicker, status == .authorized {
                await MainActor.run {
                    isGalleryPickerPresented = true
                }
            }
        }
    }

    private func buildMediaItems(from items: [PhotosPickerItem]) async -> [MediaLibraryItem] {
        var results: [MediaLibraryItem] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }
            let contentType = item.supportedContentTypes.first
            let isVideo = contentType?.conforms(to: .movie) == true || contentType?.conforms(to: .video) == true
            let fileExtension = contentType?.preferredFilenameExtension
                ?? (isVideo ? "mov" : "jpg")
            let cachedUrl = cacheFile(data: data, fileExtension: fileExtension)
            let normalizedExtension = cachedUrl.pathExtension.isEmpty
                ? fileExtension.lowercased()
                : cachedUrl.pathExtension.lowercased()
            let duration = isVideo ? formatDuration(from: cachedUrl) : nil
            var creationDate: Date? = nil
            var isFavorite = false
            var isScreenshot = false
            if let identifier = item.itemIdentifier {
                let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                if let asset = fetch.firstObject {
                    creationDate = asset.creationDate
                    isFavorite = asset.isFavorite
                    isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                }
            }
            if creationDate == nil {
                creationDate = Date()
            }
            results.append(
                MediaLibraryItem(
                    id: UUID(),
                    fileUrl: cachedUrl,
                    fileExtension: normalizedExtension,
                    isVideo: isVideo,
                    duration: duration,
                    creationDate: creationDate,
                    isFavorite: isFavorite,
                    isScreenshot: isScreenshot
                )
            )
        }
        return results
    }

    private func mergeMediaItems(_ additions: [MediaLibraryItem]) {
        guard !additions.isEmpty else {
            return
        }
        let existingIds = Set(mediaItems.map { $0.id })
        let newItems = additions.filter { !existingIds.contains($0.id) }
        guard !newItems.isEmpty else {
            return
        }
        mediaItems.insert(contentsOf: newItems, at: 0)
        saveCache()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let additions = urls.compactMap { importFileItem(from: $0) }
            guard !additions.isEmpty else {
                return
            }
            DispatchQueue.main.async {
                fileItems.insert(contentsOf: additions, at: 0)
                saveCache()
            }
        case .failure:
            return
        }
    }

    private func importFileItem(from url: URL) -> FileLibraryItem? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let cachedUrl = cacheFile(data: data, fileExtension: url.pathExtension)
        return buildFileItem(from: cachedUrl, displayName: url.lastPathComponent)
    }

    private func buildFileItem(
        from url: URL,
        displayName: String? = nil,
        id: UUID? = nil
    ) -> FileLibraryItem? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let fileExtension = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        let fileType = UTType(filenameExtension: fileExtension)
        let isVideo = fileType?.conforms(to: .movie) == true || fileType?.conforms(to: .video) == true
        let isAudio = fileType?.conforms(to: .audio) == true
        let payload = MediaPayload(data: data, fileExtension: fileExtension, isVideo: isVideo)
        let thumbnail = generateThumbnail(from: url, isVideo: isVideo)
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        let duration = isVideo ? formatDuration(from: url) : nil
        let kindLabel: String
        let iconName: String

        if isVideo {
            kindLabel = "Video"
            iconName = "film"
        } else if isAudio {
            kindLabel = "Audio"
            iconName = "waveform"
        } else {
            kindLabel = "Picture"
            iconName = "photo"
        }

        return FileLibraryItem(
            id: id ?? UUID(),
            payload: payload,
            title: displayName ?? url.lastPathComponent,
            detail: duration ?? sizeText,
            thumbnail: thumbnail,
            isVideo: isVideo,
            isAudio: isAudio,
            duration: duration,
            kindLabel: kindLabel,
            iconName: iconName,
            fileUrl: url
        )
    }

    private func generateThumbnail(from url: URL, isVideo: Bool) -> UIImage? {
        if isVideo {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
                return nil
            }
            return UIImage(cgImage: image)
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func formatDuration(from url: URL) -> String? {
        let asset = AVAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return formatDuration(seconds: seconds)
    }

    private func formatDuration(seconds: Double) -> String? {
        guard seconds.isFinite else {
            return nil
        }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsUrl)
    }

    private func presentLimitedLibraryPicker() {
        guard let controller = topViewController() else {
            return
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
        } else {
            openSettings()
        }
    }

    private func cacheFile(data: Data, fileExtension: String) -> URL {
        let baseUrl = cacheDirectoryUrl().appendingPathComponent("MediaLibraryFiles", isDirectory: true)
        if !FileManager.default.fileExists(atPath: baseUrl.path) {
            try? FileManager.default.createDirectory(at: baseUrl, withIntermediateDirectories: true)
        }
        let fileExtensionValue = fileExtension.isEmpty ? "dat" : fileExtension.lowercased()
        let fileUrl = baseUrl
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtensionValue)
        try? data.write(to: fileUrl, options: .atomic)
        return fileUrl
    }

    private func cacheDirectoryUrl() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private func cacheFileUrl() -> URL {
        cacheDirectoryUrl().appendingPathComponent("media-library-cache.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFileUrl()),
              let cache = try? JSONDecoder().decode(MediaLibraryCache.self, from: data)
        else {
            return
        }

        let cachedMedia = cache.mediaItems.compactMap { item -> MediaLibraryItem? in
            let fileUrl = URL(fileURLWithPath: item.filePath)
            guard FileManager.default.fileExists(atPath: fileUrl.path) else {
                return nil
            }
            let duration = item.duration ?? (item.isVideo ? formatDuration(from: fileUrl) : nil)
            let fileExtension = item.fileExtension.isEmpty
                ? fileUrl.pathExtension.lowercased()
                : item.fileExtension
            return MediaLibraryItem(
                id: item.id,
                fileUrl: fileUrl,
                fileExtension: fileExtension,
                isVideo: item.isVideo,
                duration: duration,
                creationDate: item.creationDate,
                isFavorite: item.isFavorite,
                isScreenshot: item.isScreenshot
            )
        }
        mediaItems = cachedMedia

        let cachedFiles = cache.fileItems.compactMap { item in
            buildFileItem(
                from: URL(fileURLWithPath: item.filePath),
                displayName: item.title,
                id: item.id
            )
        }
        fileItems = cachedFiles
    }

    private func saveCache() {
        let cache = MediaLibraryCache(
            mediaItems: mediaItems.map {
                MediaCacheItem(
                    id: $0.id,
                    filePath: $0.fileUrl.path,
                    fileExtension: $0.fileExtension,
                    isVideo: $0.isVideo,
                    duration: $0.duration,
                    creationDate: $0.creationDate,
                    isFavorite: $0.isFavorite,
                    isScreenshot: $0.isScreenshot
                )
            },
            fileItems: fileItems.map {
                FileCacheItem(
                    id: $0.id,
                    title: $0.title,
                    filePath: $0.fileUrl.path,
                    isVideo: $0.isVideo,
                    isAudio: $0.isAudio
                )
            }
        )
        guard let data = try? JSONEncoder().encode(cache) else {
            return
        }
        try? data.write(to: cacheFileUrl(), options: .atomic)
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }),
               var controller = window.rootViewController {
                while let presented = controller.presentedViewController {
                    controller = presented
                }
                return controller
            }
        }
        return nil
    }
}

private struct LibraryHeader: View {
    var onCancel: () -> Void
    var onManage: (() -> Void)?
    var title: String
    var filterLabel: String?
    var onFilterTap: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .foregroundColor(AppTheme.textSecondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            if let filterLabel, let onFilterTap {
                Button(action: onFilterTap) {
                    HStack(spacing: 6) {
                        Text(filterLabel)
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            if let onManage {
                Button(action: onManage) {
                    Text("Manage")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.accentBlue)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 60, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }
}

private struct LibrarySegmentedControl: View {
    @Binding var selectedTab: LibraryTab

    var body: some View {
        HStack(spacing: 16) {
            segmentButton(title: "Gallery", systemName: "newspaper", tab: .media)
            segmentButton(title: "Audio", systemName: "headphones", tab: .audio)
            segmentButton(title: "File", systemName: "folder", tab: .files)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 76)
        .liquidGlass(in: Capsule())
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }

    private func segmentButton(title: String, systemName: String, tab: LibraryTab) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedTab == tab ? Color.white.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionBanner: View {
    let message: String
    var onManage: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(2)

            Spacer()

            Button(action: onManage) {
                Text("Manage")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.accentBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.surface)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

private struct LibraryGrid: View {
    let items: [MediaLibraryItem]
    let selectedItemId: UUID?
    var onSelect: (UUID) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(items) { item in
                    LibraryCell(
                        item: item,
                        isSelected: item.id == selectedItemId,
                        onSelect: { onSelect(item.id) }
                    )
                }
            }
            .padding(4)
            .padding(.bottom, 140)
        }
    }
}

private struct LibraryCell: View {
    let item: MediaLibraryItem
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Button(action: onSelect) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.surfaceDark)

                    MediaFileThumbnailView(fileUrl: item.fileUrl, isVideo: item.isVideo, size: proxy.size)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if let duration = item.duration {
                        Text(duration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.accentBlue, lineWidth: 3)

                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(AppTheme.accentBlue)
                            .clipShape(Circle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(6)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
            }
            .buttonStyle(.plain)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MediaFileThumbnailView: View {
    let fileUrl: URL
    let isVideo: Bool
    let size: CGSize

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.surfaceDark)
            }
        }
        .task(id: "\(fileUrl.lastPathComponent)-\(Int(size.width))") {
            thumbnail = generateThumbnail()
        }
    }

    private func generateThumbnail() -> UIImage? {
        if isVideo {
            let asset = AVAsset(url: fileUrl)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
                return nil
            }
            return UIImage(cgImage: image)
        }
        return UIImage(contentsOfFile: fileUrl.path)
    }
}

private struct FileSelectPanel: View {
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accentBlue)
                Text("Select from Gallery")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(AppTheme.surface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct FileEmptyState: View {
    var message = "No recent files yet."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundColor(AppTheme.textSecondary)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.surface)
        .cornerRadius(12)
    }
}

private struct FileRecentSection: View {
    let items: [FileLibraryItem]
    let selectedItemId: UUID?
    var onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    FileRow(
                        item: item,
                        isSelected: item.id == selectedItemId,
                        onSelect: { onSelect(item.id) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FileRow: View {
    let item: FileLibraryItem
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                FileRowThumbnail(item: item)
                    .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        Text(item.kindLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.surfaceDark)
                            .clipShape(Capsule())

                        Text(item.detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentBlue)
                }
            }
            .padding(12)
            .background(AppTheme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.accentBlue : AppTheme.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FileRowThumbnail: View {
    let item: FileLibraryItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceDark)

            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: item.iconName)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .clipped()
    }
}

private struct LibraryEmptyState: View {
    let iconName: String
    let title: String
    let message: String
    let actionTitle: String
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAction) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentBlue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct LibraryFooter: View {
    let detailText: String
    let importTitle: String
    let isEnabled: Bool
    var onImport: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                Text(detailText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Button(action: onImport) {
                HStack {
                    Text(importTitle)
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundColor(.white)
                .background(AppTheme.accentBlue)
                .cornerRadius(12)
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.6)
        }
        .padding(16)
        .background(AppTheme.background.opacity(0.95))
    }
}

private enum LibraryTab {
    case media
    case audio
    case files
}

private enum MediaFilter: String, CaseIterable, Identifiable {
    case recent
    case screenshots
    case favorites
    case videos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .screenshots:
            return "Screenshots"
        case .favorites:
            return "Favorites"
        case .videos:
            return "Videos"
        }
    }

}

private struct MediaLibraryCache: Codable {
    let mediaItems: [MediaCacheItem]
    let fileItems: [FileCacheItem]
}

private struct MediaCacheItem: Codable {
    let id: UUID
    let filePath: String
    let fileExtension: String
    let isVideo: Bool
    let duration: String?
    let creationDate: Date?
    let isFavorite: Bool
    let isScreenshot: Bool
}

private struct FileCacheItem: Codable {
    let id: UUID
    let title: String
    let filePath: String
    let isVideo: Bool
    let isAudio: Bool
}

private enum FileImportContext {
    case all
    case audio

    var allowedTypes: [UTType] {
        switch self {
        case .all:
            return [.image, .movie, .audio]
        case .audio:
            return [.audio]
        }
    }
}

private struct MediaLibraryItem: Identifiable {
    let id: UUID
    let fileUrl: URL
    let fileExtension: String
    let isVideo: Bool
    let duration: String?
    let creationDate: Date?
    let isFavorite: Bool
    let isScreenshot: Bool
}

private struct FileLibraryItem: Identifiable {
    let id: UUID
    let payload: MediaPayload
    let title: String
    let detail: String
    let thumbnail: UIImage?
    let isVideo: Bool
    let isAudio: Bool
    let duration: String?
    let kindLabel: String
    let iconName: String
    let fileUrl: URL
}

#Preview {
    MediaLibraryScreen(onCancel: {}, onImport: { _ in })
}
