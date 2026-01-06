package space.iengpho.kmm.swiftcut.feature.app

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import space.iengpho.shared.schedule.model.AppointmentStatus
import space.iengpho.shared.schedule.model.AppointmentSummary
import space.iengpho.shared.schedule.model.ScheduleHighlight

class AppReducerTest {
    @Test
    fun `toggle shows content and requests highlight once`() {
        val initial = AppState()

        val next1 = AppReducer.reduce(initial, AppAction.ToggleClicked)
        assertEquals(true, next1.state.showContent)
        assertNull(next1.state.highlight)
        assertEquals(AppEffect.LoadHighlight, next1.effect)

        val highlight = ScheduleHighlight(
            message = "Upcoming bookings (1)",
            items = listOf(
                AppointmentSummary(
                    id = "1",
                    clientName = "Test",
                    serviceName = "Fade",
                    scheduledTimeText = "Tomorrow",
                    status = AppointmentStatus.Confirmed,
                ),
            ),
        )

        val next2 = AppReducer.reduce(next1.state, AppAction.HighlightLoaded(highlight))
        assertEquals(true, next2.state.showContent)
        assertEquals(highlight, next2.state.highlight)
        assertNull(next2.effect)

        val next3 = AppReducer.reduce(next2.state, AppAction.ToggleClicked)
        assertEquals(false, next3.state.showContent)
        assertEquals(highlight, next3.state.highlight)
        assertNull(next3.effect)

        val next4 = AppReducer.reduce(next3.state, AppAction.ToggleClicked)
        assertEquals(true, next4.state.showContent)
        assertEquals(highlight, next4.state.highlight)
        assertNull(next4.effect)
    }
}
