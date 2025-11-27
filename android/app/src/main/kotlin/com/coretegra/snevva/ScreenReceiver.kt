package com.coretegra.snevva

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ScreenReceiver(private val callback: (String) -> Unit) : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SCREEN_OFF -> callback("screen_off")
            Intent.ACTION_SCREEN_ON -> callback("screen_on")
        }
    }
}