package com.jetbrains.kmt.benchmark

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform