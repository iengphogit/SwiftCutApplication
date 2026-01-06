package space.iengpho.shared.schedule

import space.iengpho.shared.schedule.data.InMemoryAppointmentRepository
import space.iengpho.shared.schedule.domain.GetUpcomingAppointmentsUseCase
import space.iengpho.shared.schedule.model.ScheduleHighlight

class AppointmentScheduleFacade(
    private val useCase: GetUpcomingAppointmentsUseCase,
) {
    fun highlight(limit: Int = HIGHLIGHT_LIMIT): ScheduleHighlight {
        val items = useCase.execute(limit)
        val message = if (items.isEmpty()) {
            "No bookings scheduled"
        } else {
            "Upcoming bookings (${ '$' }{items.size})"
        }
        return ScheduleHighlight(message = message, items = items)
    }

    fun highlightHeadline(limit: Int = HIGHLIGHT_LIMIT): String = highlight(limit).message

    private companion object {
        private const val HIGHLIGHT_LIMIT = 3
    }
}

fun createDefaultScheduleFacade(): AppointmentScheduleFacade {
    return AppointmentScheduleFacade(
        useCase = GetUpcomingAppointmentsUseCase(
            repository = InMemoryAppointmentRepository(),
        ),
    )
}

object SharedScheduleModule {
    fun facade(): AppointmentScheduleFacade = createDefaultScheduleFacade()
}
