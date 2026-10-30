import SwiftUI

/// The money on hand, the period it has to cover, and what is set aside from it.
struct SetupSheet: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var balanceText = ""
    @State private var savingsText = ""
    @State private var billName = ""
    @State private var billAmountText = ""
    @State private var pickInHijri = false
    @State private var confirmReset = false
    @FocusState private var focus: Field?

    private enum Field { case balance, savings, billName, billAmount }

    private struct ModeOption: Identifiable {
        let mode: EndMode
        let title: String
        var id: String { mode.rawValue }
    }

    private let modes = [
        ModeOption(mode: .month, title: "آخر هالشهر"),
        ModeOption(mode: .salary, title: "قبل الراتب"),
        ModeOption(mode: .nextMonth, title: "آخر الشهر الجاي"),
    ]

    var body: some View {
        let state = store.state
        let m = store.summary
        let end = Days.date(state.endDate)

        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        TextField("مثلاً 2500", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .font(.cairo(24, .bold))
                            .focused($focus, equals: .balance)
                        RiyalMark(height: 18)
                    }
                } header: {
                    SectionTitle("كم معك الحين؟")
                } footer: {
                    Text(state.balance > 0
                         ? "حدّثته \(DateText.when(state.balanceAt, today: store.today)). المصاريف اللي تسجلها بعده تنخصم منه."
                         : "اكتب المبلغ اللي بحسابك أو بجيبك الحين.")
                        .font(.cairo(13))
                }

                Section {
                    HStack(spacing: 6) {
                        ForEach(modes) { option in
                            EndModeButton(
                                title: option.title,
                                date: Days.date(BudgetMath.endDate(for: option.mode, salaryDay: state.salaryDay, from: store.today)),
                                selected: state.endMode == option.mode
                            ) {
                                store.choose(option.mode)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))

                    Picker("التقويم", selection: $pickInHijri) {
                        Text("ميلادي").tag(false)
                        Text("هجري").tag(true)
                    }
                    .pickerStyle(.segmented)

                    DatePicker(selection: endDateBinding, in: Days.date(store.today)..., displayedComponents: .date) {
                        Text("آخر يوم")
                    }
                    .environment(\.calendar, pickInHijri ? DateText.hijriCalendar : DateText.gregorianCalendar)

                    if state.endMode == .salary {
                        Stepper(value: salaryDayBinding, in: 1...31) {
                            Text("يوم نزول الراتب: \(state.salaryDay)")
                        }
                    }
                } header: {
                    SectionTitle("لين متى تبيه يكفيك؟")
                } footer: {
                    Text("\(DateText.long(end)) · \(DateText.hijriFull(end))" + (m.ended ? " · خلصت" : " · \(DateText.days(m.daysLeft)) مع اليوم"))
                        .font(.cairo(13))
                }

                Section {
                    ForEach(state.bills) { bill in
                        HStack(spacing: 8) {
                            Text(bill.name).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Money.text(bill.amount)).font(.cairo(16, .bold))
                            Button("دفعته") { store.payBill(bill) }
                                .font(.cairo(14, .semibold))
                                .buttonStyle(.bordered)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteBill(bill)
                            } label: {
                                Label("احذف", systemImage: "trash")
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("فاتورة الجوال", text: $billName)
                            .focused($focus, equals: .billName)
                        TextField("المبلغ", text: $billAmountText)
                            .keyboardType(.decimalPad)
                            .focused($focus, equals: .billAmount)
                            .frame(width: 84)
                        Button("أضف", action: addBill)
                            .font(.cairo(15, .bold))
                            .buttonStyle(.borderless)
                            .disabled(Money.parse(billAmountText) <= 0)
                    }
                } header: {
                    SectionTitle("مبالغ محجوزة")
                } footer: {
                    Text("فواتير وأقساط لازم تدفعها قبل نهاية الفترة. أحجز مبلغها من الحين عشان ما تصرفه. اسحب الالتزام عشان تحذفه.")
                        .font(.cairo(13))
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("0", text: $savingsText)
                            .keyboardType(.decimalPad)
                            .font(.cairo(20, .bold))
                            .focused($focus, equals: .savings)
                        RiyalMark(height: 16)
                    }
                } header: {
                    SectionTitle("تبي توفّر؟")
                } footer: {
                    Text("مبلغ يبقى لك آخر الفترة وما يدخل في حساب الصرف.")
                        .font(.cairo(13))
                }

                Section {
                    HStack {
                        Text("المجموع المحجوز")
                        Spacer()
                        riyalText("\(Money.text(m.reserved)) ¤", size: 17).font(.cairo(17, .bold))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("امسح كل شي وابدأ من جديد")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("فلوسك")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                        .font(.cairo(17, .bold))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { focus = nil }
                        .font(.cairo(17, .bold))
                }
            }
            .confirmationDialog("تمسح كل المصاريف والالتزامات؟", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("امسح كل شي", role: .destructive) {
                    store.resetAll()
                    syncFields()
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
        .overlay(alignment: .bottom) { ToastView() }
        .animation(.easeOut(duration: 0.25), value: store.toast?.id)
        .onAppear(perform: syncFields)
        .onChange(of: balanceText) { text in
            let amount = Money.parse(text)
            if amount != store.state.balance { store.setBalance(amount) }
        }
        .onChange(of: savingsText) { text in
            let amount = Money.parse(text)
            if amount != store.state.savings { store.setSavings(amount) }
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { Days.date(store.state.endDate) },
            set: { store.setEndDate(Days.key($0)) }
        )
    }

    private var salaryDayBinding: Binding<Int> {
        Binding(
            get: { store.state.salaryDay },
            set: { store.setSalaryDay($0) }
        )
    }

    private func syncFields() {
        balanceText = store.state.balance > 0 ? Money.plain(store.state.balance) : ""
        savingsText = store.state.savings > 0 ? Money.plain(store.state.savings) : ""
    }

    private func addBill() {
        let amount = Money.parse(billAmountText)
        guard amount > 0 else { return }
        let name = billName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addBill(name: name.isEmpty ? "التزام" : name, amount: amount)
        billName = ""
        billAmountText = ""
        focus = .billName
    }
}

struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.cairo(14, .bold))
            .foregroundColor(Theme.secondary)
            .textCase(nil)
    }
}

struct EndModeButton: View {
    let title: String
    let date: Date
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.cairo(13.5, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(DateText.short(date))
                    .font(.cairo(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(DateText.hijri(date))
                    .font(.cairo(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundColor(selected ? Theme.accent : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.accentSoft : Theme.field))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.borderless)
    }
}
