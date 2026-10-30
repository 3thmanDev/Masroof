import SwiftUI

struct ExpenseLogCard: View {
    @EnvironmentObject private var store: BudgetStore

    private struct DayGroup: Identifiable {
        let day: String
        var items: [Expense]
        var id: String { day }
        var total: Double { items.reduce(0) { $0 + $1.amount } }
    }

    private var groups: [DayGroup] {
        let sorted = store.state.expenses.sorted { a, b in
            a.day != b.day ? a.day > b.day : a.at > b.at
        }
        var result: [DayGroup] = []
        for expense in sorted.prefix(120) {
            if result.last?.day == expense.day {
                result[result.count - 1].items.append(expense)
            } else {
                result.append(DayGroup(day: expense.day, items: [expense]))
            }
        }
        return result
    }

    var body: some View {
        let state = store.state
        let counted = state.expenses.filter { $0.at > state.balanceAt }.reduce(0) { $0 + $1.amount }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("مصاريفك")
                    .font(.cairo(20, .bold))
                Spacer(minLength: 8)
                if counted > 0 {
                    riyalText("المجموع \(Money.text(counted)) ¤", size: 13)
                        .font(.cairo(13))
                        .foregroundColor(Theme.secondary)
                }
            }

            if groups.isEmpty {
                Text("ما سجلت مصاريف للحين. أول ما تصرف شي، سجّله فوق ويتعدّل حدّك.")
                    .font(.cairo(14))
                    .foregroundColor(Theme.secondary)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text(DateText.dayHeading(group.day, today: store.today))
                                .font(.cairo(13.5, .semibold))
                                .foregroundColor(Theme.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 6)
                            riyalText("\(Money.text(group.total)) ¤", size: 13.5)
                                .font(.cairo(13.5, .semibold))
                                .foregroundColor(Theme.secondary)
                        }
                        .padding(.bottom, 2)
                        ForEach(group.items) { expense in
                            ExpenseRow(expense: expense, alreadyInBalance: expense.at <= state.balanceAt) {
                                store.deleteExpense(expense)
                            }
                            if expense.id != group.items.last?.id {
                                Rectangle().fill(Theme.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .card()
    }
}

struct ExpenseRow: View {
    let expense: Expense
    /// Written down before the balance was last typed in, so it is already part of that balance.
    let alreadyInBalance: Bool
    let onDelete: () -> Void
    @State private var expanded = false

    private var items: [BasketItem] { expense.items ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    if !items.isEmpty { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(expense.note.isEmpty ? "مصروف" : expense.note)
                            .font(.cairo(16))
                            .foregroundColor(alreadyInBalance ? Theme.secondary : Theme.ink)
                            .lineLimit(1)
                        if !items.isEmpty {
                            Tag(text: Basket.countText(items.reduce(0) { $0 + $1.quantity }))
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.secondary)
                        }
                        if expense.kind == .bill { Tag(text: "التزام") }
                        if alreadyInBalance { Tag(text: "قبل تحديث المبلغ") }
                        Spacer(minLength: 6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(Money.text(expense.amount))
                    .font(.cairo(16, .bold))
                    .foregroundColor(alreadyInBalance ? Theme.secondary : Theme.ink)
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.field))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("احذف \(expense.note.isEmpty ? "المصروف" : expense.note) \(Money.text(expense.amount))")
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(item.quantity)×")
                                .font(.cairo(13.5, .semibold))
                                .foregroundColor(Theme.secondary)
                                .frame(minWidth: 26, alignment: .leading)
                            Text(item.name)
                                .font(.cairo(14))
                                .lineLimit(2)
                            Spacer(minLength: 6)
                            Text(Money.text(item.total))
                                .font(.cairo(14, .semibold))
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
                .padding(.bottom, 4)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: expanded)
    }
}
