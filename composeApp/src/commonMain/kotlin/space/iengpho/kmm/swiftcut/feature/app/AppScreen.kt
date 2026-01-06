package space.iengpho.kmm.swiftcut.feature.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeContentPadding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.jetbrains.compose.resources.painterResource
import androidx.compose.ui.unit.dp
import space.iengpho.kmm.swiftcut.core.mvi.Store
import space.iengpho.kmm.swiftcut.generated.resources.Res
import space.iengpho.kmm.swiftcut.generated.resources.compose_multiplatform
import space.iengpho.shared.schedule.model.AppointmentSummary
import space.iengpho.shared.schedule.model.ScheduleHighlight

@Composable
fun AppScreen(
    store: Store<AppState, AppIntent>,
) {
    val state by store.state.collectAsState()

    Column(
        modifier = Modifier
            .background(MaterialTheme.colorScheme.primaryContainer)
            .safeContentPadding()
            .fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Button(onClick = { store.dispatch(AppIntent.ToggleClicked) }) {
            Text("Click me!")
        }
        AnimatedVisibility(state.showContent) {
            HighlightContent(
                highlight = state.highlight,
            )
        }
    }
}

@Composable
private fun HighlightContent(
    highlight: ScheduleHighlight?,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(painterResource(Res.drawable.compose_multiplatform), null)
        Spacer(modifier = Modifier.height(16.dp))
        if (highlight != null) {
            Text(text = highlight.message, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(16.dp))
            highlight.items.forEach { summary ->
                AppointmentSummaryCard(summary)
            }
        } else {
            Text("Loading…")
        }
    }
}

@Composable
private fun AppointmentSummaryCard(
    summary: AppointmentSummary,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = summary.clientName, style = MaterialTheme.typography.bodyLarge)
        Text(text = summary.serviceName, style = MaterialTheme.typography.bodyMedium)
        Text(text = summary.scheduledTimeText, style = MaterialTheme.typography.bodySmall)
        Spacer(modifier = Modifier.height(12.dp))
    }
}
