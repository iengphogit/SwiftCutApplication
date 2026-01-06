package space.iengpho.shared.schedule.domain

import space.iengpho.shared.schedule.model.Appointment
import space.iengpho.shared.schedule.model.AppointmentSummary
import space.iengpho.shared.time.PlatformDateFormatter

class AppointmentFormatter(
    private val dateFormatter: PlatformDateFormatter = PlatformDateFormatter(),
) {
    fun toSummary(appointment: Appointment): AppointmentSummary {
        return AppointmentSummary(
            id = appointment.id,
            clientName = appointment.clientName,
            serviceName = appointment.serviceName,
            scheduledTimeText = dateFormatter.format(appointment.scheduledAtMillis),
            status = appointment.status,
        )
    }
}
