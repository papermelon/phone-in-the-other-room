package com.ngawangchime.countingsheep.prototype

import android.app.Activity
import android.os.Bundle
import android.widget.Button

/** Test APK only: no extra application module or release feature. */
class TestTargetActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(Button(this).apply {
            text = "Isolated target interaction"
            setOnClickListener { text = "TARGET WAS TAPPED" }
        })
    }
}
