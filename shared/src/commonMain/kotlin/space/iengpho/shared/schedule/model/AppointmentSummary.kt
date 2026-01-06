package space.iengpho.shared.schedule.model

data class AppointmentSummary(
    val id: String,
    val clientName: String,
    val serviceName: String,
    val scheduledTimeText: String,
    val status: AppointmentStatus,
)

data class ScheduleHighlight(
    val message: String,
    val items: List<AppointmentSummary>,
)
