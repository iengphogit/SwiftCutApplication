package space.iengpho.kmm.swiftcut.core.mvi

data class Next<S, E>(
    val state: S,
    val effect: E? = null,
)
