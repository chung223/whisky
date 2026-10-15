import CoreGraphics
import Darwin
import Synchronization

/// Hides the pointer while a synthetic ⌘-drag moves it, so the user doesn't see it jump to Whisky's icon and back.
///
/// `CGDisplayHideCursor` is ignored for an app that isn't active (Whisky never is) unless its window server
/// connection has the private `SetsCursorInBackground` property. The functions are looked up at run time: if they
/// are gone, hiding is simply a no-op and the pointer is still put back where it was.
final class CursorConcealment: Sendable {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static let allowedInBackground: Bool = {
        guard let mainSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSMainConnectionID"),
              let setSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetConnectionProperty")
        else {
            Log.write("cursor: CGS functions not found; the pointer stays visible during moves")
            return false
        }
        let mainConnection = unsafeBitCast(mainSymbol, to: MainConnectionID.self)
        let setProperty = unsafeBitCast(setSymbol, to: SetConnectionProperty.self)
        let connection = mainConnection()
        let status = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        if status != 0 { Log.write("cursor: SetsCursorInBackground failed (\(status))") }
        return status == 0
    }()

    private let ended = Mutex(false)

    private init() {}

    static func begin() -> CursorConcealment {
        _ = allowedInBackground
        CGDisplayHideCursor(CGMainDisplayID())
        return CursorConcealment()
    }

    /// Puts the pointer at `point` while still hidden, then shows it. Only the first call does anything.
    func end(warpingTo point: CGPoint?) {
        let first = ended.withLock { done in
            defer { done = true }
            return !done
        }
        guard first else { return }
        if let point { CGWarpMouseCursorPosition(point) }
        CGDisplayShowCursor(CGMainDisplayID())
    }

    deinit { end(warpingTo: nil) }
}
