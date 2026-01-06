package space.iengpho.shared.time

import platform.Foundation.NSDate
import platform.Foundation.timeIntervalSince1970

actual class PlatformClock actual constructor() {
    actual fun now(): Long = (NSDate().timeIntervalSince1970 * 1000.0).toLong()
}
