import SwiftUI

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    /// Puts things back as they were when "تراجع" is tapped.
    let undo: (() -> Void)?
}

/// The budget and everything written in it, kept on the phone only.
@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var state: BudgetState
    @Published private(set) var today: String
    @Published private(set) var basket: Basket
    @Published private(set) var reminder: ReminderSettings
    /// The reminder is on here but notifications are switched off for the app in Settings.
    @Published private(set) var remindersBlocked = false
    @Published var toast: Toast?

    private var products: [String: Product]

    private static let storageKey = "budgetState.v1"
    private static let basketKey = "basket.v1"
    private static let productsKey = "products.v1"
    private static let reminderKey = "reminder.v1"
    private var toastTask: Task<Void, Never>?
    private var reminderTask: Task<Void, Never>?
    private var askedForNotifications = false

    init() {
        let today = Days.today()
        self.today = today
        state = Self.load(Self.storageKey) ?? .example(today: today)
        basket = Self.load(Self.basketKey) ?? Basket()
        products = Self.load(Self.productsKey) ?? [:]
        reminder = Self.load(Self.reminderKey) ?? ReminderSettings()
    }

    var summary: BudgetMath.Summary { BudgetMath.summary(state, today: today) }
    var status: BudgetMath.Status { BudgetMath.status(state, summary) }

    /// A new day changes every number, so this runs on a timer and when the app comes back.
    func refreshDay() {
        let now = Days.today()
        if now != today {
            today = now
            scheduleReminders()
        }
    }

    // MARK: Money and period

    func setBalance(_ amount: Double) {
        change { s in
            s.balance = amount
            s.balanceAt = Date()
        }
    }

    func setSavings(_ amount: Double) {
        change { s in s.savings = amount }
    }

    func choose(_ mode: EndMode) {
        let day = today
        change(keepExample: true) { s in
            s.endMode = mode
            s.endDate = BudgetMath.endDate(for: mode, salaryDay: s.salaryDay, from: day)
        }
    }

    func setEndDate(_ day: String) {
        guard day >= today, day != state.endDate else { return }
        change(keepExample: true) { s in
            s.endDate = day
            s.endMode = .custom
        }
    }

    func setSalaryDay(_ value: Int) {
        let salaryDay = min(31, max(1, value))
        let day = today
        change(keepExample: true) { s in
            s.salaryDay = salaryDay
            if s.endMode == .salary {
                s.endDate = BudgetMath.endDate(for: .salary, salaryDay: salaryDay, from: day)
            }
        }
    }

    // MARK: Spending

    func addExpense(amount: Double, note: String, day: String) {
        let undo = state.isExample ? nil : state
        let spentOn = min(day, today)
        change { s in
            s.expenses.append(Expense(amount: amount, note: note, day: spentOn, at: Date()))
        }
        show("انضاف: \(note.isEmpty ? "مصروف" : note) \(Money.text(amount)) ¤", restoring: undo)
    }

    func deleteExpense(_ expense: Expense) {
        let undo = state
        change(keepExample: true) { s in s.expenses.removeAll { $0.id == expense.id } }
        show("انحذف: \(expense.note.isEmpty ? "مصروف" : expense.note) \(Money.text(expense.amount))", restoring: undo)
    }

    // MARK: Bills

    func addBill(name: String, amount: Double) {
        change { s in s.bills.append(Bill(name: name, amount: amount)) }
    }

    /// The bill stops being set aside and is written down as money spent today.
    func payBill(_ bill: Bill) {
        let undo = state
        let day = today
        change(keepExample: true) { s in
            s.bills.removeAll { $0.id == bill.id }
            s.expenses.append(Expense(amount: bill.amount, note: bill.name, day: day, at: Date(), kind: .bill))
        }
        show("سجلت \(bill.name) كمدفوع", restoring: undo)
    }

    func deleteBill(_ bill: Bill) {
        let undo = state
        change(keepExample: true) { s in s.bills.removeAll { $0.id == bill.id } }
        show("انحذف: \(bill.name)", restoring: undo)
    }

    // MARK: Basket

    func product(for barcode: String) -> Product? {
        products[barcode]
    }

    /// Adds to the basket and remembers the barcode's name and price for next time.
    @discardableResult
    func addToBasket(barcode: String?, name: String, price: Double, quantity: Int = 1) -> BasketItem {
        let label = Self.itemName(name)
        let item = basket.add(barcode: barcode, name: label, price: price, quantity: quantity)
        remember(item)
        saveBasket()
        return item
    }

    func updateBasketItem(_ item: BasketItem) {
        var edited = item
        edited.name = Self.itemName(item.name)
        basket.update(edited)
        remember(edited)
        saveBasket()
    }

    func setQuantity(_ quantity: Int, of item: BasketItem) {
        if quantity < 1 {
            removeFromBasket(item)
            return
        }
        basket.setQuantity(quantity, of: item.id)
        saveBasket()
    }

    func removeFromBasket(_ item: BasketItem) {
        let before = basket
        basket.remove(item.id)
        saveBasket()
        show("شلت \(item.name) من السلة", undo: { [weak self] in self?.putBack(before) })
    }

    func setBasketPlace(_ place: String) {
        basket.place = place
        saveBasket()
    }

    func emptyBasket() {
        let before = basket
        basket = Basket()
        saveBasket()
        show("فضّيت السلة", undo: { [weak self] in self?.putBack(before) })
    }

    /// The basket becomes one expense today, with every item kept in it.
    func checkoutBasket() {
        guard !basket.isEmpty else { return }
        let before = basket
        let place = basket.place.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(
            amount: basket.total,
            note: place.isEmpty ? "بقالة" : place,
            day: today,
            at: Date(),
            items: basket.items
        )
        change { s in s.expenses.append(expense) }
        basket = Basket()
        saveBasket()
        show("انضافت السلة: \(expense.note) \(Money.text(expense.amount)) ¤", undo: { [weak self] in
            guard let self else { return }
            self.state.expenses.removeAll { $0.id == expense.id }
            self.save()
            self.putBack(before)
        })
    }

    // MARK: Daily reminder

    func setReminder(_ settings: ReminderSettings) {
        reminder = settings
        Self.store(settings, Self.reminderKey)
        scheduleReminders()
    }

    /// Writes the coming days' notifications again; changes in quick succession are written once.
    func scheduleReminders() {
        reminderTask?.cancel()
        reminderTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            let settings = self.reminder
            var status = await ReminderScheduler.status()
            // iOS asks once, the first time there is a real budget to remind about.
            if settings.isOn, status == .notDetermined, !self.state.isExample, !self.askedForNotifications {
                self.askedForNotifications = true
                _ = await ReminderScheduler.requestAccess()
                status = await ReminderScheduler.status()
            }
            self.remindersBlocked = settings.isOn && status == .denied
            guard settings.isOn, ReminderScheduler.canNotify(status) else {
                ReminderScheduler.clear()
                return
            }
            let messages = ReminderPlan.messages(self.state, now: Date(), hour: settings.hour, minute: settings.minute)
            await ReminderScheduler.schedule(messages, hour: settings.hour, minute: settings.minute)
        }
    }

    // MARK: Starting over

    func startFresh() {
        state = .blank(today: today)
        save()
    }

    func resetAll() {
        let undo = state
        state = .blank(today: today)
        save()
        show("انمسح كل شي.", restoring: undo)
    }

    func restore(_ snapshot: BudgetState) {
        state = snapshot
        save()
        toast = nil
    }

    // MARK: Private

    /// Any real change ends the example, except picking a period, which only looks around.
    private func change(keepExample: Bool = false, _ edit: (inout BudgetState) -> Void) {
        if state.isExample && !keepExample { state.leaveExample() }
        edit(&state)
        save()
    }

    private func show(_ message: String, restoring snapshot: BudgetState?) {
        var undo: (() -> Void)?
        if let snapshot {
            undo = { [weak self] in self?.restore(snapshot) }
        }
        show(message, undo: undo)
    }

    private func show(_ message: String, undo: (() -> Void)?) {
        toast = Toast(message: message, undo: undo)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func putBack(_ saved: Basket) {
        basket = saved
        saveBasket()
        toast = nil
    }

    private func remember(_ item: BasketItem) {
        guard let barcode = item.barcode else { return }
        products[barcode] = Product(name: item.name, price: item.price)
        Self.store(products, Self.productsKey)
    }

    private static func itemName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "غرض" : trimmed
    }

    private func save() {
        Self.store(state, Self.storageKey)
        scheduleReminders()
    }

    private func saveBasket() {
        Self.store(basket, Self.basketKey)
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func store<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
