package space.iengpho.kmm.swiftcut

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform