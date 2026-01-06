package space.iengpho.shared.schedule.domain

import space.iengpho.shared.schedule.model.AppointmentSummary

class GetUpcomingAppointmentsUseCase(
    private val repository: AppointmentRepository,
    private val formatter: AppointmentFormatter = AppointmentFormatter(),
) {
    fun execute(limit: Int = DEFAULT_LIMIT): List<AppointmentSummary> {
        return repository
            .fetchUpcoming()
            .sortedBy { it.scheduledAtMillis }
            .take(limit)
            .map(formatter::toSummary)
    }

    companion object {
        private const val DEFAULT_LIMIT = 3
    }
}
