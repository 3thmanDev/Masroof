import SwiftUI
import UIKit

/// The shopping tab: scan each product's barcode and see the running total against today's limit.
struct BasketView: View {
    @EnvironmentObject private var store: BudgetStore
    @StateObject private var camera = BarcodeCamera()
    @State private var scanning = false
    @State private var editing: ItemDraft?
    @State private var notice: ScanNotice?
    @State private var confirmEmpty = false

    private struct ScanNotice: Equatable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    ScannerCard(
                        camera: camera,
                        scanning: scanning,
                        notice: notice?.text,
                        start: startScanning,
                        stop: stopScanning,
                        addByHand: { editing = .manual }
                    )
                    BasketTotalCard()
                    BasketItemsCard(edit: { editing = .edit($0) }, emptyBasket: { confirmEmpty = true })
                    if !store.basket.isEmpty {
                        CheckoutCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .keyboardDoneButton()
        }
        .withToast()
        .sheet(item: $editing, onDismiss: { camera.isPaused = false }) { draft in
            ItemSheet(draft: draft)
                .environmentObject(store)
                .appEnvironment()
        }
        .confirmationDialog("تفضّي السلة؟", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("فضّها", role: .destructive) { store.emptyBasket() }
            Button("إلغاء", role: .cancel) {}
        }
        .onReceive(camera.codes) { handle($0) }
        .onAppear {
            if scanning { camera.start() }
        }
        .onDisappear { camera.stop() }
        .task(id: notice?.id) {
            guard notice != nil else { return }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { notice = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("السلة")
                .font(.cairo(28, .bold))
            Text("امسح أغراضك وأنت تتسوّق، وأجمع لك الحساب قبل الكاشير.")
                .font(.cairo(14))
                .foregroundColor(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func startScanning() {
        scanning = true
        camera.start()
    }

    private func stopScanning() {
        scanning = false
        camera.stop()
    }

    /// A barcode seen before goes straight in at its last price; a new one asks for its price.
    private func handle(_ code: String) {
        if let known = store.product(for: code) {
            let item = store.addToBasket(barcode: code, name: known.name, price: known.price)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            notice = ScanNotice(text: item.quantity > 1
                ? "صار عندك \(item.quantity) من \(item.name)"
                : "انضاف \(item.name) · \(Money.text(item.price)) ¤")
        } else {
            camera.isPaused = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            editing = .scanned(code)
        }
    }
}

struct ScannerCard: View {
    @ObservedObject var camera: BarcodeCamera
    let scanning: Bool
    let notice: String?
    let start: () -> Void
    let stop: () -> Void
    let addByHand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch camera.access {
            case .denied:
                blocked
            case .unavailable:
                Text("ما قدرت أشغّل الكاميرا على هالجهاز. تقدر تضيف أغراضك بيدك.")
                    .font(.cairo(15))
            case .unknown, .allowed:
                if scanning { live } else { idle }
            }

            Button(action: addByHand) {
                Label("أضف غرض بدون باركود", systemImage: "plus")
                    .font(.cairo(15, .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(16)
        .card()
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Theme.accentSoft))
            Text("امسح باركود كل غرض")
                .font(.cairo(18, .bold))
            Text("وأجمع لك أسعارها، وتعرف كم بتدفع قبل لا توصل الكاشير.")
                .font(.cairo(14))
                .foregroundColor(Theme.secondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "ابدأ المسح", action: start)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                CameraPreview(camera: camera)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 48)
                if !camera.isRunning {
                    ProgressView().tint(.white)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .top) {
                HStack {
                    if camera.hasTorch {
                        CircleButton(icon: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill", label: "الكشاف", action: camera.toggleTorch)
                    }
                    Spacer()
                    CircleButton(icon: "xmark", label: "وقّف المسح", action: stop)
                }
                .padding(10)
            }
            .overlay(alignment: .bottom) {
                if let notice {
                    riyalText(notice, size: 14)
                        .font(.cairo(14, .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: notice)

            Text("وجّه الكاميرا على باركود الغرض. أول مرة تكتب سعره، وبعدها ينضاف على طول.")
                .font(.cairo(13))
                .foregroundColor(Theme.secondary)
        }
    }

    private var blocked: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("الكاميرا مقفلة لمصروفي")
                .font(.cairo(17, .bold))
            Text("عشان تمسح الباركود، اسمح لمصروفي يستخدم الكاميرا من الإعدادات.")
                .font(.cairo(14))
                .foregroundColor(Theme.secondary)
            PrimaryButton(title: "افتح الإعدادات") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

struct CircleButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// The basket's total on the banknote-green panel, measured against today's limit.
struct BasketTotalCard: View {
    @EnvironmentObject private var store: BudgetStore

    var body: some View {
        let basket = store.basket
        let words = BasketComparison(status: store.status, summary: store.summary, state: store.state, total: basket.total)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("مجموع السلة")
                    .font(.cairo(15, .medium))
                    .foregroundColor(Theme.heroMuted)
                Spacer(minLength: 8)
                Text(basket.isEmpty ? "فاضية" : Basket.countText(basket.count))
                    .font(.cairo(13, .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Money.text(basket.total))
                    .font(.cairo(58, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                RiyalMark(height: 26, color: Theme.heroMuted)
            }

            if let ratio = words.ratio {
                Meter(ratio: ratio, color: words.color)
                    .padding(.top, 2)
            }

            riyalText(words.line, size: 15)
                .font(.cairo(15))
                .foregroundColor(Theme.heroMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            if let next = words.next {
                riyalText(next, size: 15)
                    .font(.cairo(15, .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .foregroundColor(Theme.heroInk)
        .padding(20)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// How the basket sits against today's limit, in words.
struct BasketComparison {
    var line = ""
    var next: String?
    var ratio: Double?
    var color = Theme.dotGood

    init(status: BudgetMath.Status, summary m: BudgetMath.Summary, state: BudgetState, total: Double) {
        if state.isExample || status == .empty {
            line = "حط مبلغك في «فلوسك» عشان أقارن السلة بحدّك اليومي."
            return
        }
        switch status {
        case .ended:
            line = "الفترة خلصت. حدّث مبلغك والتاريخ من «فلوسك»."
            return
        case .short:
            line = "مصروفك لهالفترة ما يكفي، انتبه قبل لا تشتري."
            ratio = 1
            color = Theme.dotBad
            return
        default:
            break
        }

        let after = BudgetMath.purchase(total, m)
        let used = m.allowance > 0 ? (m.spentToday + total) / m.allowance : 1
        ratio = used
        if after.fits {
            color = used >= 0.8 ? Theme.dotWarn : Theme.dotGood
            if total == 0 {
                line = "باقي لك تصرف اليوم \(Money.whole(after.leftToday)) ¤."
            } else if m.spentToday > 0 {
                line = "مع اللي صرفته اليوم، يبقى لك \(Money.whole(after.leftToday)) ¤ من حدّك \(Money.whole(m.allowance)) ¤."
            } else {
                line = "تكفيك من حدّك اليوم، ويبقى لك \(Money.whole(after.leftToday)) ¤."
            }
            return
        }

        color = Theme.dotBad
        line = total == 0
            ? "تجاوزت حدّك اليوم بـ \(Money.text(-after.leftToday)) ¤."
            : "بتتجاوز حدّك اليوم (\(Money.whole(m.allowance)) ¤) بـ \(Money.text(-after.leftToday)) ¤."
        if m.daysLeft <= 1 {
            next = "اليوم آخر يوم بالفترة."
        } else if after.futureDaily >= 1 {
            next = total == 0
                ? "حدّك من بكرة \(Money.whole(after.futureDaily)) ¤ باليوم."
                : "لو اشتريتها، حدّك من بكرة يصير \(Money.whole(after.futureDaily)) ¤ باليوم."
        } else {
            next = "لو اشتريتها، ما يبقى لك شي للأيام الجاية."
        }
    }
}

struct BasketItemsCard: View {
    @EnvironmentObject private var store: BudgetStore
    let edit: (BasketItem) -> Void
    let emptyBasket: () -> Void

    var body: some View {
        let items = store.basket.items

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("أغراضك")
                    .font(.cairo(20, .bold))
                Spacer(minLength: 8)
                if !items.isEmpty {
                    Button("فضّي السلة", action: emptyBasket)
                        .font(.cairo(13.5, .semibold))
                        .foregroundColor(Theme.bad)
                }
            }

            if items.isEmpty {
                Text("السلة فاضية. امسح أول غرض وينضاف هنا.")
                    .font(.cairo(14))
                    .foregroundColor(Theme.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        BasketRow(item: item, edit: { edit(item) }, change: { store.setQuantity($0, of: item) })
                        if item.id != items.last?.id {
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                    }
                }
                Text("اضغط على أي غرض عشان تعدّل اسمه أو سعره.")
                    .font(.cairo(12.5))
                    .foregroundColor(Theme.secondary)
            }
        }
        .padding(18)
        .card()
        .animation(.easeOut(duration: 0.2), value: items.map(\.id))
    }
}

struct BasketRow: View {
    let item: BasketItem
    let edit: () -> Void
    let change: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.cairo(16))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    riyalText(item.quantity > 1 ? "\(item.quantity) × \(Money.text(item.price)) ¤" : "\(Money.text(item.price)) ¤ للحبة", size: 13)
                        .font(.cairo(13))
                        .foregroundColor(Theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            QuantityControl(quantity: item.quantity, change: change)

            Text(Money.text(item.total))
                .font(.cairo(16, .bold))
                .lineLimit(1)
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

struct QuantityControl: View {
    let quantity: Int
    let change: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            step(icon: "plus", label: "زيد واحد", color: Theme.accent) { change(quantity + 1) }
            Text("\(quantity)")
                .font(.cairo(15, .bold))
                .frame(minWidth: 20)
            if quantity == 1 {
                step(icon: "trash", label: "شيله من السلة", color: Theme.bad) { change(0) }
            } else {
                step(icon: "minus", label: "نقّص واحد", color: Theme.accent) { change(quantity - 1) }
            }
        }
        .background(Capsule().fill(Theme.field))
    }

    private func step(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

struct CheckoutCard: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var place = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("خلصت تسوّق؟")
                .font(.cairo(20, .bold))
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("وين تتسوّق؟")
                TextField("مثلاً: بنده", text: $place)
                    .font(.cairo(16))
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
            }
            PrimaryButton(title: "سجّلها مصروف") {
                hideKeyboard()
                store.checkoutBasket()
            }
            riyalText("تنضاف \(Money.text(store.basket.total)) ¤ لمصاريف اليوم مع تفصيل أغراضها، وتلقاها في «السجل».", size: 13)
                .font(.cairo(13))
                .foregroundColor(Theme.secondary)
        }
        .padding(18)
        .card()
        .onAppear { place = store.basket.place }
        .onChange(of: place) { text in
            if text != store.basket.place { store.setBasketPlace(text) }
        }
    }
}
