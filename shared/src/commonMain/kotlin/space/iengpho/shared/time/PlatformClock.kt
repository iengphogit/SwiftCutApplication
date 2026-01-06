package space.iengpho.shared.time

expect class PlatformClock() {
    fun now(): Long
}
