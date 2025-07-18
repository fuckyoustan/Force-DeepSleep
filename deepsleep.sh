#!/system/bin/sh

MODDIR=${0%/*}
LAST_STATE=""
WHITELIST_FILE="$MODDIR/whitelist.txt"
LOG_FILE="/storage/emulated/0/deepsleep.log"

#===== Get Screen State🔋 =====
get_screen_state() {
    dumpsys display | grep -iq "mScreenState=ON" && echo "on" || echo "off"
}

is_whitelisted() {
    pkg="$1"
    [ -f "$WHITELIST_FILE" ] || return 1
    grep -qx "$pkg" "$WHITELIST_FILE"
}

echo "=== Deep Sleep Enforcer Started ===" >> "$LOG_FILE"

#===== Main Loop🔋 =====
while true; do
    SCREEN_STATE=$(get_screen_state)
    
    if [ "$SCREEN_STATE" != "$LAST_STATE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [📲] Screen state changed to: $SCREEN_STATE" >> "$LOG_FILE"
        if [ "$SCREEN_STATE" = "off" ]; then
             # Enable all DeviceIdle restrictions (thx to @hoshiyomi_id)
             cmd deviceidle enable all && \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Enabled DeviceIdle (Doze) restrictions" >> "$LOG_FILE" || \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] Failed to enable DeviceIdle" >> "$LOG_FILE"
        
             # Force Quick Doze mode (skip motion checks)
             cmd deviceidle force-modemanager-quickdoze true && \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Forced Quick Doze mode" >> "$LOG_FILE" || \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] Failed to force Quick Doze" >> "$LOG_FILE"
        
             # Force Off-Body mode (simulate device not being carried)
             cmd deviceidle force-modemanager-offbody true && \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Forced Off-Body mode" >> "$LOG_FILE" || \
             echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] Failed to force Off-Body mode" >> "$LOG_FILE"

             # Set custom idle parameters (thx to @WeAreRavenS)
             settings put global device_idle_constants light_after_inactive_to=30000,light_pre_idle_to=35000,light_idle_to=30000,light_idle_factor=1.7,light_max_idle_to=50000,light_idle_maintenance_min_budget=28000,light_idle_maintenance_max_budget=300000,min_light_maintenance_time=5000,min_deep_maintenance_time=10000,inactive_to=30000,sensing_to=0,locating_to=0,location_accuracy=2000,motion_inactive_to=86400000,idle_after_inactive_to=0,idle_pending_to=30000,max_idle_pending_to=60000,idle_pending_factor=2.1,quick_doze_delay_to=60000,idle_to=3600000,max_idle_to=21600000,idle_factor=1.7,min_time_to_alarm=1800000,max_temp_app_whitelist_duration=20000,mms_temp_app_whitelist_duration=20000,sms_temp_app_whitelist_duration=10000,notification_whitelist_duration=20000,wait_for_unlock=true,pre_idle_factor_long=1.67,pre_idle_factor_short=0.33

             # Attempt to enforce deep sleep (best effort)
             echo "deep" > /sys/power/mem_sleep
             echo "mem" > /sys/power/state
             sync
             echo "3" > /proc/sys/vm/drop_caches
             
             pm list packages -3 | cut -f2 -d ':' | while read pkg; do
                 if ! is_whitelisted "$pkg"; then
                     am force-stop "$pkg"
                     echo "$(date '+%Y-%m-%d %H:%M:%S') - [KILL] $pkg" >> "$LOG_FILE"
                 else
                     echo "$(date '+%Y-%m-%d %H:%M:%S') - [SKIP] $pkg (whitelisted)" >> "$LOG_FILE"
                 fi
             done

             LAST_STATE="off"
        else
             LAST_STATE="on"
        fi
    fi
    
    sleep 5
done