package space.iengpho.shared.schedule.data

import space.iengpho.shared.schedule.domain.AppointmentRepository
import space.iengpho.shared.schedule.model.Appointment
import space.iengpho.shared.schedule.model.AppointmentStatus
import space.iengpho.shared.time.PlatformClock

class InMemoryAppointmentRepository(
    private val clock: PlatformClock = PlatformClock(),
) : AppointmentRepository {
    override fun fetchUpcoming(): List<Appointment> {
        val baseTime = clock.now()
        return listOf(
            Appointment(
                id = "cut-${'$'}baseTime",
                clientName = "Alex I.",
                serviceName = "Skin Fade + Beard",
                scheduledAtMillis = baseTime + HOURS_2,
                status = AppointmentStatus.Confirmed,
            ),
            Appointment(
                id = "cut-${'$'}{baseTime + 1}",
                clientName = "Malena G.",
                serviceName = "Color Refresh",
                scheduledAtMillis = baseTime + HOURS_5,
                status = AppointmentStatus.Requested,
            ),
            Appointment(
                id = "cut-${'$'}{baseTime + 2}",
                clientName = "Jordan U.",
                serviceName = "Razor Fade",
                scheduledAtMillis = baseTime + HOURS_26,
                status = AppointmentStatus.Confirmed,
            ),
            Appointment(
                id = "cut-${'$'}{baseTime + 3}",
                clientName = "Lee S.",
                serviceName = "Kids Trim",
                scheduledAtMillis = baseTime + HOURS_30,
                status = AppointmentStatus.Completed,
            ),
        )
    }

    private companion object {
        private const val HOUR_MILLIS = 60 * 60 * 1000L
        private const val HOURS_2 = 2 * HOUR_MILLIS
        private const val HOURS_5 = 5 * HOUR_MILLIS
        private const val HOURS_26 = 26 * HOUR_MILLIS
        private const val HOURS_30 = 30 * HOUR_MILLIS
    }
}
