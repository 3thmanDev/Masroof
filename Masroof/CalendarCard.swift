import SwiftUI

/// Every day from when the money was typed in to the last day: what was spent, what is left today,
/// and the limit ahead. Weeks start on Sunday, as on a Saudi calendar.
struct CalendarCard: View {
    @EnvironmentObject private var store: BudgetStore

    private let weekdays = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let m = store.summary
        let plan = CalendarPlan(state: store.state, today: store.today, summary: m)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("أيامك لين آخر الفترة")
                    .font(.cairo(20, .bold))
                Spacer(minLength: 8)
                Text(m.ended ? "الفترة خلصت" : "باقي \(DateText.days(m.daysLeft))")
                    .font(.cairo(13))
                    .foregroundColor(Theme.secondary)
            }
            Text(plan.monthsLine)
                .font(.cairo(13))
                .foregroundColor(Theme.secondary)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { name in
                    Text(name)
                        .font(.cairo(11))
                        .foregroundColor(Theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(plan.slots) { slot in
                    if let cell = slot.cell {
                        DayCell(cell: cell)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            if plan.hiddenDays > 0 {
                Text("وفيه \(DateText.days(plan.hiddenDays)) قبلها ما تنعرض هنا.")
                    .font(.cairo(12.5))
                    .foregroundColor(Theme.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 14) {
                    LegendItem(text: "صرفته", fill: .clear, stroke: Theme.line)
                    LegendItem(text: "باقي اليوم", fill: Theme.accent)
                    LegendItem(text: "حدّك المتوقع", fill: Theme.accentSoft)
                }
                HStack(spacing: 14) {
                    LegendItem(text: "فوق الحد", fill: Theme.badSoft)
                    LegendItem(text: "آخر يوم", fill: .clear, stroke: Theme.accent, strokeWidth: 2)
                }
                Text("الرقم الصغير جنب اليوم: التاريخ الهجري")
                    .font(.cairo(12.5))
                    .foregroundColor(Theme.secondary)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .card()
    }
}

struct CalendarPlan {
    struct Cell {
        enum Kind { case past, today, future }
        let day: String
        let date: Date
        let kind: Kind
        let value: String
        let over: Bool
        let isLast: Bool
        let gregorianMonth: String?
        let hijriMonth: String?
        let hijriDay: Int
    }

    struct Slot: Identifiable {
        let id: String
        let cell: Cell?
    }

    var slots: [Slot] = []
    var hiddenDays = 0
    var monthsLine = ""

    private static let maxDays = 70

    init(state: BudgetState, today: String, summary m: BudgetMath.Summary) {
        let end = state.endDate
        var start = Days.key(state.balanceAt)
        if start > today { start = today }
        if start > end { start = end }
        let span = Days.between(start, end) + 1
        if span > Self.maxDays {
            hiddenDays = span - Self.maxDays
            start = Days.adding(-(Self.maxDays - 1), to: end)
        }
        monthsLine = DateText.span(from: Days.date(start), to: Days.date(end), hijri: false)
            + " · " + DateText.span(from: Days.date(start), to: Days.date(end), hijri: true)

        var spentByDay: [String: Double] = [:]
        for expense in state.expenses where expense.kind == .daily {
            spentByDay[expense.day, default: 0] += expense.amount
        }

        for index in 0..<Days.weekday(start) {
            slots.append(Slot(id: "pad-\(index)", cell: nil))
        }
        var day = start
        var isFirst = true
        while day <= end {
            let date = Days.date(day)
            let kind: Cell.Kind
            let value: String
            var over = false
            if day < today {
                kind = .past
                let spent = spentByDay[day] ?? 0
                over = m.allowance > 0 && spent > m.allowance
                value = Money.text(spent)
            } else if day == today {
                kind = .today
                over = m.spentToday > m.allowance
                value = m.ended ? "" : Money.whole(m.leftToday)
            } else {
                kind = .future
                value = Money.whole(m.futureDaily)
            }
            let hijriDay = DateText.hijriDay(date)
            let gregorianDay = Days.parts(day).day
            let cell = Cell(
                day: day, date: date, kind: kind, value: value, over: over, isLast: day == end,
                gregorianMonth: isFirst || gregorianDay == 1 ? DateText.gregorianMonth(date) : nil,
                hijriMonth: hijriDay == 1 ? DateText.hijriMonth(date) : nil,
                hijriDay: hijriDay
            )
            slots.append(Slot(id: day, cell: cell))
            isFirst = false
            day = Days.adding(1, to: day)
        }
    }
}

struct DayCell: View {
    let cell: CalendarPlan.Cell

    private var isToday: Bool { cell.kind == .today }

    private var background: Color {
        switch cell.kind {
        case .past: return cell.over ? Theme.badSoft : .clear
        case .today: return cell.over ? Theme.bad : Theme.accent
        case .future: return Theme.accentSoft
        }
    }

    private var valueColor: Color {
        switch cell.kind {
        case .past: return cell.over ? Theme.bad : Theme.ink
        case .today: return .white
        case .future: return Theme.accent
        }
    }

    private var border: Color {
        if cell.isLast { return isToday ? .white : Theme.accent }
        return cell.kind == .past && !cell.over ? Theme.line : .clear
    }

    var body: some View {
        VStack(spacing: 0) {
            if let month = cell.gregorianMonth {
                Text(month)
                    .font(.cairo(9.5))
                    .foregroundColor(isToday ? .white : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let month = cell.hijriMonth {
                Text(month)
                    .font(.cairo(9.5, .semibold))
                    .foregroundColor(isToday ? .white : Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Days.parts(cell.day).day)")
                    .font(.cairo(14, .bold))
                    .foregroundColor(isToday ? .white : Theme.ink)
                Text("\(cell.hijriDay)")
                    .font(.cairo(9.5))
                    .foregroundColor(isToday ? Color.white.opacity(0.85) : Theme.secondary)
            }
            if !cell.value.isEmpty {
                Text(cell.value)
                    .font(.cairo(11, .semibold))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(background))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(border, lineWidth: cell.isLast ? 2 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DateText.long(cell.date))، \(DateText.hijriFull(cell.date))، \(cell.value) ريال")
    }
}

struct LegendItem: View {
    let text: String
    let fill: Color
    var stroke: Color = .clear
    var strokeWidth: CGFloat = 1

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(stroke, lineWidth: strokeWidth))
                .frame(width: 13, height: 13)
            Text(text)
                .font(.cairo(12.5))
                .foregroundColor(Theme.secondary)
                .lineLimit(1)
        }
    }
}
