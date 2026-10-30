import SwiftUI

/// What the item sheet is for: a barcode scanned for the first time, something without a barcode,
/// or an item already in the basket.
enum ItemDraft: Identifiable {
    case scanned(String)
    case manual
    case edit(BasketItem)

    var id: String {
        switch self {
        case .scanned(let code): return "scan-\(code)"
        case .manual: return "manual"
        case .edit(let item): return item.id.uuidString
        }
    }

    var barcode: String? {
        switch self {
        case .scanned(let code): return code
        case .manual: return nil
        case .edit(let item): return item.barcode
        }
    }
}

struct ItemSheet: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    let draft: ItemDraft

    @State private var name = ""
    @State private var priceText = ""
    @State private var quantity = 1
    @State private var lookingUp = false
    @State private var showError = false
    @FocusState private var focus: Field?

    private enum Field { case name, price }

    private var isEdit: Bool {
        if case .edit = draft { return true }
        return false
    }

    var body: some View {
        let price = Money.parse(priceText)

        NavigationStack {
            Form {
                Section {
                    TextField("مثلاً: حليب", text: $name)
                        .font(.cairo(17))
                        .focused($focus, equals: .name)
                    if lookingUp {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("أدوّر على اسمه…")
                                .font(.cairo(14))
                                .foregroundColor(Theme.secondary)
                        }
                    }
                } header: {
                    SectionTitle("وش الغرض؟")
                } footer: {
                    if let barcode = draft.barcode {
                        Text("الباركود \(barcode)")
                            .font(.cairo(13))
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("0", text: $priceText)
                            .keyboardType(.decimalPad)
                            .font(.cairo(24, .bold))
                            .focused($focus, equals: .price)
                        RiyalMark(height: 18)
                    }
                    if showError {
                        Text("اكتب سعر الحبة.")
                            .font(.cairo(13))
                            .foregroundColor(Theme.bad)
                    }
                } header: {
                    SectionTitle("كم سعر الحبة؟")
                } footer: {
                    if draft.barcode != nil {
                        Text("أحفظ السعر لهالباركود، والمرة الجاية ينضاف على طول.")
                            .font(.cairo(13))
                    }
                }

                Section {
                    Stepper(value: $quantity, in: 1...99) {
                        Text("العدد: \(quantity)")
                    }
                    HStack {
                        Text("المجموع")
                        Spacer()
                        riyalText("\(Money.text(price * Double(quantity))) ¤", size: 17)
                            .font(.cairo(17, .bold))
                    }
                }

                if case .edit(let item) = draft {
                    Section {
                        Button(role: .destructive) {
                            store.removeFromBasket(item)
                            dismiss()
                        } label: {
                            Text("شيله من السلة")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEdit ? "عدّل الغرض" : "غرض جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "احفظ" : "أضف", action: save)
                        .font(.cairo(17, .bold))
                }
            }
            .keyboardDoneButton()
        }
        .onAppear(perform: load)
        .onChange(of: priceText) { _ in showError = false }
    }

    private func load() {
        switch draft {
        case .edit(let item):
            name = item.name
            priceText = Money.plain(item.price)
            quantity = item.quantity
        case .manual:
            break
        case .scanned(let code):
            lookingUp = true
            Task {
                let found = await ProductLookup.name(for: code)
                if let found, name.trimmingCharacters(in: .whitespaces).isEmpty {
                    name = found
                }
                lookingUp = false
            }
        }
        // A sheet takes keyboard focus only once it has finished sliding up.
        let field: Field = draft.barcode == nil && !isEdit ? .name : .price
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = field }
    }

    private func save() {
        let price = Money.parse(priceText)
        guard price > 0 else {
            showError = true
            focus = .price
            return
        }
        if case .edit(var item) = draft {
            item.name = name
            item.price = price
            item.quantity = quantity
            store.updateBasketItem(item)
        } else {
            store.addToBasket(barcode: draft.barcode, name: name, price: price, quantity: quantity)
        }
        dismiss()
    }
}
