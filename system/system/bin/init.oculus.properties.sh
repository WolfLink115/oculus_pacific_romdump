#!/system/bin/sh
set -o errexit
set -o nounset

# this script initializes various read-only properties based
# on runtime boot state

if [ -f /sys/bus/soc/devices/soc0/machine ]; then
  setprop ro.chipname `cat /sys/bus/soc/devices/soc0/machine`
fi

if [ -f /sys/devices/virtual/graphics/fb0/msm_fb_panel_info ]; then
  panel_name=`cat /sys/devices/virtual/graphics/fb0/msm_fb_panel_info | grep panel_name | cut -d= -f 2`
fi

if [ -d /sys/bus/scsi/devices/0\:0\:0\:0 ]; then
  nand_type=`cat /sys/bus/scsi/devices/0\:0\:0\:0/model`
fi

case "${panel_name:=unknown}" in
  "Dual Samsung"*)
    panel_type=SDC
    ;;
  "Dual AUO"*)
    panel_type=AUO
    ;;
  "jdi 2k"*)
    panel_type=JDI
    ;;
  "boe 2k"*)
    panel_type=BOE
    ;;
  *)
    panel_type=unknown
    ;;
esac

product_device=`getprop ro.product.device`

setprop ro.product.variant "${product_device}:${panel_type}:${nand_type:=unknown}"
