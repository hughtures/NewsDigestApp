import SwiftUI

struct SettingsWindow: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "screenshotTab")
    @State private var showingAddFeed = false
    @State private var selectedCategory: NewsCategory = .topNews

    var body: some View {
        ZStack {
            BlurredBackground(material: .hudWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Feeds").tag(1)
                    Text("About").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                SmoothDivider()

                // Tab content
                // (A plain switch rather than TabView: the native tab control
                // would draw underneath the custom segmented picker above.)
                Group {
                    switch selectedTab {
                    case 1: feedsTab
                    case 2: aboutTab
                    default: generalTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                SmoothDivider()

                // Save button
                HStack {
                    Spacer()

                    GlassButton("Save Settings", systemImage: "checkmark.circle.fill") {
                        viewModel.saveSettings()
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // API Key Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Anthropic API Key")
                            .font(.system(size: 14, weight: .semibold))

                        SecureField("sk-ant-...", text: $viewModel.apiKey)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )

                        HStack {
                            if let result = viewModel.apiKeyTestResult {
                                Text(result)
                                    .font(.system(size: 12))
                                    .foregroundColor(result.hasPrefix("✓") ? .green : .red)
                            }

                            Spacer()

                            if viewModel.isTestingAPIKey {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                GlassButton("Test Connection", systemImage: "checkmark.circle") {
                                    Task {
                                        await viewModel.testAPIKey()
                                    }
                                }
                            }
                        }
                    }
                }

                // Model Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Claude Model")
                            .font(.system(size: 14, weight: .semibold))

                        Picker("", selection: $viewModel.model) {
                            ForEach(ClaudeModel.allCases) { model in
                                Text(model.displayName).tag(model.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Schedule Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Schedule")
                            .font(.system(size: 14, weight: .semibold))

                        Toggle("Enable automatic daily digest", isOn: $viewModel.isScheduleEnabled)

                        if viewModel.isScheduleEnabled {
                            HStack {
                                Text("Time:")
                                    .font(.system(size: 13))

                                Spacer()

                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let calendar = Calendar.current
                                            var components = DateComponents()
                                            components.hour = viewModel.scheduleTime.hour ?? 6
                                            components.minute = viewModel.scheduleTime.minute ?? 0
                                            return calendar.date(from: components) ?? Date()
                                        },
                                        set: { newDate in
                                            let calendar = Calendar.current
                                            let components = calendar.dateComponents([.hour, .minute], from: newDate)
                                            viewModel.scheduleTime = components
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Feeds Tab

    private var feedsTab: some View {
        VStack(spacing: 0) {
            // Category selector
            HStack(spacing: 8) {
                ForEach(NewsCategory.allCases) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category.emoji)
                            .font(.system(size: 18))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedCategory == category ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            SmoothDivider()

            // Feeds list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedCategory.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal)
                        .padding(.top)

                    let categoryFeeds = viewModel.feedSources.filter { $0.category == selectedCategory }

                    if categoryFeeds.isEmpty {
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)

                                Text("No feeds for this category")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                GlassButton("Add Feed", systemImage: "plus") {
                                    showingAddFeed = true
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .padding(.horizontal)
                    } else {
                        ForEach(categoryFeeds) { feed in
                            FeedSourceRow(
                                feed: feed,
                                onToggle: { viewModel.toggleFeed(feed) },
                                onDelete: { viewModel.removeFeed(feed) }
                            )
                            .padding(.horizontal)
                        }

                        GlassButton("Add Feed", systemImage: "plus") {
                            showingAddFeed = true
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingAddFeed) {
            AddFeedSheet(category: selectedCategory) { feed in
                viewModel.addFeed(feed)
                showingAddFeed = false
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(radius: 10)

                Text("NewsDigest")
                    .font(.system(size: 24, weight: .bold))

                Text("Version 1.0.0")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automated daily news digest powered by Claude AI")
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - FeedSourceRow

struct FeedSourceRow: View {
    let feed: FeedSource
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        GlassCard(padding: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.name)
                        .font(.system(size: 13, weight: .medium))

                    Text(feed.url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { feed.isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .toggleStyle(.switch)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.5)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - AddFeedSheet

struct AddFeedSheet: View {
    let category: NewsCategory
    let onAdd: (FeedSource) -> Void

    @State private var name = ""
    @State private var urlString = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlurredBackground(material: .hudWindow)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Add RSS Feed")
                    .font(.system(size: 18, weight: .semibold))

                Text(category.sectionTitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Feed Name")
                        .font(.system(size: 12, weight: .medium))

                    TextField("e.g., TechCrunch", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Feed URL")
                        .font(.system(size: 12, weight: .medium))

                    TextField("https://example.com/feed", text: $urlString)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }

                HStack {
                    GlassButton("Cancel") {
                        dismiss()
                    }

                    Spacer()

                    GlassButton("Add Feed", systemImage: "plus") {
                        if !name.isEmpty, !urlString.isEmpty, let url = URL(string: urlString) {
                            let feed = FeedSource(name: name, url: url, category: category)
                            onAdd(feed)
                        }
                    }
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
            .padding(30)
        }
        .frame(width: 400, height: 300)
    }
}
