package space.iengpho.kmm.swiftcut.feature.app

import space.iengpho.kmm.swiftcut.core.mvi.Next
import space.iengpho.kmm.swiftcut.core.mvi.Reducer
import space.iengpho.shared.schedule.model.ScheduleHighlight

internal sealed interface AppAction {
    data object ToggleClicked : AppAction
    data class HighlightLoaded(val highlight: ScheduleHighlight) : AppAction
}

internal sealed interface AppEffect {
    data object LoadHighlight : AppEffect
}

internal object AppReducer : Reducer<AppState, AppAction, AppEffect> {
    override fun reduce(state: AppState, action: AppAction): Next<AppState, AppEffect> {
        return when (action) {
            AppAction.ToggleClicked -> {
                val nextShow = !state.showContent
                val shouldLoadContent = nextShow && state.highlight == null
                Next(
                    state = state.copy(showContent = nextShow),
                    effect = if (shouldLoadContent) AppEffect.LoadHighlight else null,
                )
            }

            is AppAction.HighlightLoaded -> {
                Next(state = state.copy(highlight = action.highlight))
            }
        }
    }
}
