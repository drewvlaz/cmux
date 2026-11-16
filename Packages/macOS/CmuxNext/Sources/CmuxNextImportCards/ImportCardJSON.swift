import AppKit
import CmuxNextImportSuggestions
import CmuxNextSettings

/// A card list as the web surfaces read it (Settings' host lists `import_suggestions`,
/// `import.list`): the Codable cards, each with its source app's icon as a small
/// `data:image/png` URL (a cmux page's CSP allows `img-src data:` only).
@MainActor
struct ImportCardJSON {
    /// Null for an empty list: the surface draws nothing and keeps no room. A card's `icon` is its app's icon from
    /// `icons` when it is rendered (never rendered here); nil `icons` adds none.
    static func value(_ list: ImportCardList, icons: ImportAppIconCache?, keepEmpty: Bool = false) -> JSONValue {
        withIcons(encoded(list, keepEmpty: keepEmpty), icons: icons)
    }

    /// `list` as JSON, without icons: null when empty, unless `keepEmpty`.
    static func encoded(_ list: ImportCardList, keepEmpty: Bool) -> JSONValue {
        guard keepEmpty || !list.cards.isEmpty, let data = try? JSONEncoder().encode(list),
              let object = try? JSONSerialization.jsonObject(with: data), let value = JSONValue(foundation: object) else { return .null }
        return value
    }

    /// ``encoded(_:keepEmpty:)``'s value with each card's app icon that `icons` has rendered.
    static func withIcons(_ encoded: JSONValue, icons: ImportAppIconCache?) -> JSONValue {
        var value = encoded
        if let icons, case .object(var members) = value, case .array(let cards) = members["cards"] {
            members["cards"] = .array(cards.map { card in
                guard case .object(var fields) = card, let app = fields["app"]?.stringValue, let icon = icons.url(app) else { return card }
                fields["icon"] = .string(icon)
                return .object(fields)
            })
            value = .object(members)
        }
        return value
    }

    /// The list as JSON text (`import.list`'s `cards` field).
    static func text(_ list: ImportCardList) -> String {
        value(list, icons: nil).compactText
    }
}
