package ru.kiper.android.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Analytics
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.delay
import ru.kiper.android.KiperApp
import ru.kiper.android.data.AppStore
import ru.kiper.android.ui.analytics.AnalyticsScreen
import ru.kiper.android.ui.home.HomeScreen
import ru.kiper.android.ui.home.PaymentsSheet
import ru.kiper.android.ui.settings.SettingsScreen
import ru.kiper.android.ui.subs.AddSubscriptionSheet
import ru.kiper.android.ui.subs.SubscriptionDetailScreen
import ru.kiper.android.ui.subs.SubscriptionsListScreen

val LocalAppStore = compositionLocalOf<AppStore> { error("AppStore not provided") }

/** Top-level tabs, mirroring `RootTabView`. */
private data class Tab(val route: String, val title: String, val icon: ImageVector)

private val tabs = listOf(
    Tab("home", "Главная", Icons.Rounded.Home),
    Tab("analytics", "Аналитика", Icons.Rounded.Analytics),
    Tab("settings", "Настройки", Icons.Rounded.Settings),
)

@Composable
fun AppRoot(deepLinkSubscriptionId: String?) {
    val store = KiperApp.store
    val navController = rememberNavController()
    var showPayments by remember { mutableStateOf(false) }
    var showAdd by remember { mutableStateOf(false) }

    var toastVisible by remember { mutableStateOf(false) }
    var toastText by remember { mutableStateOf("") }
    var toastError by remember { mutableStateOf(false) }
    LaunchedEffect(store.toast.value) {
        val t = store.toast.value ?: return@LaunchedEffect
        toastText = t.text
        toastError = t.isError
        toastVisible = true
        delay(2_400)
        toastVisible = false
    }

    LaunchedEffect(deepLinkSubscriptionId) {
        val id = deepLinkSubscriptionId ?: return@LaunchedEffect
        navController.navigate("detail/$id")
    }

    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showBar = currentRoute in tabs.map { it.route }

    androidx.compose.runtime.CompositionLocalProvider(LocalAppStore provides store) {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            bottomBar = {
                AnimatedVisibility(visible = showBar, enter = fadeIn(), exit = fadeOut()) {
                    NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainer) {
                        for (tab in tabs) {
                            NavigationBarItem(
                                selected = currentRoute == tab.route,
                                onClick = {
                                    navController.navigate(tab.route) {
                                        popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                },
                                icon = { Icon(tab.icon, contentDescription = tab.title) },
                                label = { Text(tab.title) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = MaterialTheme.colorScheme.primary,
                                    selectedTextColor = MaterialTheme.colorScheme.primary,
                                    indicatorColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                                ),
                            )
                        }
                    }
                }
            },
        ) { padding ->
            NavHost(
                navController = navController,
                startDestination = "home",
                modifier = Modifier.padding(padding),
                // Snappy crossfade: the default 700 ms fade with a delay makes the
                // previous screen linger over the new one.
                enterTransition = { androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(160)) },
                exitTransition = { androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(160)) },
                popEnterTransition = { androidx.compose.animation.fadeIn(androidx.compose.animation.core.tween(160)) },
                popExitTransition = { androidx.compose.animation.fadeOut(androidx.compose.animation.core.tween(160)) },
            ) {
                composable("home") {
                    HomeScreen(
                        onOpenList = { navController.navigate("list") },
                        onOpenDetail = { navController.navigate("detail/$it") },
                        onAdd = { showAdd = true },
                        onOpenPayments = { showPayments = true },
                    )
                }
                composable("list") {
                    SubscriptionsListScreen(
                        onBack = { navController.popBackStack() },
                        onOpenDetail = { navController.navigate("detail/$it") },
                        onAdd = { showAdd = true },
                    )
                }
                composable("detail/{id}") { entry ->
                    SubscriptionDetailScreen(
                        subscriptionId = entry.arguments?.getString("id") ?: "",
                        onBack = { navController.popBackStack() },
                    )
                }
                composable("analytics") { AnalyticsScreen() }
                composable("settings") { SettingsScreen() }
            }
        }

        if (showPayments) {
            PaymentsSheet(onDismiss = { showPayments = false })
        }
        if (showAdd) {
            AddSubscriptionSheet(onDismiss = { showAdd = false })
        }

        // Toast overlay on top of everything.
        AnimatedVisibility(visible = toastVisible, enter = fadeIn(), exit = fadeOut()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                Box(
                    Modifier
                        .padding(top = 60.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(
                            if (toastError) MaterialTheme.colorScheme.error
                            else MaterialTheme.colorScheme.surfaceContainerHigh
                        )
                        .padding(horizontal = 18.dp, vertical = 12.dp),
                ) {
                    Text(
                        toastText,
                        color = if (toastError) MaterialTheme.colorScheme.onError else MaterialTheme.colorScheme.onSurface,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
    }
}
