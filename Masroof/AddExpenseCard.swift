import SwiftUI

struct AddExpenseCard: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var amountText = ""
    @State private var note = ""
    @State private var spentOn = Date()
    @State private var showError = false
    @FocusState private var focus: Field?

    private enum Field { case amount, note }
    private let quickNotes = ["قهوة", "مطاعم", "بقالة", "بنزين", "توصيل", "مشاوير", "تسوّق"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("سجّل مصروف")
                .font(.cairo(20, .bold))

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("كم صرفت؟")
                HStack(spacing: 8) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.cairo(26, .bold))
                        .focused($focus, equals: .amount)
                    RiyalMark(height: 18)
                }
                .padding(.horizontal, 14)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(showError ? Theme.bad : Color.clear, lineWidth: 1.5)
                )
                if showError {
                    Text("اكتب المبلغ اللي صرفته.")
                        .font(.cairo(13))
                        .foregroundColor(Theme.bad)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("على إيش؟")
                    TextField("مثلاً: قهوة", text: $note)
                        .font(.cairo(16))
                        .focused($focus, equals: .note)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("متى؟ · \(DateText.hijri(spentOn))")
                    DatePicker("متى؟", selection: $spentOn, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .frame(height: 46)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickNotes, id: \.self) { word in
                        let picked = note.trimmingCharacters(in: .whitespaces) == word
                        Button {
                            note = word
                            if amountText.isEmpty { focus = .amount }
                        } label: {
                            Text(word)
                                .font(.cairo(14, picked ? .bold : .regular))
                                .foregroundColor(picked ? Theme.accent : Theme.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(Capsule().fill(picked ? Theme.accentSoft : Color.clear))
                                .overlay(Capsule().strokeBorder(picked ? Theme.accent : Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
            }

            PrimaryButton(title: "أضف", action: add)
        }
        .padding(18)
        .card()
        .onChange(of: amountText) { _ in showError = false }
    }

    private func add() {
        let amount = Money.parse(amountText)
        guard amount > 0 else {
            showError = true
            focus = .amount
            return
        }
        store.addExpense(
            amount: amount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            day: Days.key(spentOn)
        )
        amountText = ""
        note = ""
        spentOn = Date()
        focus = nil
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.cairo(13.5, .medium))
            .foregroundColor(Theme.secondary)
            .lineLimit(1)
    }
}
