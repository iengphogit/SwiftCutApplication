package space.iengpho.shared.time

expect class PlatformDateFormatter() {
    fun format(epochMillis: Long): String
}
