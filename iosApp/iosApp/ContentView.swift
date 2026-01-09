import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var workspaceStore = WorkspaceStore()
    @State private var navigationPath = NavigationPath()
    @State private var isMediaLibraryPresented = false
    @State private var pendingProjectId: UUID?
    @State private var isLoadingMediaLibrary = false
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
                                navigationPath.append(Route.studio(projectId: project.id))
                            },
                            onExit: handleExitApp,
                            onDeleteProject: handleDeleteProject
                        )
                    case .studio(let projectId):
                        if let project = workspaceStore.project(withId: projectId) {
                            StudioScreen(
                                project: project,
                                onBack: { navigationPath.removeLast() }
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

private enum Route: Hashable {
    case history
    case studio(projectId: UUID)
}
