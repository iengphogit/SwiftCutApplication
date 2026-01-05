package space.iengpho.coolcut

class Greeting {
    private val platform = getPlatform()

    fun greet(): String {
        return "I Hello, ${platform.name}!"
    }
}