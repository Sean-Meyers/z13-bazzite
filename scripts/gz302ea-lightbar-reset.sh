#!/bin/bash
# Unbind/rebind the N-KEY Device (0B05:18C6) from the asus HID driver
# so the lightbar accepts direct HID commands.
# This is needed because asusd grabs exclusive access on boot.

DEV=$(ls /sys/bus/hid/drivers/asus/ 2>/dev/null | grep "0B05:18C6" | head -1)

if [ -z "$DEV" ]; then
    echo "gz302ea-lightbar-reset: N-KEY device not found, skipping"
    exit 0
fi

echo "gz302ea-lightbar-reset: Unbinding $DEV from asus driver"
echo "$DEV" > /sys/bus/hid/drivers/asus/unbind
sleep 0.5
echo "gz302ea-lightbar-reset: Rebinding $DEV to asus driver"
echo "$DEV" > /sys/bus/hid/drivers/asus/bind
sleep 0.5
echo "gz302ea-lightbar-reset: Done"
