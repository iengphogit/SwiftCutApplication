package space.iengpho.kmm.swiftcut.feature.app

data class AppState(
    val showContent: Boolean = false,
    val greeting: String? = null,
)

sealed interface AppIntent {
    data object ToggleClicked : AppIntent
}
