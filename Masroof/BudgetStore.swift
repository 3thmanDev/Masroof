import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    /// The state to go back to when "تراجع" is tapped.
    let undo: BudgetState?
}

/// The budget and everything written in it, kept on the phone only.
@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var state: BudgetState
    @Published private(set) var today: String
    @Published var toast: Toast?

    private static let storageKey = "budgetState.v1"
    private var toastTask: Task<Void, Never>?

    init() {
        let today = Days.today()
        self.today = today
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(BudgetState.self, from: data) {
            state = saved
        } else {
            state = .example(today: today)
        }
    }

    var summary: BudgetMath.Summary { BudgetMath.summary(state, today: today) }
    var status: BudgetMath.Status { BudgetMath.status(state, summary) }

    /// A new day changes every number, so this runs on a timer and when the app comes back.
    func refreshDay() {
        let now = Days.today()
        if now != today { today = now }
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
        show("انضاف: \(note.isEmpty ? "مصروف" : note) \(Money.text(amount)) ¤", undo: undo)
    }

    func deleteExpense(_ expense: Expense) {
        let undo = state
        change(keepExample: true) { s in s.expenses.removeAll { $0.id == expense.id } }
        show("انحذف: \(expense.note.isEmpty ? "مصروف" : expense.note) \(Money.text(expense.amount))", undo: undo)
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
        show("سجلت \(bill.name) كمدفوع", undo: undo)
    }

    func deleteBill(_ bill: Bill) {
        let undo = state
        change(keepExample: true) { s in s.bills.removeAll { $0.id == bill.id } }
        show("انحذف: \(bill.name)", undo: undo)
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
        show("انمسح كل شي.", undo: undo)
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

    private func show(_ message: String, undo: BudgetState?) {
        toast = Toast(message: message, undo: undo)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
