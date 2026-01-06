package space.iengpho.shared.time

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

actual class PlatformDateFormatter actual constructor() {
    private val formatter = DateTimeFormatter
        .ofPattern("MMM d • h:mm a", Locale.getDefault())
        .withZone(ZoneId.systemDefault())

    actual fun format(epochMillis: Long): String {
        return formatter.format(Instant.ofEpochMilli(epochMillis))
    }
}
