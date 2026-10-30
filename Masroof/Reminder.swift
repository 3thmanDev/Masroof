import Foundation

struct ReminderSettings: Codable, Equatable {
    var isOn = true
    var hour = 9
    var minute = 0
}

/// The words of the daily "how much can I spend" notification for each coming day.
/// A notification's text is fixed when it is scheduled, so every change to the money writes them again.
enum ReminderPlan {
    struct Message: Equatable {
        var day: String
        var title: String
        var body: String
    }

    /// Notifications show plain text, which can't draw the new riyal sign yet.
    private static let currency = "ريال"

    static func messages(_ s: BudgetState, now: Date, hour: Int, minute: Int, limit: Int = 30) -> [Message] {
        let today = Days.today(now)
        let m = BudgetMath.summary(s, today: today)
        let status = BudgetMath.status(s, m)
        if s.isExample || status == .empty || status == .ended { return [] }

        let end = Days.date(s.endDate)
        var day = now < fireDate(day: today, hour: hour, minute: minute) ? today : Days.adding(1, to: today)

        if case .short = status {
            return [Message(
                day: day,
                title: "مصروفك ما يكفي",
                body: "اللي معك ما يغطي المحجوز لين \(DateText.both(end)). افتح مصروفي وحدّث مبلغك."
            )]
        }

        var result: [Message] = []
        while result.count < limit && day <= s.endDate {
            let daysLeft = Days.between(day, s.endDate) + 1
            let until = daysLeft == 1
                ? "اليوم آخر يوم بالفترة."
                : "يكفيك لين \(DateText.both(end)) (\(DateText.days(daysLeft)) مع اليوم)."
            let title: String
            var body = until
            if day == today {
                if m.leftToday < 0 {
                    title = "تجاوزت حدّك اليوم"
                    body = m.daysLeft > 1 ? "حدّك من بكرة \(Money.whole(m.futureDaily)) \(currency) باليوم." : until
                } else if m.spentToday > 0 {
                    title = "باقي لك تصرف اليوم \(Money.whole(m.leftToday)) \(currency)"
                    body = "من حدّك \(Money.whole(m.allowance)) \(currency). \(until)"
                } else {
                    title = "تقدر تصرف اليوم \(Money.whole(m.allowance)) \(currency)"
                }
            } else if m.futureDaily < 1 {
                title = "ما بقى لك مصروف لهالفترة"
                body = "صرفت المتاح لين \(DateText.both(end)). حدّث مبلغك لو دخلك شي."
            } else {
                // Later days assume each day before them ends at its limit.
                title = "تقدر تصرف اليوم \(Money.whole(m.futureDaily)) \(currency)"
            }
            result.append(Message(day: day, title: title, body: body))
            day = Days.adding(1, to: day)
        }

        // The morning after the last day, ask for the new money.
        if result.count < limit && day > s.endDate {
            result.append(Message(
                day: day,
                title: "خلصت الفترة",
                body: "حط مبلغك الجديد واختر لين متى، عشان أحسب لك حدّك من جديد."
            ))
        }
        return result
    }

    static func fireDate(day: String, hour: Int, minute: Int) -> Date {
        Days.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Days.date(day)) ?? Days.date(day)
    }
}
