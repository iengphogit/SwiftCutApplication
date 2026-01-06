package space.iengpho.kmm.swiftcut.feature.app

import space.iengpho.kmm.swiftcut.core.mvi.Next
import space.iengpho.kmm.swiftcut.core.mvi.Reducer

internal sealed interface AppAction {
    data object ToggleClicked : AppAction
    data class GreetingLoaded(val greeting: String) : AppAction
}

internal sealed interface AppEffect {
    data object LoadGreeting : AppEffect
}

internal object AppReducer : Reducer<AppState, AppAction, AppEffect> {
    override fun reduce(state: AppState, action: AppAction): Next<AppState, AppEffect> {
        return when (action) {
            AppAction.ToggleClicked -> {
                val nextShow = !state.showContent
                val shouldLoadGreeting = nextShow && state.greeting == null
                Next(
                    state = state.copy(showContent = nextShow),
                    effect = if (shouldLoadGreeting) AppEffect.LoadGreeting else null,
                )
            }

            is AppAction.GreetingLoaded -> {
                Next(state = state.copy(greeting = action.greeting))
            }
        }
    }
}
