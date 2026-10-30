import Foundation

/// Product names from Open Food Facts, a free shared database of packaged food. It has no prices,
/// so a price is typed once and remembered for that barcode.
enum ProductLookup {
    private struct Reply: Decodable {
        struct Fields: Decodable {
            var product_name_ar: String?
            var product_name: String?
            var brands: String?
            var quantity: String?
        }

        var status: Int?
        var product: Fields?
    }

    static func name(for barcode: String) async -> String? {
        guard !barcode.isEmpty, barcode.allSatisfy({ $0.isASCII && $0.isNumber }),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name_ar,product_name,brands,quantity")
        else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        // Open Food Facts asks every app to name itself.
        request.setValue("Masroof/1.1 (iOS budget app)", forHTTPHeaderField: "User-Agent")
        guard let fetched = try? await URLSession.shared.data(for: request),
              (fetched.1 as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONDecoder().decode(Reply.self, from: fetched.0),
              reply.status == 1, let product = reply.product
        else { return nil }
        return ProductName.from(arabic: product.product_name_ar, name: product.product_name, brand: product.brands, quantity: product.quantity)
    }
}
