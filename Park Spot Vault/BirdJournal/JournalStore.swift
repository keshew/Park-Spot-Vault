import Foundation
import Combine

enum SupplyCategory: String, CaseIterable, Codable, Identifiable {
    case food = "Food"
    case treats = "Treats"
    case bedding = "Bedding"
    case care = "Care"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .food: "leaf.fill"
        case .treats: "sparkles"
        case .bedding: "square.stack.3d.down.right.fill"
        case .care: "drop.fill"
        }
    }
}

struct BirdSupply: Codable, Identifiable {
    var id = UUID()
    var name = ""
    var category: SupplyCategory = .food
    var quantity = 1
    var unit = "bags"
    var lowAt = 1

    var isLow: Bool { quantity <= lowAt }
}

struct BirdPurchase: Codable, Identifiable {
    var id = UUID()
    var name = ""
    var quantity = 1
    var unit = ""
    var checked = false
    var supplyID: UUID?

    var amount: String {
        [quantity.formatted(), unit].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct BirdProfile: Codable, Identifiable {
    var id = UUID()
    var name = ""
    var species = ""
    var notes = ""
}

enum CareRepeat: String, CaseIterable, Codable, Identifiable {
    case never = "Once"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: Self { self }

    func nextDate(after due: Date, now: Date, calendar: Calendar = .current) -> Date? {
        let coordinate: Calendar.Component
        switch self {
        case .never: return nil
        case .daily: coordinate = .day
        case .weekly: coordinate = .weekOfYear
        case .monthly: coordinate = .month
        }
        let elapsed = max(0, calendar.dateComponents([coordinate], from: due, to: now).value(for: coordinate) ?? 0)
        guard let candidate = calendar.date(byAdding: coordinate, value: max(1, elapsed), to: due) else { return nil }
        return candidate > now ? candidate : calendar.date(byAdding: coordinate, value: elapsed + 1, to: due)
    }
}

struct BirdCareTask: Codable, Identifiable {
    var id = UUID()
    var title = ""
    var birdID: UUID?
    var due = Date().addingTimeInterval(3_600)
    var recurrence: CareRepeat = .never
    var reminds = false
}

struct JournalSnapshot: Codable {
    var supplies: [BirdSupply] = []
    var purchases: [BirdPurchase] = []
    var birds: [BirdProfile] = []
    var care: [BirdCareTask] = []
}

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var data = JournalSnapshot()
    @Published var message: String?

    private let file: URL
    private var readFailed = false

    init(file: URL = URL.applicationSupportDirectory.appendingPathComponent("Golden Run/journal.json")) {
        self.file = file
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            data = try JSONDecoder().decode(JournalSnapshot.self, from: Data(contentsOf: file))
        } catch {
            readFailed = true
            message = "The journal could not be opened. Existing records are still stored on this device."
        }
    }

    var lowSupplies: [BirdSupply] { data.supplies.filter(\.isLow) }
    var openPurchases: [BirdPurchase] { data.purchases.filter { !$0.checked } }
    var careByDate: [BirdCareTask] { data.care.sorted { $0.due < $1.due } }

    func birdName(for id: UUID?) -> String? {
        data.birds.first { $0.id == id }?.name
    }

    @discardableResult
    func save<Model: Identifiable>(_ model: Model, in collection: WritableKeyPath<JournalSnapshot, [Model]>) -> Bool {
        commit { snapshot in
            if let index = snapshot[keyPath: collection].firstIndex(where: { $0.id == model.id }) {
                snapshot[keyPath: collection][index] = model
            } else {
                snapshot[keyPath: collection].append(model)
            }
        }
    }

    @discardableResult
    func delete<Model: Identifiable>(_ model: Model, from collection: WritableKeyPath<JournalSnapshot, [Model]>) -> Bool {
        commit { $0[keyPath: collection].removeAll { $0.id == model.id } }
    }

