import Foundation
import IOKit.pwr_mgt

final class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private var active = false

    func engage() {
        guard !active else { return }
        let result = IOPMAssertionCreateWithName(
            "PreventUserIdleSystemSleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Tether beacon active" as CFString,
            &assertionID
        )
        active = (result == kIOReturnSuccess)
    }

    func release() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        active = false
    }

    deinit { release() }
}
