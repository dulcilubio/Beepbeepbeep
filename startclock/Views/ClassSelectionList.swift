import SwiftUI

/// Multi-select list of class names, shared by the Liveresultat picker and the
/// Eventor settings row. An empty selection means "all classes" — that is the
/// default, and tapping the "All classes" row returns to it.
struct ClassSelectionList: View {
    let classes: [String]
    @Binding var selection: Set<String>

    var body: some View {
        List {
            Section {
                row(label: "All classes", systemImage: "list.bullet", isSelected: selection.isEmpty) {
                    selection.removeAll()
                }
            } footer: {
                Text(summary)
            }

            if !classes.isEmpty {
                Section("Filter by class") {
                    ForEach(classes, id: \.self) { cls in
                        row(label: cls, systemImage: nil, isSelected: selection.contains(cls)) {
                            toggle(cls)
                        }
                    }
                }
            }
        }
    }

    private var summary: String {
        switch selection.count {
        case 0:  return "All classes are shown. Pick one or more to narrow it down."
        case 1:  return "1 class selected."
        default: return "\(selection.count) classes selected."
        }
    }

    private func toggle(_ cls: String) {
        if selection.contains(cls) {
            selection.remove(cls)
        } else {
            selection.insert(cls)
        }
    }

    @ViewBuilder
    private func row(
        label: String,
        systemImage: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Label(label, systemImage: systemImage)
                } else {
                    Text(label)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}
