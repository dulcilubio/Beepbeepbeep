import SwiftUI

struct CompetitionPickerView: View {
    @EnvironmentObject var liveresultat: LiveResultatManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCompetition: Competition?

    var body: some View {
        NavigationStack {
            Group {
                if liveresultat.isLoadingCompetitions {
                    ProgressView("Loading competitions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = liveresultat.error, liveresultat.competitions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Failed to load")
                            .font(.headline)
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await liveresultat.fetchCompetitions() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredCompetitions) { comp in
                        Button {
                            selectedCompetition = comp
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comp.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        if let date = comp.date {
                                            Text(date)
                                        }
                                        if let org = comp.organizer, !org.isEmpty {
                                            Text("·")
                                            Text(org)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if comp.id == liveresultat.savedCompId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search competition or organiser")
            .navigationTitle("Competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await liveresultat.fetchCompetitions() }
            .navigationDestination(isPresented: showsClassPicker) {
                if let comp = selectedCompetition {
                    ClassFilterPickerView(competition: comp) { classNames in
                        Task {
                            await liveresultat.selectCompetition(
                                id: comp.id,
                                name: comp.name,
                                classNames: classNames
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    /// `navigationDestination(item:)` needs iOS 17, so the selection drives an
    /// isPresented binding instead.
    private var showsClassPicker: Binding<Bool> {
        Binding(
            get: { selectedCompetition != nil },
            set: { if !$0 { selectedCompetition = nil } }
        )
    }

    private var filteredCompetitions: [Competition] {
        guard !searchText.isEmpty else { return liveresultat.competitions }
        let q = searchText.lowercased()
        return liveresultat.competitions.filter {
            $0.name.lowercased().contains(q) ||
            ($0.organizer?.lowercased().contains(q) ?? false)
        }
    }
}

/// Lets the user pick any number of classes for the selected competition.
/// An empty selection means all classes.
struct ClassFilterPickerView: View {
    let competition: Competition
    let onDone: (Set<String>) -> Void   // empty = all classes

    @EnvironmentObject var liveresultat: LiveResultatManager
    @State private var selection: Set<String> = []
    @State private var didPrefill = false

    var body: some View {
        Group {
            if liveresultat.isLoadingClasses && liveresultat.classes.isEmpty {
                ProgressView("Loading classes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ClassSelectionList(
                    classes: liveresultat.classes.map(\.className),
                    selection: $selection
                )
            }
        }
        .navigationTitle(competition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone(selection) }
                    .fontWeight(.semibold)
            }
        }
        .task {
            // Re-entering the loaded competition starts from its saved selection.
            if !didPrefill {
                didPrefill = true
                if liveresultat.savedCompId == competition.id {
                    selection = liveresultat.savedClassNames
                }
            }
            await liveresultat.fetchClasses(for: competition.id)
        }
    }
}
