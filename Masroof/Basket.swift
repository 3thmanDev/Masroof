import Foundation

/// One line of a shopping basket: a scanned product (or one typed in) and how many of it.
struct BasketItem: Codable, Identifiable, Equatable {
    var id = UUID()
    /// nil for things added without a barcode, like loose vegetables.
    var barcode: String?
    var name: String
    /// The price of one.
    var price: Double
    var quantity = 1

    var total: Double { price * Double(quantity) }
}

/// What a barcode was called and cost last time, so scanning it again fills both in.
struct Product: Codable, Equatable {
    var name: String
    var price: Double
}

/// The things picked up so far on a shopping trip, before they are paid for.
struct Basket: Codable, Equatable {
    /// Newest first, so the last thing scanned is at the top of the list.
    var items: [BasketItem] = []
    /// Where the shopping is, used as the expense's note.
    var place = ""

    var total: Double { items.reduce(0) { $0 + $1.total } }
    var count: Int { items.reduce(0) { $0 + $1.quantity } }
    var isEmpty: Bool { items.isEmpty }

    /// Scanning a barcode that is already in the basket adds one more of it.
    @discardableResult
    mutating func add(barcode: String?, name: String, price: Double, quantity: Int = 1) -> BasketItem {
        if let barcode, let index = items.firstIndex(where: { $0.barcode == barcode }) {
            var item = items.remove(at: index)
            item.quantity += max(1, quantity)
            item.name = name
            item.price = price
            items.insert(item, at: 0)
            return item
        }
        let item = BasketItem(barcode: barcode, name: name, price: price, quantity: max(1, quantity))
        items.insert(item, at: 0)
        return item
    }

    mutating func update(_ item: BasketItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    /// Zero takes the item out.
    mutating func setQuantity(_ quantity: Int, of id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if quantity < 1 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }

    mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// "غرض واحد"، "غرضين"، "3 أغراض"، "12 غرض"
    static func countText(_ count: Int) -> String {
        switch count {
        case 1: return "غرض واحد"
        case 2: return "غرضين"
        case 3...10: return "\(count) أغراض"
        default: return "\(count) غرض"
        }
    }
}

extension BudgetMath {
    struct Purchase: Equatable {
        /// Today's limit minus what was spent today and this purchase; below zero when it goes over.
        var leftToday: Double
        var fits: Bool
        /// Each later day's limit if this is bought and today ends at its limit (or past it).
        var futureDaily: Double
    }

    /// What buying `amount` today would do to today's limit and the days after it.
    static func purchase(_ amount: Double, _ m: Summary) -> Purchase {
        let spent = m.spentToday + amount
        let rest = m.daysLeft - 1
        let left = m.allowance - spent
        let future = rest > 0 ? max(0, m.poolStart - max(spent, m.allowance)) / Double(rest) : 0
        return Purchase(leftToday: left, fits: left > -0.005, futureDaily: future)
    }
}

/// Product names from Open Food Facts records, which hold the name in several languages.
enum ProductName {
    /// "المراعي حليب طازج 1 لتر"; nil when the record has no name and no brand.
    static func from(arabic: String?, name: String?, brand: String?, quantity: String?) -> String? {
        func clean(_ text: String?) -> String {
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var title = clean(arabic).isEmpty ? clean(name) : clean(arabic)
        // Brands come as a list ("Almarai,المراعي"); the first one is enough.
        let firstBrand = clean(brand?.split(separator: ",").first.map(String.init))
        if title.isEmpty {
            title = firstBrand
        } else if !firstBrand.isEmpty && title.range(of: firstBrand, options: .caseInsensitive) == nil {
            title = "\(firstBrand) \(title)"
        }
        guard !title.isEmpty else { return nil }
        let size = clean(quantity)
        if !size.isEmpty && !title.contains(size) {
            title += " \(size)"
        }
        return String(title.prefix(70))
    }
}
