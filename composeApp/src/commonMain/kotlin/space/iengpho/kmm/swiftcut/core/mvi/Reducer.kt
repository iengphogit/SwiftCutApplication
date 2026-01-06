package space.iengpho.kmm.swiftcut.core.mvi

fun interface Reducer<S, A, E> {
    fun reduce(state: S, action: A): Next<S, E>
}
