package space.iengpho.shared.time

import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter
import platform.Foundation.NSLocale
import platform.Foundation.NSTimeZone
import platform.Foundation.currentLocale
import platform.Foundation.dateWithTimeIntervalSince1970
import platform.Foundation.localTimeZone

actual class PlatformDateFormatter actual constructor() {
    private val formatter: NSDateFormatter = NSDateFormatter().apply {
        dateFormat = "MMM d • h:mm a"
        locale = NSLocale.currentLocale
        timeZone = NSTimeZone.localTimeZone
    }

    actual fun format(epochMillis: Long): String {
        val date = NSDate.dateWithTimeIntervalSince1970(epochMillis.toDouble() / 1000.0)
        return formatter.stringFromDate(date)
    }
}
