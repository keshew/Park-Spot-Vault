import SwiftUI

enum JournalPalette {
    static let pine = Color(red: 0.055, green: 0.106, blue: 0.090)
    static let moss = Color(red: 0.102, green: 0.166, blue: 0.137)
    static let spruce = Color(red: 0.157, green: 0.245, blue: 0.191)
    static let gold = Color(red: 0.976, green: 0.757, blue: 0.369)
    static let cream = Color(red: 0.973, green: 0.937, blue: 0.847)
    static let muted = Color(red: 0.686, green: 0.750, blue: 0.671)
    static let coral = Color(red: 1, green: 0.658, blue: 0.473)
}

struct JournalMark: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30)
                .fill(LinearGradient(colors: [.init(red: 1, green: 0.84, blue: 0.55), JournalPalette.gold],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "bird.fill")
                .font(.system(size: size * 0.50, weight: .semibold))
                .foregroundStyle(JournalPalette.pine)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct JournalCard: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(prominent ? JournalPalette.spruce : JournalPalette.moss)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.08))
                    .allowsHitTesting(false)
            }
    }
}

struct JournalView: View {
    let canOpenPage: Bool
    let openPage: () -> Void
    @StateObject private var store = JournalStore()
    @State private var tab = Tab.today
    @State private var editor: JournalEntry?
    @State private var filter: SupplyCategory?

    private enum Tab: Hashable { case today, supplies, shopping, flock }

