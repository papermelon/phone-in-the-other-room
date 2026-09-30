package com.ngawangchime.countingsheep.prototype.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Android counterpart of the current Swift dark Farm palette; native scalable typography. */
object GuestSpace { val page = 24.dp; val card = 16.dp; val gap = 12.dp; val touch = 48.dp }
private val colors = darkColorScheme(
    background = Color(0.055f, 0.075f, 0.06f), surface = Color(0.12f, 0.15f, 0.12f),
    onBackground = Color(0.93f, 0.90f, 0.82f), onSurface = Color(0.93f, 0.90f, 0.82f),
    onSurfaceVariant = Color(0.72f, 0.70f, 0.64f), primary = Color(0.60f, 0.72f, 0.48f),
    surfaceContainer = Color(0.10f, 0.13f, 0.10f), surfaceContainerLow = Color(0.10f, 0.13f, 0.10f),
    surfaceContainerHigh = Color(0.12f, 0.15f, 0.12f), surfaceContainerHighest = Color(0.12f, 0.15f, 0.12f),
    secondaryContainer = Color(0.23f, 0.30f, 0.19f), onSecondaryContainer = Color(0.93f, 0.90f, 0.82f),
    outline = Color(0.40f, 0.43f, 0.35f),
    onPrimary = Color(0.055f, 0.075f, 0.06f), error = Color(1f, 0.48f, 0.43f)
)
@Composable fun GuestTheme(content: @Composable () -> Unit) { MaterialTheme(colorScheme = colors, content = content) }
