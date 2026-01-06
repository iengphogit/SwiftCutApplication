package space.iengpho.kmm.swiftcut.feature.app

import space.iengpho.shared.schedule.model.ScheduleHighlight

data class AppState(
    val showContent: Boolean = false,
    val highlight: ScheduleHighlight? = null,
)

sealed interface AppIntent {
    data object ToggleClicked : AppIntent
}
