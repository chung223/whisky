import CoreGraphics
import Testing
@testable import WhiskyCore

@Suite("Popup detection")
struct PopupDetectionTests {
    private let statusLevel = 25

    private func detect(_ windows: [PopupDetection.Window], excluding: Int32? = nil) -> [UInt32] {
        PopupDetection.popups(among: windows, itemMidX: 1200, menuBarHeight: 32, statusLevel: statusLevel, excludingPID: excluding).map(\.id)
    }

    @Test("A dropdown under the item, from any process, counts")
    func dropdown() {
        let dropdown = PopupDetection.Window(id: 1, pid: 900, layer: 101, frame: CGRect(x: 1000, y: 34, width: 320, height: 400))
        #expect(detect([dropdown]) == [1])
    }

    @Test("Status items, tiny windows and windows far down or far away don't")
    func noise() {
        let statusItem = PopupDetection.Window(id: 2, pid: 900, layer: statusLevel, frame: CGRect(x: 1180, y: 0, width: 32, height: 32))
        let sliver = PopupDetection.Window(id: 3, pid: 900, layer: 101, frame: CGRect(x: 1190, y: 0, width: 20, height: 1))
        let document = PopupDetection.Window(id: 4, pid: 900, layer: 0, frame: CGRect(x: 1000, y: 300, width: 600, height: 400))
        let farLeft = PopupDetection.Window(id: 5, pid: 900, layer: 101, frame: CGRect(x: 10, y: 34, width: 200, height: 200))
        #expect(detect([statusItem, sliver, document, farLeft]).isEmpty)
    }

    @Test("Whisky's own windows don't count")
    func ownWindows() {
        let panel = PopupDetection.Window(id: 6, pid: 42, layer: 27, frame: CGRect(x: 1000, y: 0, width: 380, height: 300))
        #expect(detect([panel], excluding: 42).isEmpty)
    }
}