    func saveSupply(_ draft: BirdSupply) -> Bool {
        var supply = draft
        supply.quantity = min(99_999, max(0, supply.quantity))
        supply.lowAt = min(99_999, max(0, supply.lowAt))
        supply.unit = supply.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let previous = data.supplies.first(where: { $0.id == supply.id }),
              previous.unit != supply.unit else {
            return save(supply, in: \.supplies)
        }
        return commit { snapshot in
            guard let index = snapshot.supplies.firstIndex(where: { $0.id == supply.id }) else { return }
            snapshot.supplies[index] = supply
            for item in snapshot.purchases.indices where snapshot.purchases[item].supplyID == supply.id {
                snapshot.purchases[item].supplyID = nil
            }
        }
    }

    @discardableResult
    func deleteSupply(_ supply: BirdSupply) -> Bool {
        commit { snapshot in
            snapshot.supplies.removeAll { $0.id == supply.id }
            for item in snapshot.purchases.indices where snapshot.purchases[item].supplyID == supply.id {
                snapshot.purchases[item].supplyID = nil
            }
        }
    }

    func savePurchase(_ draft: BirdPurchase) -> Bool {
        var purchase = draft
        purchase.quantity = min(99_999, max(1, purchase.quantity))
        purchase.unit = purchase.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return save(purchase, in: \.purchases)
    }

    @discardableResult
    func adjust(_ supply: BirdSupply, by delta: Int) -> Bool {
        guard var current = data.supplies.first(where: { $0.id == supply.id }) else { return false }
        current.quantity = min(99_999, max(0, current.quantity + delta))
        return save(current, in: \.supplies)
    }

    func addToShopping(_ supplies: [BirdSupply]) {
        let queued = Set(data.purchases.compactMap(\.supplyID))
        let toAdd = supplies.filter { !queued.contains($0.id) }
        guard !toAdd.isEmpty else { return }
        commit { snapshot in
            for supply in toAdd {
                snapshot.purchases.append(BirdPurchase(
                    name: supply.name,
                    quantity: min(99_999, max(1, supply.lowAt * 2 - supply.quantity)),
                    unit: supply.unit,
                    supplyID: supply.id
                ))
            }
        }
    }

    func putAwayChecked() {
        commit { snapshot in
            for purchase in snapshot.purchases where purchase.checked {
                if let index = snapshot.supplies.firstIndex(where: { $0.id == purchase.supplyID }) {
                    snapshot.supplies[index].quantity = min(99_999, snapshot.supplies[index].quantity + purchase.quantity)
                }
            }
            snapshot.purchases.removeAll(where: \.checked)
        }
    }

    @discardableResult
    func saveCare(_ task: BirdCareTask) -> Bool {
        guard save(task, in: \.care) else { return false }
        Task { await synchronizeReminder(for: task.id) }
        return true
    }

    @discardableResult
    func deleteCare(_ task: BirdCareTask) -> Bool {
        guard delete(task, from: \.care) else { return false }
        BirdReminders.cancel(task.id)
        return true
    }

    func finishCare(_ task: BirdCareTask) {
        let now = Date()
        guard let next = task.recurrence.nextDate(after: task.due, now: now) else {
            deleteCare(task)
            return
        }
        var updated = task
        updated.due = next
        saveCare(updated)
    }

    @discardableResult
    func deleteBird(_ bird: BirdProfile) -> Bool {
        commit { snapshot in
            snapshot.birds.removeAll { $0.id == bird.id }
            for index in snapshot.care.indices where snapshot.care[index].birdID == bird.id {
                snapshot.care[index].birdID = nil
            }
        }
    }

    private func synchronizeReminder(for id: UUID) async {
        BirdReminders.cancel(id)
        guard let task = data.care.first(where: { $0.id == id }), task.reminds, task.due > Date() else { return }
        do {
            let allowed = try await BirdReminders.ensurePermission()
            guard let current = data.care.first(where: { $0.id == id }),
                  current.reminds, current.due > Date() else { return }
            guard allowed else {
                message = "Enable notifications for Golden Run in Settings to receive care alerts."
                return
            }
            try await BirdReminders.schedule(current)
        } catch {
            message = "The care entry was saved. The alert could not be scheduled."
        }
    }

    @discardableResult
    private func commit(_ update: (inout JournalSnapshot) -> Void) -> Bool {
        guard !readFailed else {
            message = "The saved journal could not be opened."
            return false
        }
        var next = data
        update(&next)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            data = next
            return true
        } catch {
            message = "The journal could not be saved. Check available storage and try again."
            return false
        }
    }
}
