import SwiftUI

/// Personal dictionary editor: add / edit / delete preferred spellings + "heard as" aliases.
struct DictionaryView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var newTerm = ""
    @State private var newAliases = ""
    @State private var editing: DictionaryEntry?
    @State private var editTerm = ""
    @State private var editAliases = ""
    @State private var filter = ""

    private var store: DictionaryStore { appState.dictionaryStore }

    private var filtered: [DictionaryEntry] {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.entries }
        return store.entries.filter { entry in
            entry.term.localizedCaseInsensitiveContains(q)
                || entry.aliases.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal dictionary")
                    .font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Names and jargon Bakbak should always spell your way. “Heard as” lists what the speech engine tends to write instead (comma-separated). Spacing/casing variants like “fluid audio” → “FluidAudio” match automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("Add") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Spelling (e.g. Devan, FluidAudio)", text: $newTerm)
                        .onSubmit(addEntry)
                    TextField("Heard as (optional, e.g. Devin, dev on)", text: $newAliases)
                        .onSubmit(addEntry)
                    HStack {
                        Spacer()
                        Button("Add", action: addEntry)
                            .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(4)
            }

            TextField("Filter", text: $filter)
                .textFieldStyle(.roundedBorder)

            if store.entries.isEmpty {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "character.book.closed",
                    description: Text("Add names, product names, and jargon you dictate often.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { entry in
                        row(entry)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { filtered[$0].id }
                        ids.forEach { store.remove(id: $0) }
                    }
                }
                .frame(minHeight: 180)
            }

            Text("\(store.entries.count) entr\(store.entries.count == 1 ? "y" : "ies") · stored locally in Application Support/Bakbak/dictionary.json")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 440, minHeight: 460)
        .sheet(item: $editing) { entry in
            editSheet(entry)
        }
    }

    @ViewBuilder
    private func row(_ entry: DictionaryEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.term)
                    .fontWeight(.medium)
                if !entry.aliases.isEmpty {
                    Text("heard as: " + entry.aliases.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                beginEdit(entry)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")
            Button(role: .destructive) {
                store.remove(id: entry.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .contextMenu {
            Button("Edit…") { beginEdit(entry) }
            Button("Delete", role: .destructive) { store.remove(id: entry.id) }
        }
    }

    private func editSheet(_ entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit entry").font(.headline)
            TextField("Spelling", text: $editTerm)
            TextField("Heard as (comma-separated)", text: $editAliases)
            HStack {
                Button("Delete", role: .destructive) {
                    store.remove(id: entry.id)
                    editing = nil
                }
                Spacer()
                Button("Cancel") { editing = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.update(
                        id: entry.id,
                        term: editTerm,
                        aliases: DictionaryEntry.parseAliases(editAliases)
                    )
                    editing = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding()
        .frame(minWidth: 380)
    }

    private func beginEdit(_ entry: DictionaryEntry) {
        editTerm = entry.term
        editAliases = entry.aliases.joined(separator: ", ")
        editing = entry
    }

    private func addEntry() {
        let term = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        store.add(term: term, aliases: DictionaryEntry.parseAliases(newAliases))
        newTerm = ""
        newAliases = ""
    }
}
