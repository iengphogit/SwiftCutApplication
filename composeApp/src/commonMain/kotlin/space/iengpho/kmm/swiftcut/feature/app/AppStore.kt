package space.iengpho.kmm.swiftcut.feature.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.CoroutineScope
import space.iengpho.kmm.swiftcut.Greeting
import space.iengpho.kmm.swiftcut.core.mvi.CoroutineStore
import space.iengpho.kmm.swiftcut.core.mvi.Store

fun interface GreetingProvider {
    suspend fun getGreeting(): String
}

fun createAppStore(
    scope: CoroutineScope,
    greetingProvider: GreetingProvider,
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
                AppEffect.LoadGreeting -> {
                    val greeting = greetingProvider.getGreeting()
                    AppAction.GreetingLoaded(greeting)
                }
            }
        },
    )
}

@Composable
fun rememberAppStore(
    greetingProvider: GreetingProvider = remember { GreetingProvider { Greeting().greet() } },
): Store<AppState, AppIntent> {
    val scope = rememberCoroutineScope()
    return remember(scope, greetingProvider) {
        createAppStore(
            scope = scope,
            greetingProvider = greetingProvider,
        )
    }
}