    var body: some View {
        TabView(selection: $tab) {
            screen(title: "Golden Run", subtitle: "Your flock journal", symbol: nil) {
                overview
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(Tab.today)

            screen(title: "Supplies", subtitle: "Keep track of what is on hand", symbol: "plus") {
                supplies
            } action: {
                editor = .supply(BirdSupply(category: filter ?? .food))
            }
            .tabItem { Label("Supplies", systemImage: "shippingbox") }
            .tag(Tab.supplies)

            screen(title: "Shopping", subtitle: "Prepare your next restock", symbol: "plus") {
                shopping
            } action: {
                editor = .purchase(BirdPurchase())
            }
            .tabItem { Label("Shopping", systemImage: "cart") }
            .tag(Tab.shopping)

            screen(title: "Flock", subtitle: "Profiles and care routines", symbol: "plus") {
                flock
            } action: {
                editor = .bird(BirdProfile())
            }
            .tabItem { Label("Flock", systemImage: "bird") }
            .tag(Tab.flock)
        }
        .preferredColorScheme(.dark)
        .tint(JournalPalette.gold)
        .sheet(item: $editor) { entry in
            JournalEditor(entry: entry, store: store)
                .tint(JournalPalette.gold)
        }
        .alert("Golden Run", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("OK", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private func screen<Content: View>(
        title: String, subtitle: String, symbol: String?,
        @ViewBuilder content: () -> Content, action: @escaping () -> Void = {}
    ) -> some View {
        ZStack {
            JournalPalette.pine.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        if symbol == nil { JournalMark(size: 48) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                                .foregroundStyle(JournalPalette.cream)
                                .accessibilityAddTraits(.isHeader)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(JournalPalette.muted)
                        }
                        Spacer(minLength: 4)
                        if symbol == nil, canOpenPage {
                            Button(action: openPage) {
                                Image(systemName: "globe")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(JournalPalette.gold)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open online page")
                        } else if let symbol {
                            Button(action: action) {
                                Image(systemName: symbol)
                                    .font(.headline)
                                    .frame(width: 48, height: 48)
                                    .foregroundStyle(JournalPalette.pine)
                                    .background(JournalPalette.gold, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(addLabel(for: title))
                        }
                    }
                    content()
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func addLabel(for title: String) -> String {
        switch title {
        case "Supplies": "Add supply"
        case "Shopping": "Add purchase"
        default: "Add bird"
        }
    }

    private var overview: some View {
        let today = Date.now
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(JournalPalette.gold)
                Text("Flock overview")
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(JournalPalette.cream)
                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(JournalPalette.muted)
                if store.data.birds.isEmpty {
                    Button {
                        editor = .bird(BirdProfile())
                    } label: {
                        Label("Add your first bird", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(JournalPalette.pine)
                }
            }
            .modifier(JournalCard(prominent: true))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { shortcutCards }
                VStack(spacing: 10) { shortcutCards }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming care")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                if store.careByDate.isEmpty {
                    empty("Set a care reminder", systemImage: "calendar.badge.plus",
                          detail: "Schedule cage cleaning, supply checks or a feeding routine.") {
                        editor = .care(BirdCareTask())
                    }
                } else {
                    ForEach(Array(store.careByDate.prefix(3))) { task in
                        careRow(task)
                    }
                }
            }
        }
    }

    private var statusLine: String {
        if store.lowSupplies.isEmpty && store.openPurchases.isEmpty {
            return "Track food, supplies and the next care routine in one place."
        }
        let low = store.lowSupplies.count.formatted()
        let shopping = store.openPurchases.count.formatted()
        return "\(low) low in stock · \(shopping) to buy"
    }

    @ViewBuilder
    private var shortcutCards: some View {
        quickLink("Low stock", count: store.lowSupplies.count, icon: "shippingbox", tab: .supplies)
        quickLink("To buy", count: store.openPurchases.count, icon: "cart", tab: .shopping)
    }

    private func quickLink(_ title: String, count: Int, icon: String, tab: Tab) -> some View {
        Button {
            self.tab = tab
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(JournalPalette.gold)
                    .accessibilityHidden(true)
                Text(count, format: .number)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(JournalPalette.cream)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(JournalPalette.muted)
            }
            .fixedSize(horizontal: true, vertical: false)
            .modifier(JournalCard())
        }
        .buttonStyle(.plain)
    }

    private var supplies: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip("All", value: nil)
                    ForEach(SupplyCategory.allCases) { category in
                        categoryChip(category.rawValue, value: category)
                    }
                }
            }
            let items = store.data.supplies.filter { filter == nil || $0.category == filter }
            if items.isEmpty {
                empty("Add a supply", systemImage: "shippingbox",
                      detail: "Set a quantity and a low-stock threshold for food or supplies.") {
                    editor = .supply(BirdSupply(category: filter ?? .food))
                }
            } else {
                ForEach(items) { supply in
                    supplyRow(supply)
                }
            }
        }
    }

    private func categoryChip(_ name: String, value: SupplyCategory?) -> some View {
        Button {
            filter = value
        } label: {
            Text(name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(filter == value ? JournalPalette.pine : JournalPalette.cream)
                .background(filter == value ? JournalPalette.gold : JournalPalette.moss, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == value ? .isSelected : [])
    }

    private func supplyRow(_ supply: BirdSupply) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                JournalRowTitle(title: supply.name, detail: supply.category.rawValue, icon: supply.category.symbol)
                Spacer()
                Menu {
                    Button {
                        editor = .supply(supply)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        store.addToShopping([supply])
                    } label: {
                        Label("Add to shopping", systemImage: "cart.badge.plus")
                    }
                    .disabled(store.data.purchases.contains { $0.supplyID == supply.id })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Options for \(supply.name)")
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(supply.quantity.formatted()) \(supply.unit)")
                        .font(.headline)
                    if supply.isLow {
                        Label("Low stock", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(JournalPalette.coral)
                    }
                }
                Spacer()
                Button {
                    store.adjust(supply, by: -1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 26, height: 28)
                }
                .disabled(supply.quantity == 0)
                .accessibilityLabel("Decrease \(supply.name)")
                Button {
                    store.adjust(supply, by: 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 26, height: 28)
                }
                .disabled(supply.quantity == 99_999)
                .accessibilityLabel("Increase \(supply.name)")
            }
            .buttonStyle(.bordered)
        }
        .modifier(JournalCard())
    }

    private var shopping: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.lowSupplies.isEmpty {
                Button {
                    store.addToShopping(store.lowSupplies)
                } label: {
                    Label("Add low-stock supplies", systemImage: "cart.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            if store.data.purchases.isEmpty {
                empty("Add a purchase", systemImage: "cart",
                      detail: "Make a list for your next trip or share it with someone who shops for the flock.") {
                    editor = .purchase(BirdPurchase())
                }
            } else {
                ForEach(store.data.purchases) { purchase in
                    HStack(spacing: 12) {
                        Button {
                            var updated = purchase
                            updated.checked.toggle()
                            store.save(updated, in: \.purchases)
                        } label: {
                            Image(systemName: purchase.checked ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(JournalPalette.gold)
                        .accessibilityLabel(purchase.checked ? "Uncheck \(purchase.name)" : "Check \(purchase.name)")
                        Button {
                            editor = .purchase(purchase)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(purchase.name)
                                        .font(.headline)
                                        .strikethrough(purchase.checked)
                                    Text(purchase.amount)
                                        .font(.subheadline)
                                        .foregroundStyle(JournalPalette.muted)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(JournalPalette.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .modifier(JournalCard())
                }
                if store.data.purchases.contains(where: \.checked) {
                    Button {
                        store.putAwayChecked()
                    } label: {
                        Label("Put away checked items", systemImage: "shippingbox.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(JournalPalette.pine)
                }
                if !store.openPurchases.isEmpty {
                    ShareLink(item: shoppingText) {
                        Label("Share shopping list", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var shoppingText: String {
        (["Golden Run · Shopping"] + store.openPurchases.map { "• \($0.name) · \($0.amount)" })
            .joined(separator: "\n")
    }

    private var flock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.data.birds.isEmpty {
                empty("Add a bird", systemImage: "bird",
                      detail: "Keep a profile for each bird with its species and care notes.") {
                    editor = .bird(BirdProfile())
                }
            } else {
                ForEach(store.data.birds) { bird in
                    Button {
                        editor = .bird(bird)
                    } label: {
                        HStack {
                            JournalRowTitle(title: bird.name, detail: bird.species, icon: "bird.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(JournalPalette.muted)
                        }
                        .modifier(JournalCard())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Care schedule")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    editor = .care(BirdCareTask())
                } label: {
                    Label("Add care", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)

            if store.careByDate.isEmpty {
                Text("Care routines and reminders will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(JournalPalette.muted)
            }
            ForEach(store.careByDate) { task in
                careRow(task)
            }
        }
    }

    private func careRow(_ task: BirdCareTask) -> some View {
        let due = task.due.formatted(date: .abbreviated, time: .shortened)
        let detail = [store.birdName(for: task.birdID), due, task.recurrence == .never ? nil : task.recurrence.rawValue]
            .compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 8) {
            Button {
                editor = .care(task)
            } label: {
                JournalRowTitle(title: task.title, detail: detail,
                                icon: task.due < .now ? "clock.badge.exclamationmark" : "calendar")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                store.finishCare(task)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(JournalPalette.gold)
            .accessibilityLabel("Complete \(task.title)")
        }
        .modifier(JournalCard())
    }

    private func empty(_ title: String, systemImage: String, detail: String,
                       action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(JournalPalette.gold)
                .accessibilityHidden(true)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(JournalPalette.muted)
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
        .modifier(JournalCard())
    }
}

private struct JournalRowTitle: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(JournalPalette.gold)
                .background(JournalPalette.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(JournalPalette.cream)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(JournalPalette.muted)
                }
            }
        }
    }
}
