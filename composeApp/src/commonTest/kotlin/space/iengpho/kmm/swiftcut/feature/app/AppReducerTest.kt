package space.iengpho.kmm.swiftcut.feature.app

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AppReducerTest {
    @Test
    fun `toggle shows content and requests greeting once`() {
        val initial = AppState()

        val next1 = AppReducer.reduce(initial, AppAction.ToggleClicked)
        assertEquals(true, next1.state.showContent)
        assertNull(next1.state.greeting)
        assertEquals(AppEffect.LoadGreeting, next1.effect)

        val next2 = AppReducer.reduce(next1.state, AppAction.GreetingLoaded("Hello"))
        assertEquals(true, next2.state.showContent)
        assertEquals("Hello", next2.state.greeting)
        assertNull(next2.effect)

        val next3 = AppReducer.reduce(next2.state, AppAction.ToggleClicked)
        assertEquals(false, next3.state.showContent)
        assertEquals("Hello", next3.state.greeting)
        assertNull(next3.effect)

        val next4 = AppReducer.reduce(next3.state, AppAction.ToggleClicked)
        assertEquals(true, next4.state.showContent)
        assertEquals("Hello", next4.state.greeting)
        assertNull(next4.effect)
    }
}
