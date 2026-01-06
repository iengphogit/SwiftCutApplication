package space.iengpho.shared.schedule.model

data class Appointment(
    val id: String,
    val clientName: String,
    val serviceName: String,
    val scheduledAtMillis: Long,
    val status: AppointmentStatus,
)

enum class AppointmentStatus {
    Requested,
    Confirmed,
    Completed,
}
