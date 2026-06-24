import Foundation

extension Decimal {
    /// Returns a currency-formatted string for this value, using the
    /// supplied ISO 4217 currency code.
    ///
    /// Negative values are prefixed with the Unicode minus sign
    /// (`\u{2212}`) rather than a hyphen so the rendered string is
    /// typographically correct. The sign is the ONLY place in the
    /// codebase that decides which prefix to use; all views call this
    /// helper and never add their own minus sign.
    ///
    /// Example: `Decimal(-243.10).formatted(currencyCode: "USD")` →
    /// `"\u{2212}$243.10"`
    func formatted(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.roundingMode = .halfUp

        let absoluteValue = self < 0 ? -self : self
        let formatted = formatter.string(from: absoluteValue as NSDecimalNumber) ?? "\(absoluteValue)"

        if self < 0 {
            return "\u{2212}\(formatted)"
        }
        return formatted
    }

    /// Returns a currency-formatted string for the absolute value of
    /// this `Decimal`, without any sign prefix.
    ///
    /// Useful for displaying the "available balance" subtext beside a
    /// negative balance row: e.g. `"$4,756.90 available"`.
    func formattedAbsolute(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.roundingMode = .halfUp

        let absoluteValue = self < 0 ? -self : self
        return formatter.string(from: absoluteValue as NSDecimalNumber) ?? "\(absoluteValue)"
    }
}
