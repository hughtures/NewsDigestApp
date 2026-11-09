import os
import SwiftUI
import UniformTypeIdentifiers


struct DigestHistoryView: View {
    @State private var digests: [NewsDigest] = []
    @State private var selectedDigest: NewsDigest?
    @State private var showingDeleteAlert = false
    @State private var digestToDelete: NewsDigest?

    var body: some View {
        ZStack {
            BlurredBackground(material: .hudWindow)
                .ignoresSafeArea()

            HSplitView {
                // Sidebar
                sidebar

                // Main content
                if let selected = selectedDigest {
                    digestDetail(selected)
                } else {
                    emptySelection
                }
            }
        }
        .onAppear {
            loadDigests()
        }
        .alert("Delete Digest", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let digest = digestToDelete {
                    deleteDigest(digest)
                }
            }
        } message: {
            Text("Are you sure you want to delete this digest? This action cannot be undone.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(digests.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()

            SmoothDivider()

            // List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(digests) { digest in
                        DigestHistoryRow(
                            digest: digest,
                            isSelected: selectedDigest?.id == digest.id,
                            onSelect: {
                                selectedDigest = digest
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 200, idealWidth: 220)
    }

    // MARK: - Detail View

    private func digestDetail(_ digest: NewsDigest) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(digest.formattedDate)
                        .font(.system(size: 16, weight: .semibold))

                    Text("\(digest.articleCount) articles")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    GlassButton("Export", systemImage: "square.and.arrow.up") {
                        exportDigest(digest)
                    }

                    GlassButton("Delete", systemImage: "trash") {
                        digestToDelete = digest
                        showingDeleteAlert = true
                    }
                }
            }
            .padding()

            SmoothDivider()

            // Content
            ScrollView {
                FormattedMarkdownView(markdown: digest.content)
                    .textSelection(.enabled)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No Digest Selected")
                .font(.system(size: 16, weight: .semibold))

            Text("Select a digest from the sidebar to view it")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func loadDigests() {
        digests = StorageService.shared.loadDigests()
        if selectedDigest == nil, let first = digests.first {
            selectedDigest = first
        }
    }

    private func deleteDigest(_ digest: NewsDigest) {
        do {
            try StorageService.shared.deleteDigest(digest)
            digests.removeAll { $0.id == digest.id }

            if selectedDigest?.id == digest.id {
                selectedDigest = digests.first
            }
        } catch {
            Log.storage.error("Error deleting digest: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func exportDigest(_ digest: NewsDigest) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "md")!]
        savePanel.nameFieldStringValue = digest.fileName

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? digest.content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - DigestHistoryRow

struct DigestHistoryRow: View {
    let digest: NewsDigest
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(digest.formattedDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text("\(digest.articleCount) articles")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        Color.accentColor.opacity(0.2)
                    } else if isHovered {
                        Color.white.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
