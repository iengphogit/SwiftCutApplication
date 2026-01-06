package space.iengpho.kmm.swiftcut.feature.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.CoroutineScope
import space.iengpho.kmm.swiftcut.core.mvi.CoroutineStore
import space.iengpho.kmm.swiftcut.core.mvi.Store
import space.iengpho.shared.schedule.model.ScheduleHighlight

fun interface ScheduleHighlightProvider {
    suspend fun getHighlight(): ScheduleHighlight
}

fun createAppStore(
    scope: CoroutineScope,
    scheduleHighlightProvider: ScheduleHighlightProvider,
): Store<AppState, AppIntent> {
    return CoroutineStore(
        initialState = AppState(),
        scope = scope,
        intentToAction = { intent ->
            when (intent) {
                AppIntent.ToggleClicked -> AppAction.ToggleClicked
            }
        },
        reducer = AppReducer,
        effectHandler = { effect ->
            when (effect) {
                AppEffect.LoadHighlight -> {
                    val highlight = scheduleHighlightProvider.getHighlight()
                    AppAction.HighlightLoaded(highlight)
                }
            }
        },
    )
}

@Composable
fun rememberAppStore(
    scheduleHighlightProvider: ScheduleHighlightProvider,
): Store<AppState, AppIntent> {
    val scope = rememberCoroutineScope()
    return remember(scope, scheduleHighlightProvider) {
        createAppStore(
            scope = scope,
            scheduleHighlightProvider = scheduleHighlightProvider,
        )
    }
}
