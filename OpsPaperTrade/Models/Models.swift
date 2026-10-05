import Foundation

// MARK: - Lenient numbers

/// The bot's ledger stores quantities as JSON strings (e.g. `"quantity": "0"`,
/// `"filled_quantity": "12.5"`), while other endpoints emit real numbers.
/// `LenientDouble` decodes either form into a `Double?`; unparseable values
/// decode as `nil` instead of failing the whole response. Call sites keep
/// using `Double?`, so `trade.notionalUsd` etc. are unchanged.
@propertyWrapper
struct LenientDouble: Codable {
    var wrappedValue: Double?

    init(wrappedValue: Double?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
            return
        }
        if let number = try? container.decode(Double.self) {
            wrappedValue = number
            return
        }
        if let text = try? container.decode(String.self), let number = Double(text) {
            wrappedValue = number
            return
        }
        wrappedValue = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Health

/// GET /health — every field optional; the server currently returns
/// {"status": "ok", "dry_run": bool}.
struct HealthResponse: Codable {
    var status: String?
    var dryRun: Bool?

    var isAlive: Bool { (status ?? "").lowercased() == "ok" }
}

// MARK: - Dashboard trades

/// GET /api/trades
struct TradesResponse: Codable {
    var trades: [Trade]?
    var notice: String?
    var asOf: String?
    var summary: TradeSummary?
    var settings: DashboardSettings?
}

struct TradeSummary: Codable {
    var total: Int?
    var ordered: Int?
    var activeExits: Int?
    var completedExits: Int?
    var attention: Int?
}

struct DashboardSettings: Codable {
    var dryRun: Bool?
    var schedulerEnabled: Bool?
    var schedulerRunning: Bool?
    var exitTime: String?
    var timezone: String?
}

struct Trade: Codable, Identifiable {
    var key: String?
    var tradeId: String?
    var symbol: String?
    var direction: String?
    var strategy: String?
    var pipeline: String?
    var status: String?
    var createdAt: String?
    var updatedAt: String?
    var action: String?
    @LenientDouble var notionalUsd: Double?
    var rationale: String?
    var bracket: Bracket?
    var exit: ExitJob?

    /// The server always provides `key`; fall back to trade_id so rows stay stable.
    var id: String { key ?? tradeId ?? "unknown" }
    var displaySymbol: String { symbol ?? "\u{2014}" }
}

struct Bracket: Codable {
    var entryId: String?
    var profitId: String?
    var stopId: String?
    var comboId: String?

    var hasAny: Bool {
        [entryId, profitId, stopId, comboId].contains { ($0 ?? "").isEmpty == false }
    }
}

struct ExitJob: Codable {
    var id: String?
    var symbol: String?
    var status: String?
    var updatedAt: String?
    var entryId: String?
    var profitId: String?
    var stopId: String?
    var comboId: String?
    var dueAt: String?
    var entryFilledAt: String?
    @LenientDouble var entryFilledQuantity: Double?
    @LenientDouble var bracketFilledQuantity: Double?
    @LenientDouble var remainingQuantity: Double?
    @LenientDouble var quantity: Double?
    var lastError: String?
    var nextCheckAt: String?
    var entrySubmissionError: String?
    var orderSnapshots: [String: OrderSnapshot]?
    var marketOrders: [MarketOrderAttempt]?
}

struct OrderSnapshot: Codable {
    var status: String?
    @LenientDouble var filledQuantity: Double?
}

struct MarketOrderAttempt: Codable {
    var id: String?
    @LenientDouble var quantity: Double?
    var status: String?
    @LenientDouble var filledQuantity: Double?
}

// MARK: - Account

/// GET /api/trading/account
struct AccountResponse: Codable {
    var accountNumber: String?
    var currency: String?
    @LenientDouble var totalValue: Double?
    @LenientDouble var cash: Double?
    @LenientDouble var buyingPower: Double?
    var positions: [Position]?
    var asOf: String?
}

struct Position: Codable, Identifiable {
    var symbol: String?
    @LenientDouble var quantity: Double?
    @LenientDouble var avgCost: Double?
    @LenientDouble var marketPrice: Double?
    @LenientDouble var marketValue: Double?
    @LenientDouble var unrealizedPnl: Double?
    @LenientDouble var unrealizedPnlPct: Double?

    var id: String { symbol ?? UUID().uuidString }
}

// MARK: - Orders

/// GET /api/trading/orders
struct OrdersResponse: Codable {
    var orders: [OrderRecord]?
    var asOf: String?
}

struct OrderRecord: Codable, Identifiable {
    var orderId: String?
    var clientOrderId: String?
    var symbol: String?
    var side: String?
    var orderType: String?
    @LenientDouble var quantity: Double?
    @LenientDouble var limitPrice: Double?
    var status: String?
    @LenientDouble var filledQuantity: Double?
    var createdAt: String?
    var source: String?

    var id: String { orderId ?? clientOrderId ?? UUID().uuidString }
}

// MARK: - Order preview / submit

/// POST /api/trading/orders/preview — request body.
struct OrderPreviewRequest: Codable {
    var symbol: String
    var side: String        // "buy" | "sell"
    var orderType: String   // "market" | "limit"
    @LenientDouble var quantity: Double?
    @LenientDouble var limitPrice: Double?
}

/// POST /api/trading/orders — request body (preview fields + confirm).
struct OrderSubmitRequest: Codable {
    var symbol: String
    var side: String
    var orderType: String
    @LenientDouble var quantity: Double?
    @LenientDouble var limitPrice: Double?
    var confirm: Bool

    init(preview: OrderPreviewRequest) {
        self.symbol = preview.symbol
        self.side = preview.side
        self.orderType = preview.orderType
        self.quantity = preview.quantity
        self.limitPrice = preview.limitPrice
        self.confirm = true
    }
}

/// POST /api/trading/orders/preview — response.
struct OrderPreviewResponse: Codable {
    var ok: Bool?
    var symbol: String?
    var side: String?
    var orderType: String?
    @LenientDouble var quantity: Double?
    @LenientDouble var limitPrice: Double?
    @LenientDouble var referencePrice: Double?
    @LenientDouble var estimatedNotional: Double?
    @LenientDouble var maxNotionalUsd: Double?
    var withinNotionalCap: Bool?
    var marketOpen: Bool?
    var dryRun: Bool?
    var checks: [PreviewCheck]?
    var warnings: [String]?
}

struct PreviewCheck: Codable {
    var name: String?
    var passed: Bool?
    var detail: String?
}

/// POST /api/trading/orders — response.
struct OrderSubmitResponse: Codable {
    var dryRun: Bool?
    var status: String?
    var orderId: String?
    var clientOrderId: String?
    var preview: OrderPreviewResponse?
    var message: String?
}