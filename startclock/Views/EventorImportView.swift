import SwiftUI

struct EventorImportView: View {
    @EnvironmentObject var eventor: EventorManager
    @Environment(\.dismiss) private var dismiss

    @State private var showBrowser = false
    @State private var urlText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showBrowser = true
                    } label: {
                        Label("Browse Eventor…", systemImage: "globe")
                    }
                    .disabled(eventor.isLoading)
                } footer: {
                    Text("Navigate to the competition on eventor.se and tap \u{201C}Select this competition\u{201D}.")
                }

                Section {
                    TextField("https://eventor.se/event/56028", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Import from URL") {
                        Task { await eventor.fetchAndParse(urlString: urlText) }
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || eventor.isLoading)
                } header: {
                    Text("Or paste URL")
                }

                if eventor.isLoading {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Fetching start list\u{2026}").foregroundStyle(.secondary)
                        }
                    }
                }

                if let err = eventor.error {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let list = eventor.importedList {
                    Section("Imported") {
                        LabeledContent("Competition", value: list.name)
                        LabeledContent("Entries", value: "\(list.entries.count)")

                        let classes = Dictionary(grouping: list.entries, by: \.className)
                        ForEach(classes.keys.sorted(), id: \.self) { cls in
                            LabeledContent(
                                cls.isEmpty ? "Unclassified" : cls,
                                value: "\(classes[cls]!.count)"
                            )
                        }
                    }

                    Section {
                        Button("Remove offline list", role: .destructive) {
                            eventor.clearList()
                        }
                    }
                }
            }
            .navigationTitle("Eventor start list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showBrowser) {
                EventorBrowserView { url, json in
                    Task { await eventor.importFromBrowser(url: url, json: json) }
                }
            }
            .onChange(of: eventor.importedList) { list in
                if list != nil { urlText = "" }
            }
        }
    }
}
