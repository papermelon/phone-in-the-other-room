package com.ngawangchime.countingsheep.prototype.platform

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.telecom.TelecomManager

data class SelectableApp(val packageName: String, val label: String)

object AppSelection {
    fun launchable(context: Context): List<SelectableApp> {
        val manager = context.packageManager
        val dialer = context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        val homes = manager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .map { it.activityInfo.packageName }.toSet()
        return manager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .filter { it.activityInfo.packageName != context.packageName && it.activityInfo.packageName != dialer && it.activityInfo.packageName !in homes &&
                it.activityInfo.applicationInfo.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0 }
            .map { SelectableApp(it.activityInfo.packageName, it.loadLabel(manager).toString()) }
            .distinctBy { it.packageName }.sortedBy { it.label.lowercase() }
    }
}
