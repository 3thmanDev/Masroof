// Checks the budget math and both calendars on the build machine before the app is built:
// swiftc Masroof/Budget.swift Masroof/DateText.swift Tests/main.swift -o budget-check && ./budget-check

import Foundation

var checks = 0
var failures = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ what: String, line: Int = #line) {
    checks += 1
    if actual != expected {
        print("FAIL line \(line): \(what) -> \(actual), expected \(expected)")
        failures += 1
    }
}

func near(_ actual: Double, _ expected: Double, _ what: String, line: Int = #line) {
    checks += 1
    if abs(actual - expected) > 0.01 {
        print("FAIL line \(line): \(what) -> \(actual), expected \(expected)")
        failures += 1
    }
}

// Periods.
expect(BudgetMath.endDate(for: .month, salaryDay: 27, from: "2026-10-30"), "2026-10-31", "end of this month")
expect(BudgetMath.endDate(for: .nextMonth, salaryDay: 27, from: "2026-10-30"), "2026-11-30", "end of next month")
expect(BudgetMath.endDate(for: .nextMonth, salaryDay: 27, from: "2026-12-28"), "2027-01-31", "next month across the new year")
expect(BudgetMath.endDate(for: .month, salaryDay: 27, from: "2028-02-10"), "2028-02-29", "leap February")
expect(BudgetMath.endDate(for: .salary, salaryDay: 27, from: "2026-10-30"), "2026-11-26", "day before next payday")
expect(BudgetMath.endDate(for: .salary, salaryDay: 27, from: "2026-11-26"), "2026-11-26", "the day before payday is the last day")
expect(BudgetMath.endDate(for: .salary, salaryDay: 27, from: "2026-11-27"), "2026-12-26", "on payday, plan to the next one")
expect(BudgetMath.endDate(for: .salary, salaryDay: 27, from: "2026-12-28"), "2027-01-26", "payday across the new year")
expect(BudgetMath.endDate(for: .salary, salaryDay: 31, from: "2027-02-10"), "2027-02-27", "payday 31 falls on 28 February")
let late = BudgetMath.defaultEnd(today: "2026-10-30")
expect(late.mode, .nextMonth, "two days left: default to next month")
expect(late.date, "2026-11-30", "two days left: default date")
let early = BudgetMath.defaultEnd(today: "2026-10-10")
expect(early.mode, .month, "mid month: default to this month")
expect(early.date, "2026-10-31", "mid month: default date")

// Day arithmetic.
expect(Days.between("2026-10-30", "2026-11-30"), 31, "days between")
expect(Days.adding(1, to: "2026-12-31"), "2027-01-01", "next day across the new year")
expect(Days.weekday("2026-11-01"), 0, "1 November 2026 is a Sunday")
expect(Days.weekday("2026-10-30"), 5, "30 October 2026 is a Friday")

// The example the app opens with: 3,200 − 131 spent − 710 set aside = 2,359 over 32 days.
let examplePlan = BudgetState.example(today: "2026-10-30", now: Days.date("2026-10-30").addingTimeInterval(3 * 3600))
let example = BudgetMath.summary(examplePlan, today: "2026-10-30")
expect(example.daysLeft, 32, "example days left")
near(example.reserved, 710, "example set aside")
near(example.onHand, 3051, "example on hand")
near(example.poolStart, 2359, "example spendable")
near(example.allowance, 73.72, "example daily limit")
near(example.leftToday, 55.72, "example left today")
expect(Money.whole(example.allowance), "73", "daily limit is rounded down")
expect(BudgetMath.status(examplePlan, example), .onTrack(left: example.leftToday, nearLimit: false), "example is on track")

// Spending past today's limit lowers the days after it.
let morning = Days.date("2026-11-01").addingTimeInterval(-4 * 3600)
var overPlan = BudgetState.blank(today: "2026-11-01", now: morning)
overPlan.balance = 1000
overPlan.endDate = "2026-11-10"
overPlan.endMode = .custom
overPlan.expenses = [Expense(amount: 150, note: "مطعم", day: "2026-11-01", at: Days.date("2026-11-01"))]
let over = BudgetMath.summary(overPlan, today: "2026-11-01")
expect(over.daysLeft, 10, "ten days left")
near(over.allowance, 100, "1000 over 10 days")
near(over.futureDaily, 94.44, "850 over the 9 days after today")
expect(BudgetMath.status(overPlan, over), .over(50), "50 over today's limit")

