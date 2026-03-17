import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var workspaceStore = WorkspaceStore()
    @State private var navigationPath = NavigationPath()
    @State private var isMediaLibraryPresented = false
    @State private var pendingProjectId: UUID?
    @State private var isLoadingMediaLibrary = false
    @State private var isOpeningProject = false
    @State private var isShowingSplash = true

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LauncherScreen(
                onStartNewProject: handleStartNewProject,
                onOpenHistory: handleOpenHistoryIfNeeded
            )
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        ProjectHistoryScreen(
                            projects: workspaceStore.projects,
                            onCreateNewProject: handleCreateNewProject,
                            onOpenProject: { project in
                                handleOpenProject(project)
                            },
                            onExit: handleExitApp,
                            onDeleteProject: handleDeleteProject
                        )
                    case .studio(let projectId):
                        if let project = workspaceStore.project(withId: projectId) {
                            TimelineEditorScreen(
                                project: project,
                                onBack: { navigationPath.removeLast() },
                                onProjectReady: { isOpeningProject = false },
                                onUpdateAspectRatio: { ratio in
                                    workspaceStore.updateAspectRatio(
                                        for: project.id,
                                        aspectRatio: ratio
                                    )
                                },
                                onUpdateUhdSettings: { resolution, frameRate, bitrate in
                                    workspaceStore.updateUhdSettings(
                                        for: project.id,
                                        resolution: resolution,
                                        frameRate: frameRate,
                                        bitrate: bitrate
                                    )
                                }
                            )
                        }
                    }
                }
        }
        .overlay {
            if isLoadingMediaLibrary {
                LoadingOverlay()
            }
        }
        .overlay {
            if isOpeningProject {
                OpeningProjectOverlay()
            }
        }
        .overlay {
            if isShowingSplash {
                SplashScreen()
            }
        }
        .task {
            await workspaceStore.load()
            if !workspaceStore.projects.isEmpty {
                navigationPath.append(Route.history)
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            isShowingSplash = false
        }
        .fullScreenCover(
            isPresented: $isMediaLibraryPresented,
            onDismiss: handleLibraryDismissed
        ) {
            MediaLibraryScreen(
                onCancel: { isMediaLibraryPresented = false },
                onImport: handleImportPayload
            )
        }
    }

    private func handleStartNewProject() {
        guard workspaceStore.projects.isEmpty else {
            navigationPath.append(Route.history)
            return
        }
        isLoadingMediaLibrary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isMediaLibraryPresented = true
            isLoadingMediaLibrary = false
        }
    }

    private func handleCreateNewProject() {
        isLoadingMediaLibrary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isMediaLibraryPresented = true
            isLoadingMediaLibrary = false
        }
    }

    private func handleOpenHistoryIfNeeded() {
        guard navigationPath.isEmpty else {
            return
        }
        if !workspaceStore.projects.isEmpty, !isShowingSplash {
            navigationPath.append(Route.history)
        }
    }

    private func handleImportPayload(_ payload: MediaPayload) {
        if let project = workspaceStore.createProject(from: payload) {
            pendingProjectId = project.id
            isMediaLibraryPresented = false
            isOpeningProject = true
        }
    }

    private func handleLibraryDismissed() {
        guard let projectId = pendingProjectId else {
            isLoadingMediaLibrary = false
            return
        }
        pendingProjectId = nil
        navigationPath.append(Route.studio(projectId: projectId))
    }

    private func handleOpenProject(_ project: WorkspaceProject) {
        isOpeningProject = true
        DispatchQueue.main.async {
            navigationPath.append(Route.studio(projectId: project.id))
        }
    }

    private func handleDeleteProject(_ project: WorkspaceProject) {
        workspaceStore.deleteProject(project)
    }

    private func handleExitApp() {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Opening Library…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}

private struct OpeningProjectOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Opening Project…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.72))
            .cornerRadius(16)
        }
    }
}

private enum Route: Hashable {
    case history
    case studio(projectId: UUID)
}
