// WhiskyHolder: keeps macOS 27's menu bar restricted to the apps Whisky allows, for as long as it runs.
//
// The restriction (MenuBarClientCore's MBAssessmentModeAssertion, the private client behind the public "assessment
// mode" menu bar control) belongs to the process that activated it: when this process ends, for any reason, macOS
// shows the whole menu bar again. It lives in its own process because a process that has activated the restriction
// can't open Notification Center from the clock for the rest of its life, even after invalidating (measured by
// MenuTidy).
//
// Protocol, one line per request on stdin, one reply line on stdout ("ok" or "error: …"):
//   allow <bundle ID>…   restrict to these apps (system items always stay), replacing the previous list; on an
//                        error the whole menu bar shows
//   lift                 show the whole menu bar again
// Two restrictions active at once show the whole menu bar (measured on 27.2), so the previous one is lifted before
// the new one is activated; the menu bar shows everything for that moment.
// Ends when stdin closes or Whisky (its parent) is gone, which also lifts the restriction.
import Foundation
import ObjectiveC

setvbuf(stdout, nil, _IOLBF, 0)

guard dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil,
      let configClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
      let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type,
      configClass.instancesRespond(to: NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")),
      assertionClass.instancesRespond(to: NSSelectorFromString("activateWithConfiguration:completionHandler:")),
      assertionClass.instancesRespond(to: NSSelectorFromString("invalidate"))
else {
    print("error: MenuBarClientCore is not available")
    exit(1)
}

// Every system item stays (battery, Bluetooth, clock, displays, keyboard, volume, Wi-Fi, screen mirroring, Control
// Center): only third-party apps are restricted. The arrays must be NSArray (an NSSet crashes in -objectAtIndex:).
let systemItems = (0...8).map { NSNumber(value: $0) } as NSArray
var current: NSObject?

@MainActor
func activate(_ bundles: [String]) {
    current?.perform(NSSelectorFromString("invalidate"))
    current = nil
    let allocated = configClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue() as! NSObject
    let configuration = allocated.perform(NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:"),
                                          with: systemItems, with: bundles as NSArray).takeUnretainedValue()
    let assertion = assertionClass.init()
    let completion: @convention(block) (NSError?) -> Void = { error in
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if let error {
                    print("error: \(error.localizedDescription)")
                    return
                }
                current = assertion
                print("ok")
            }
        }
    }
    _ = assertion.perform(NSSelectorFromString("activateWithConfiguration:completionHandler:"), with: configuration,
                          with: unsafeBitCast(completion, to: AnyObject.self))
}

@MainActor
func handle(_ line: String) {
    let words = line.split(separator: " ").map(String.init)
    switch words.first {
    case "allow":
        activate(Array(words.dropFirst()))
    case "lift":
        current?.perform(NSSelectorFromString("invalidate"))
        current = nil
        print("ok")
    default:
        print("error: unknown request \(words.first ?? "")")
    }
}

Thread.detachNewThread {
    while let line = readLine() {
        DispatchQueue.main.async { MainActor.assumeIsolated { handle(line) } }
    }
    exit(0)
}
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
    if getppid() == 1 { exit(0) }
}
signal(SIGTERM) { _ in exit(0) }
RunLoop.main.run()
