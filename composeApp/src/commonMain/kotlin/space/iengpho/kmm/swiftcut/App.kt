package space.iengpho.kmm.swiftcut

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import org.jetbrains.compose.ui.tooling.preview.Preview
import space.iengpho.kmm.swiftcut.feature.app.AppScreen
import space.iengpho.kmm.swiftcut.feature.app.ScheduleHighlightProvider
import space.iengpho.kmm.swiftcut.feature.app.rememberAppStore
import space.iengpho.shared.schedule.AppointmentScheduleFacade
import space.iengpho.shared.schedule.createDefaultScheduleFacade

@Composable
@Preview
fun App(
    scheduleHighlightProvider: ScheduleHighlightProvider = rememberScheduleHighlightProvider(),
) {
    MaterialTheme {
        AppScreen(store = rememberAppStore(scheduleHighlightProvider))
    }
}

@Composable
fun rememberScheduleHighlightProvider(
    facadeFactory: () -> AppointmentScheduleFacade = { createDefaultScheduleFacade() },
): ScheduleHighlightProvider {
    val facade = remember(facadeFactory) { facadeFactory() }
    return remember(facade) { ScheduleHighlightProvider { facade.highlight() } }
}
