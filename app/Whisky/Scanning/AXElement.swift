import ApplicationServices
import CoreGraphics

/// A Sendable handle to an AXUIElement. AX calls may be made from any thread; the reference itself
/// carries no state, so sharing it across threads is safe.
struct AXElement: @unchecked Sendable {
    let raw: AXUIElement

    static func application(_ pid: pid_t) -> AXElement {
        AXElement(raw: AXUIElementCreateApplication(pid))
    }

    /// Applies to calls made through this element only, so set it on every element you query.
    func setTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(raw, seconds)
    }

    func copy(_ attribute: String) -> (error: AXError, value: CFTypeRef?) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        return (error, value)
    }

    func value(_ attribute: String) -> CFTypeRef? {
        let result = copy(attribute)
        return result.error == .success ? result.value : nil
    }

    func string(_ attribute: String) -> String? {
        guard let string = value(attribute) as? String, !string.isEmpty else { return nil }
        return string
    }

    func bool(_ attribute: String) -> Bool? { value(attribute) as? Bool }

    func int(_ attribute: String) -> Int? { value(attribute) as? Int }

    func element(_ attribute: String) -> AXElement? { Self.element(from: value(attribute)) }

    func elements(_ attribute: String) -> [AXElement] {
        guard let array = value(attribute) as? [AnyObject] else { return [] }
        return array.compactMap { Self.element(from: $0) }
    }

    var children: [AXElement] { elements("AXChildren") }

    var role: String? { string("AXRole") }

    var frame: CGRect? {
        guard let position = value("AXPosition"), let size = value("AXSize"),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent)
        else { return nil }
        return CGRect(origin: point, size: extent)
    }

    var actionNames: [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(raw, &names) == .success, let names = names as? [String] else { return [] }
        return names
    }

    @discardableResult
    func perform(_ action: String) -> AXError {
        AXUIElementPerformAction(raw, action as CFString)
    }

    private static func element(from value: CFTypeRef?) -> AXElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(raw: value as! AXUIElement)
    }
}
