import SwiftUI

enum JournalEntry: Identifiable {
    case supply(BirdSupply)
    case purchase(BirdPurchase)
    case bird(BirdProfile)
    case care(BirdCareTask)

    var id: UUID {
        switch self {
        case .supply(let draft): draft.id
        case .purchase(let draft): draft.id
        case .bird(let draft): draft.id
        case .care(let draft): draft.id
        }
    }
}

struct JournalEditor: View {
    let entry: JournalEntry
    @ObservedObject var store: JournalStore

    var body: some View {
        switch entry {
        case .supply(let supply):
            form("Supply", draft: supply, exists: store.data.supplies.contains { $0.id == supply.id },
                 name: \.name, save: { store.saveSupply($0) },
                 delete: { store.deleteSupply(supply) }) { draft in
                Section {
                    TextField("Name", text: draft.name)
                    Picker("Category", selection: draft.category) {
                        ForEach(SupplyCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.symbol).tag(category)
                        }
                    }
                    TextField("Unit (bags, boxes, kg)", text: draft.unit)
                }
                Section("Inventory") {
                    quantityField("On hand", value: draft.quantity)
                    quantityField("Low at or below", value: draft.lowAt)
                }
            }

        case .purchase(let purchase):
            form("Purchase", draft: purchase, exists: store.data.purchases.contains { $0.id == purchase.id },
                 name: \.name, save: { store.savePurchase($0) },
                 delete: { store.delete(purchase, from: \.purchases) }) { draft in
                Section {
                    TextField("Item", text: draft.name)
                    quantityField("Quantity", value: draft.quantity)
                    TextField("Unit (optional)", text: draft.unit)
                        .disabled(purchase.supplyID != nil)
                }
            }

        case .bird(let bird):
            form("Bird", draft: bird, exists: store.data.birds.contains { $0.id == bird.id },
                 name: \.name, save: { store.save($0, in: \.birds) },
                 delete: { store.deleteBird(bird) }) { draft in
                Section {
                    TextField("Name", text: draft.name)
                    TextField("Species or breed", text: draft.species)
                }
                Section("Care notes") {
                    TextField("Diet, preferences or routine", text: draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }

        case .care(let task):
            form("Care entry", draft: task, exists: store.data.care.contains { $0.id == task.id },
                 name: \.title, save: { store.saveCare($0) },
                 delete: { store.deleteCare(task) }) { draft in
                Section {
                    TextField("Routine", text: draft.title)
                    Picker("Bird", selection: draft.birdID) {
                        Text("Whole flock").tag(UUID?.none)
                        ForEach(store.data.birds) { bird in
                            Text(bird.name).tag(Optional(bird.id))
                        }
                    }
                }
                Section("Schedule") {
                    DatePicker("Due", selection: draft.due)
                    Picker("Repeat", selection: draft.recurrence) {
                        ForEach(CareRepeat.allCases) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                    Toggle("Send a reminder", isOn: draft.reminds)
                }
            }
        }
    }

    private func form<Model, Fields: View>(
        _ title: String, draft: Model, exists: Bool,
        name: WritableKeyPath<Model, String>,
        save: @escaping (Model) -> Bool, delete: @escaping () -> Bool,
        @ViewBuilder fields: @escaping (Binding<Model>) -> Fields
    ) -> some View {
        EntryForm(title: exists ? title : "New " + title.lowercased(),
                  draft: draft, name: name, save: save, delete: exists ? delete : nil, fields: fields)
    }

    private func quantityField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.grouping(.never))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(minWidth: 48, idealWidth: 80, maxWidth: 100)
        }
    }
}

private struct EntryForm<Draft, Fields: View>: View {
    let title: String
    @State var draft: Draft
    let name: WritableKeyPath<Draft, String>
    let save: (Draft) -> Bool
    let delete: (() -> Bool)?
    @ViewBuilder let fields: (Binding<Draft>) -> Fields

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                fields($draft)
                if delete != nil {
                    Button("Delete entry", role: .destructive) {
                        confirmsDeletion = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(JournalPalette.pine)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft[keyPath: name] = cleanName
                        if save(draft) { dismiss() }
                    }
                    .disabled(cleanName.isEmpty)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if delete?() == true { dismiss() }
                }
            }
        }
    }

    private var cleanName: String {
        draft[keyPath: name].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
