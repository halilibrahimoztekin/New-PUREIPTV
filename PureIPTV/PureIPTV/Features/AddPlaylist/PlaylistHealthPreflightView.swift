import SwiftUI

public struct PlaylistHealthPreflightView: View {
    let report: PlaylistHealthReport?
    let isChecking: Bool
    let isEnabled: Bool
    let onCheck: () -> Void

    public init(
        report: PlaylistHealthReport?,
        isChecking: Bool,
        isEnabled: Bool,
        onCheck: @escaping () -> Void
    ) {
        self.report = report
        self.isChecking = isChecking
        self.isEnabled = isEnabled
        self.onCheck = onCheck
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard isEnabled, !isChecking else { return }
                onCheck()
            } label: {
                Label(AppStrings.PlaylistMgmt.healthCheck, systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            #if !os(tvOS)
                .disabled(!isEnabled || isChecking)
            #else
                .disabled(!isEnabled)
                .opacity(isEnabled && !isChecking ? 1 : 0.55)
                .accessibilityValue(isChecking ? AppStrings.Common.loading : "")
            #endif
                .accessibilityHint(AppStrings.PlaylistMgmt.healthCheckDescription)

            if isChecking {
                ProgressView(AppStrings.PlaylistMgmt.healthCheckProgress)
                    .accessibilityLabel(AppStrings.PlaylistMgmt.healthCheckProgress)
            }

            if let report {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.PlaylistMgmt.healthReportTitle)
                        .font(.headline)
                    ForEach(report.checks) { check in
                        let title = checkTitle(check.kind)
                        let status = statusTitle(check.status)
                        let detail = statusDetail(check.status)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: statusSymbol(check.status))
                                .foregroundStyle(statusColor(check.status))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.subheadline.weight(.medium))
                                Text(status)
                                    .font(.footnote)
                                    .foregroundStyle(statusColor(check.status))
                                if let detail {
                                    Text(detail)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(title). \(status). \(detail ?? "")")
                    }
                    Text(report.checkedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }

            Text(AppStrings.PlaylistMgmt.healthCheckDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
    }

    private func checkTitle(_ kind: PlaylistHealthCheckKind) -> String {
        switch kind {
        case .connection: AppStrings.PlaylistMgmt.healthConnection
        case .authentication: AppStrings.PlaylistMgmt.healthAuthentication
        case .format: AppStrings.PlaylistMgmt.healthFormat
        case .parsing: AppStrings.PlaylistMgmt.healthParsing
        case .epg: AppStrings.PlaylistMgmt.healthEPG
        }
    }

    private func statusTitle(_ status: PlaylistHealthStatus) -> String {
        switch status {
        case .passed: AppStrings.PlaylistMgmt.healthPassed
        case .failed: AppStrings.PlaylistMgmt.healthFailed
        case .notChecked: AppStrings.PlaylistMgmt.healthNotChecked
        case .notConfigured: AppStrings.PlaylistMgmt.healthNotConfigured
        case .notApplicable: AppStrings.PlaylistMgmt.healthNotApplicable
        }
    }

    private func statusDetail(_ status: PlaylistHealthStatus) -> String? {
        switch status {
        case let .failed(issue), let .notChecked(issue): AppStrings.PlaylistMgmt.healthIssueDescription(issue)
        case .passed, .notConfigured, .notApplicable: nil
        }
    }

    private func statusSymbol(_ status: PlaylistHealthStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .notChecked: "minus.circle.fill"
        case .notConfigured, .notApplicable: "info.circle"
        }
    }

    private func statusColor(_ status: PlaylistHealthStatus) -> Color {
        switch status {
        case .passed: .green
        case .failed: .red
        case .notChecked: .orange
        case .notConfigured, .notApplicable: .secondary
        }
    }
}
