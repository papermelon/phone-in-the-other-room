package com.ngawangchime.countingsheep.prototype.platform

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.ngawangchime.countingsheep.prototype.PrototypeApplication

class BoundaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, "${context.packageName}.BOUNDARY")) return
        (context.applicationContext as PrototypeApplication).reconcile(intent.getStringExtra("occurrence"))
    }
}
