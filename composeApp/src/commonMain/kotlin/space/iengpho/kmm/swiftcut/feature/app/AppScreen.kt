package space.iengpho.kmm.swiftcut.feature.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import space.iengpho.kmm.swiftcut.core.mvi.Store
import space.iengpho.kmm.swiftcut.generated.resources.Res
import space.iengpho.kmm.swiftcut.generated.resources.compose_multiplatform

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
            val greeting = state.greeting
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Image(painterResource(Res.drawable.compose_multiplatform), null)
                Text(
                    text = if (greeting != null) {
                        "Compose: $greeting"
                    } else {
                        "Loading…"
                    },
                )
            }
        }
    }
}
