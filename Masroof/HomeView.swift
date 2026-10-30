import SwiftUI
import UIKit

enum AppTab: Hashable {
    case today, basket, log, money
}

/// The four tabs along the bottom: today's limit, the shopping basket, the spending log, and the money settings.
struct RootView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.today
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: Binding(get: { tab }, set: select)) {
            HomeView(openSetup: { select(.money) })
                .tabItem { Label("اليوم", systemImage: "sun.max.fill") }
                .tag(AppTab.today)
            BasketView()
                .tabItem { Label("السلة", systemImage: "barcode.viewfinder") }
                .tag(AppTab.basket)
            LogView()
                .tabItem { Label("السجل", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.log)
            SetupView()
                .tabItem { Label("فلوسك", systemImage: "banknote") }
                .tag(AppTab.money)
        }
        .onReceive(clock) { _ in store.refreshDay() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            store.refreshDay()
            store.scheduleReminders()
        }
        .task { store.scheduleReminders() }
    }

    /// The example is only a preview, so opening the money tab starts from the person's own numbers.
    private func select(_ next: AppTab) {
        if next == .money && store.state.isExample { store.startFresh() }
        tab = next
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: BudgetStore
    let openSetup: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if store.state.isExample {
                        ExampleBanner(start: openSetup)
                    }
                    HeroCard(onEdit: openSetup)
                    AddExpenseCard()
                    CalendarCard()
                    Text("طريقة الحساب: (اللي معك − المحجوز) ÷ الأيام الباقية مع اليوم. إذا صرفت اليوم أقل من حدّك، يرتفع حدّك للأيام الجاية، وإذا صرفت أكثر ينزل.")
                        .font(.cairo(13))
                        .foregroundColor(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .keyboardDoneButton()
        }
        .withToast()
    }

    private var header: some View {
        let today = Days.date(store.today)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("مصروف آخر الشهر")
                    .font(.cairo(28, .bold))
                Text("\(DateText.long(today)) · \(DateText.hijriFull(today))")
                    .font(.cairo(14))
                    .foregroundColor(Theme.secondary)
            }
            Spacer(minLength: 8)
            Button(action: openSetup) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.card))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("فلوسك")
        }
        .padding(.top, 8)
    }
}

/// Every expense, newest day first, with the items of each scanned basket.
struct LogView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("السجل")
                            .font(.cairo(28, .bold))
                        Text("كل مصاريفك، واضغط على أي سلة تشوف أغراضها.")
                            .font(.cairo(14))
                            .foregroundColor(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    ExpenseLogCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .withToast()
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension View {
    /// A "تم" button above the number pad, which has no return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("تم") { hideKeyboard() }
                    .font(.cairo(17, .bold))
            }
        }
    }

    /// The undo message, sitting just above the tab bar.
    func withToast() -> some View {
        modifier(ToastLayer())
    }
}

struct ToastLayer: ViewModifier {
    @EnvironmentObject private var store: BudgetStore

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) { ToastView() }
            .animation(.easeOut(duration: 0.25), value: store.toast?.id)
    }
}

struct ExampleBanner: View {
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("هذي أرقام مثال. ").font(.cairo(15, .bold))
                + Text("حط مبلغك الحقيقي وتنحسب لك على طول.").font(.cairo(15)))
                .frame(maxWidth: .infinity, alignment: .leading)
            PrimaryButton(title: "ابدأ بأرقامي", action: start)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.warnSoft))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.warn.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

struct ToastView: View {
    @EnvironmentObject private var store: BudgetStore

    var body: some View {
        if let toast = store.toast {
            HStack(spacing: 12) {
                riyalText(toast.message, size: 15)
                    .font(.cairo(15))
                    .foregroundColor(.white)
                    .lineLimit(2)
                if let undo = toast.undo {
                    Button {
                        undo()
                        store.toast = nil
                    } label: {
                        Text("تراجع")
                            .font(.cairo(15, .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.ink))
            .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }
}
