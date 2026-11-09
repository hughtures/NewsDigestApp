import SwiftUI
import AppKit

struct DigestView: View {
    @ObservedObject var viewModel = DigestViewModel.shared

    var body: some View {
        ZStack {
            // Background blur
            BlurredBackground(material: .hudWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding()

                SmoothDivider()

                // Content
                if viewModel.isLoading {
                    loadingState
                } else if let error = viewModel.error {
                    errorState(error)
                } else if let digest = viewModel.currentDigest {
                    digestContent(digest)
                } else {
                    emptyState
                }
            }
        }
        .frame(width: 620, height: 840)
    }

    private var header: some View {
        HStack {
            // Icon and title
            HStack(spacing: 12) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("NewsDigest")
                        .font(.system(size: 16, weight: .semibold))

                    if let digest = viewModel.currentDigest {
                        Text(digest.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Refresh button
            GlassButton("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await viewModel.generateDigest()
                }
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer()

            GlassCard {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Generating your daily digest...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Fetching articles and analyzing with Claude")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .padding()

            Spacer()
        }
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Spacer()

            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("Error")
                        .font(.system(size: 16, weight: .semibold))

                    Text(error.localizedDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    GlassButton("Try Again", systemImage: "arrow.clockwise") {
                        viewModel.clearError()
                        Task {
                            await viewModel.generateDigest()
                        }
                    }
                }
                .padding()
            }
            .padding()

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("No Digest Yet")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Click 'Refresh' to generate your daily news digest")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()

            Spacer()
        }
    }

    private func digestContent(_ digest: NewsDigest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Article count badge
                HStack {
                    Spacer()
                    Text("\(digest.articleCount) articles analyzed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Beautifully formatted markdown content
                FormattedMarkdownView(markdown: digest.content)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Digest Renderer

struct FormattedMarkdownView: View {
    let markdown: String

    var body: some View {
        let elements = DigestParser.parse(markdown)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                render(element)
            }
        }
    }

    @ViewBuilder
    private func render(_ element: DigestElement) -> some View {
        switch element {
        case .title(let text):
            Text(text)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .padding(.bottom, 8)

        case .section(let text):
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 24)
                .padding(.bottom, 12)

        case .article(let article):
            ArticleRow(article: article)
                .padding(.bottom, 16)

        case .paragraph(let text):
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Article Row

struct ArticleRow: View {
    let article: DigestArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let url = article.url {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 12))
                        Text(article.sourceName.map { "Read on \($0)" } ?? "Read Full Article")
                            .font(.system(size: 12, weight: .medium))
                            .underline()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(.leading, 12)
    }
}
