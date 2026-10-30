import SwiftUI

/// Today's limit: what is left to spend today, and the four numbers behind it.
struct HeroCard: View {
    @EnvironmentObject private var store: BudgetStore
    let onEdit: () -> Void

    var body: some View {
        let state = store.state
        let m = store.summary
        let content = HeroContent(status: store.status, summary: m, state: state)
        let end = Days.date(state.endDate)
        let live = content.isLive

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(content.eyebrow)
                    .font(.cairo(15, .medium))
                    .foregroundColor(Theme.heroMuted)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(content.dot).frame(width: 8, height: 8)
                    Text(content.pill).font(.cairo(13, .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(content.number)
                    .font(.cairo(66, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if content.showsCurrency {
                    RiyalMark(height: 30, color: Theme.heroMuted)
                }
            }

            Meter(ratio: content.ratio, color: content.dot)
                .padding(.top, 2)

            riyalText(content.sub, size: 15)
                .font(.cairo(15))
                .foregroundColor(Theme.heroMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .padding(.vertical, 14)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14, alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 14) {
                Stat(
                    title: "حدّك اليومي",
                    value: live ? "\(Money.whole(m.allowance)) ¤" : "—",
                    notes: live ? ["حد الأسبوع \(Money.whole(m.allowance * Double(min(7, m.daysLeft))))"] : []
                )
                Stat(
                    title: "يكفيك لين",
                    value: DateText.short(end),
                    notes: [DateText.hijri(end), m.ended ? "خلصت" : "\(DateText.days(m.daysLeft)) مع اليوم"]
                )
                Stat(
                    title: "معك الحين",
                    value: content.isEmpty ? "—" : "\(Money.text(m.onHand)) ¤",
                    notes: content.isEmpty ? [] : [m.spentAll > 0 ? "صرفت \(Money.text(m.spentAll)) من \(Money.text(state.balance))" : "ما صرفت منه شي"]
                )
                Stat(
                    title: "منها محجوز",
                    value: "\(Money.text(m.reserved)) ¤",
                    notes: content.isEmpty ? [] : ["يبقى للصرف \(Money.text(max(0, m.free)))"]
                )
            }

            riyalText(content.hint, size: 15)
                .font(.cairo(15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)

            Button(action: onEdit) {
                Text("عدّل المبلغ أو التاريخ")
                    .font(.cairo(14, .semibold))
                    .underline()
                    .foregroundColor(Theme.heroInk)
            }
            .padding(.top, 8)
        }
        .foregroundColor(Theme.heroInk)
        .padding(20)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The words on the hero for each state of the budget.
struct HeroContent {
    var eyebrow = ""
    var pill = ""
    var number = "—"
    var showsCurrency = true
    var sub = ""
    var hint = ""
    var ratio = 0.0
    var dot = Theme.dotGood
    var isEmpty = false
    var isLive = true

    init(status: BudgetMath.Status, summary m: BudgetMath.Summary, state s: BudgetState) {
        switch status {
        case .empty:
            isEmpty = true
            isLive = false
            pill = "بانتظار المبلغ"
            eyebrow = "ابدأ من هنا"
            showsCurrency = false
            dot = Theme.heroMuted
            sub = "اضغط «عدّل المبلغ أو التاريخ» واكتب كم معك الحين."
            hint = "أقسم لك المبلغ على الأيام الباقية لين التاريخ اللي تختاره، بعد ما أحجز الفواتير والتوفير."
        case .ended:
            isLive = false
            pill = "خلصت الفترة"
            eyebrow = "معك الحين تقريبًا"
            number = Money.text(max(0, m.onHand))
            dot = Theme.heroMuted
            let end = Days.date(s.endDate)
            sub = "الفترة خلصت يوم \(DateText.long(end)) (\(DateText.hijri(end)))."
            hint = "اختر تاريخ جديد من «عدّل المبلغ أو التاريخ» وحدّث المبلغ اللي معك."
        case .short(let missing):
            pill = "المبلغ ما يكفي"
            eyebrow = "ينقصك"
            number = Money.text(missing)
            ratio = 1
            dot = Theme.dotBad
            sub = m.reserved > 0 ? "اللي معك ما يغطي المبالغ المحجوزة للفترة." : "خلص المبلغ اللي معك."
            hint = s.savings > 0
                ? "قلّل مبلغ التوفير أو أجّل التزام، أو حدّث المبلغ لو دخلك شي."
                : "حدّث المبلغ لو دخلك شي، أو راجع الالتزامات."
        case .over(let extra):
            pill = "تجاوزت حد اليوم"
            eyebrow = "تجاوزت حد اليوم بـ"
            number = Money.text(extra)
            ratio = 1
            dot = Theme.dotBad
            sub = "صرفت اليوم \(Money.text(m.spentToday)) وحدّك \(Money.whole(m.allowance)) ¤."
            hint = m.daysLeft > 1
                ? "عشان تلحق، حدّك من بكرة يصير \(Money.whole(m.futureDaily)) ¤ باليوم."
                : "اليوم آخر يوم بالفترة، والزيادة بتنقص من التوفير."
        case .onTrack(let left, let nearLimit):
            pill = nearLimit ? "قربت من الحد" : "ماشي تمام"
            eyebrow = "باقي لك تصرف اليوم"
            number = Money.whole(left)
            ratio = m.allowance > 0 ? m.spentToday / m.allowance : 0
            dot = nearLimit ? Theme.dotWarn : Theme.dotGood
            sub = m.spentToday > 0
                ? "صرفت اليوم \(Money.text(m.spentToday)) من حدّك \(Money.whole(m.allowance)) ¤."
                : "ما سجلت مصروف اليوم. حدّك اليومي \(Money.whole(m.allowance)) ¤."
            hint = m.daysLeft > 1
                ? "لو ما صرفت أكثر اليوم، يرتفع حدّك من بكرة إلى \(Money.whole(m.ifStopNow)) ¤ باليوم."
                : "اليوم آخر يوم بالفترة."
        }
    }
}

struct Stat: View {
    let title: String
    let value: String
    var notes: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.cairo(12.5))
                .foregroundColor(Theme.heroMuted)
            riyalText(value, size: 18)
                .font(.cairo(18, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.cairo(12))
                    .foregroundColor(Theme.heroMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Meter: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, ratio))))
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: ratio)
    }
}

/// Fine concentric rings from two corners, like the engraving on a banknote.
struct HeroBackground: View {
    var body: some View {
        Theme.hero.overlay(
            Canvas { context, size in
                let rings: [(CGPoint, CGFloat)] = [
                    (CGPoint(x: 0, y: size.height), 14),
                    (CGPoint(x: size.width, y: 0), 18),
                ]
                let reach = hypot(size.width, size.height)
                for (center, step) in rings {
                    var radius = step
                    while radius < reach {
                        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.055)), lineWidth: 1)
                        radius += step
                    }
                }
            }
        )
    }
}
