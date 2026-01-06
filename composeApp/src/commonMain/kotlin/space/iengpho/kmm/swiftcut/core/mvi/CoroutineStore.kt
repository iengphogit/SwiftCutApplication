package space.iengpho.kmm.swiftcut.core.mvi

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

interface Store<S, I> {
    val state: StateFlow<S>
    fun dispatch(intent: I)
}

class CoroutineStore<S, I, A, E>(
    initialState: S,
    private val scope: CoroutineScope,
    private val intentToAction: (I) -> A,
    private val reducer: Reducer<S, A, E>,
    private val effectHandler: suspend (E) -> A?,
) : Store<S, I> {
    private val mutex = Mutex()
    private val _state = MutableStateFlow(initialState)
    override val state: StateFlow<S> = _state.asStateFlow()

    override fun dispatch(intent: I) {
        dispatchAction(intentToAction(intent))
    }

    private fun dispatchAction(action: A) {
        scope.launch {
            val effect = mutex.withLock {
                val next = reducer.reduce(_state.value, action)
                _state.value = next.state
                next.effect
            }

            if (effect == null) return@launch
            val followUpAction = effectHandler(effect)
            if (followUpAction != null) dispatchAction(followUpAction)
        }
    }
}
