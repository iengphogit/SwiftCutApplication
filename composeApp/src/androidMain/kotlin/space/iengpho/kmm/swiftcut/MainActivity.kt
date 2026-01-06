package space.iengpho.kmm.swiftcut

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import space.iengpho.kmm.swiftcut.feature.app.ScheduleHighlightProvider
import space.iengpho.shared.schedule.AppointmentScheduleFacade
import space.iengpho.shared.schedule.createDefaultScheduleFacade

class MainActivity : ComponentActivity() {
    private val scheduleFacade: AppointmentScheduleFacade by lazy {
        createDefaultScheduleFacade()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        setContent {
            App(
                scheduleHighlightProvider = ScheduleHighlightProvider { scheduleFacade.highlight() },
            )
        }
    }
}

@Preview
@Composable
fun AppAndroidPreview() {
    App()
}
