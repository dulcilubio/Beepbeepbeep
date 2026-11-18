import SwiftUI

struct SelectCompetitionView: View {
    @EnvironmentObject var liveresultat: LiveResultatManager
    @EnvironmentObject var eventor: EventorManager
    @Environment(\.dismiss) private var dismiss
    @State private var showLiveresultat = false
    @State private var showEventor = false

    /// What is currently loaded, if anything — shown so the user can confirm
    /// their pick before leaving this screen.
    private struct Selection {
        let sourceID: String
        let sourceName: String
        let competition: String
        let className: String
        let runners: Int
    }

    private var selection: Selection? {
        if liveresultat.hasActiveCompetition {
            return Selection(
                sourceID: "liveresultat",
                sourceName: "Liveresultat",
                competition: liveresultat.savedCompName,
                className: liveresultat.classFilterLabel,
                runners: liveresultat.startEntries.count
            )
        }
        if let list = eventor.importedList {
            return Selection(
                sourceID: "eventor",
                sourceName: "Eventor",
                competition: list.name,
                className: eventor.classFilterLabel,
                runners: eventor.filteredEntries.count
            )
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                if let sel = selection {
                    Section("Selected") {
                        LabeledContent("Competition", value: sel.competition)
                        LabeledContent("Class",       value: sel.className)
                        LabeledContent("Runners",     value: "\(sel.runners)")
                        LabeledContent("Source",      value: sel.sourceName)
                    }
                }

                Section {
                    sourceButton(
                        title: "Liveresultat",
                        systemImage: "wifi",
                        isActive: selection?.sourceID == "liveresultat"
                    ) { showLiveresultat = true }

                    sourceButton(
                        title: "Eventor",
                        systemImage: "globe",
                        isActive: selection?.sourceID == "eventor"
                    ) { showEventor = true }
                } header: {
                    Text(selection == nil ? "Source" : "Change source")
                } footer: {
                    Text("Live start list from liveresultat.orientering.se, or offline from eventor.se.")
                }

                if selection != nil {
                    Section {
                        Button("Remove start list", role: .destructive) {
                            liveresultat.clearSelection()
                            eventor.clearList()
                        }
                    }
                }

                Section("Coming soon") {
                    Label("IOF XML", systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                    Label("OLA", systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                    Label("MeOS", systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Select competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel only makes sense while nothing is loaded — once a list is
                // selected it has already been applied, so the exit is "OK".
                if selection == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showLiveresultat) {
                CompetitionPickerView()
            }
            .sheet(isPresented: $showEventor) {
                EventorImportView()
            }
        }
    }

    @ViewBuilder
    private func sourceButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
