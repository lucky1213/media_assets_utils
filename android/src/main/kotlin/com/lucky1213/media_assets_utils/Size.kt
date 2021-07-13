package com.lucky1213.media_assets_utils

internal class Size(firstSize: Int, secondSize: Int) {
    val major: Int = firstSize.coerceAtLeast(secondSize)
    val minor: Int = firstSize.coerceAtMost(secondSize)

}