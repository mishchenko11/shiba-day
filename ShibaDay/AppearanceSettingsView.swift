import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @Binding var selection: AppAppearance

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(AppAppearance.allCases.enumerated()), id: \.offset) { index, appearance in
                    appearanceRow(appearance)

                    if index < AppAppearance.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color("brandOrange").opacity(0.20), lineWidth: 1)
            }
            .shadow(color: Color("brandOrange").opacity(0.14), radius: 12, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("brandOrange"))
    }

    private func appearanceRow(_ appearance: AppAppearance) -> some View {
        Button {
            selection = appearance
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appearance.rawValue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(description(for: appearance))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selection == appearance {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color("brandOrange"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func description(for appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return "Follow your iPhone's appearance"
        case .light:
            return "Always use Light Mode"
        case .dark:
            return "Always use Dark Mode"
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView(selection: .constant(.system))
    }
}
