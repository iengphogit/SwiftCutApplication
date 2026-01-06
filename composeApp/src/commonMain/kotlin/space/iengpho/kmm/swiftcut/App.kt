package space.iengpho.kmm.swiftcut

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import org.jetbrains.compose.ui.tooling.preview.Preview
import space.iengpho.kmm.swiftcut.feature.app.AppScreen
import space.iengpho.kmm.swiftcut.feature.app.rememberAppStore

@Composable
@Preview
fun App() {
    MaterialTheme {
        AppScreen(store = rememberAppStore())
    }
}