// A paid bill is not daily spending, and entries written before the balance are already in it.
var paidPlan = overPlan
paidPlan.expenses = [
    Expense(amount: 300, note: "إيجار", day: "2026-11-01", at: Days.date("2026-11-01"), kind: .bill),
    Expense(amount: 999, note: "قبل الرصيد", day: "2026-11-01", at: morning.addingTimeInterval(-60)),
]
let paid = BudgetMath.summary(paidPlan, today: "2026-11-01")
near(paid.spentToday, 0, "paid bill is not today's spending")
near(paid.onHand, 700, "paid bill leaves the balance")
near(paid.allowance, 70, "700 over 10 days")

// Not enough money for what is set aside.
var shortPlan = overPlan
shortPlan.expenses = []
shortPlan.balance = 500
shortPlan.savings = 600
expect(BudgetMath.status(shortPlan, BudgetMath.summary(shortPlan, today: "2026-11-01")), .short(100), "100 short")

// A finished period, and a fresh start.
var endedPlan = overPlan
endedPlan.endDate = "2026-10-31"
expect(BudgetMath.summary(endedPlan, today: "2026-11-01").ended, true, "period ended yesterday")
expect(BudgetMath.status(endedPlan, BudgetMath.summary(endedPlan, today: "2026-11-01")), .ended, "ended status")
let blank = BudgetState.blank(today: "2026-11-01")
expect(BudgetMath.status(blank, BudgetMath.summary(blank, today: "2026-11-01")), .empty, "nothing typed yet")

// Typed amounts.
expect(Money.parse("٢٬٥٠٠"), 2500, "Arabic digits with Arabic thousands sign")
expect(Money.parse("١٢٫٥"), 12.5, "Arabic decimal sign")
expect(Money.parse("۳۰۰"), 300, "Persian digits")
expect(Money.parse("1,250.5"), 1250.5, "comma thousands")
expect(Money.parse("1,250"), 1250, "comma before three digits is thousands")
expect(Money.parse("12,5"), 12.5, "comma before one digit is a decimal")
expect(Money.parse("abc"), 0, "no digits")
expect(Money.parse(""), 0, "empty")
expect(Money.text(3051), "3,051", "money text")
expect(Money.text(1250.5), "1,250.5", "money text with decimals")
expect(Money.plain(2500), "2500", "plain whole")
expect(Money.plain(12.5), "12.5", "plain decimal")

// Hijri dates (Umm al-Qura).
let october30 = Days.date("2026-10-30")
let november30 = Days.date("2026-11-30")
expect(DateText.hijriDay(october30), 19, "30 Oct 2026 is 19 Jumada al-Ula")
expect(DateText.hijriCalendar.component(.month, from: october30), 5, "Jumada al-Ula is month 5")
expect(DateText.hijriDay(november30), 20, "30 Nov 2026 is 20 Jumada al-Akhirah")
expect(DateText.hijriCalendar.component(.month, from: november30), 6, "Jumada al-Akhirah is month 6")
expect(DateText.hijri(october30).contains("جمادى"), true, "Hijri month name in Arabic")
expect(DateText.short(october30).contains("30"), true, "Gregorian day in Western digits")
expect(DateText.days(1), "يوم واحد", "one day")
expect(DateText.days(2), "يومين", "two days")
expect(DateText.days(5), "5 أيام", "a few days")
expect(DateText.days(32), "32 يوم", "many days")

print("samples: \(DateText.long(october30)) | \(DateText.hijriFull(october30)) | \(DateText.both(november30)) | \(DateText.span(from: october30, to: november30, hijri: false)) | \(DateText.span(from: october30, to: november30, hijri: true))")
print("\(checks - failures)/\(checks) budget checks passed")
if failures > 0 { exit(1) }
