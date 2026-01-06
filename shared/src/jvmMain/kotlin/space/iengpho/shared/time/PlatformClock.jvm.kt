package space.iengpho.shared.time

actual class PlatformClock actual constructor() {
    actual fun now(): Long = System.currentTimeMillis()
}
