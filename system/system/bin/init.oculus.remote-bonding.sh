#!/system/bin/sh
set -o errexit
set -o nounset

# This script is used to store controller bonding information during manufacture and restore it
# during first boot.
#

TAG=init.oculus.remote-bonding.sh
PERSIST_PATH=/persist/remote_bonding/bt_config.conf
PAIRING_PATH=/persist/remote_pairing/factory_pairing.txt
DATA_PATH=/data/misc/bluedroid/bt_config.conf

STORE_BONDING_RESULT_PROP=mfg.oculus.remotebond.result
STORE_MAC_RESULT_PROP=mfg.oculus.remotebond.mac

# Restore remote bonding state that is store in PERSIST_PATH to the runtime location DATA_PATH.
# This must be run before the bluetooth service starts, since it will be read during bluetooth
# service init.
#
# This script is expected to be run during early-boot, which is before the bluetooth
# service is started by activity manager.  It it also expected that the path /data/misc/bluedroid/
# has been created and has the appropriate permissions before this script is run.
#
restore_factory_bonding()
{
    log -t $TAG Restoring factory bonding
    if [ ! -e $DATA_PATH ]; then
        if [ -e $PERSIST_PATH ]; then
            log -t $TAG Attempting to deploy controller bonding information
            if cp $PERSIST_PATH $DATA_PATH; then
              chmod 0660 $DATA_PATH
              chown bluetooth $DATA_PATH
              chgrp net_bt_stack $DATA_PATH
              log -p i -t $TAG Successfully copied bonding information
            else
              log -p e -t $TAG Failed to copy bonding information
            fi
        else
          log -p w -t $TAG Persisted bonding information does not exist
        fi
    fi
}

# Store the current bluetooth bonding information from DATA_PATH to PERSIST_PATH.  On success or
# failure, a result string is written to oculus.remote-bonding.result, which can be read by the
# initiating process.
#
# This will fail if the data file is missing, the data file doesn't contain any bonded controllers
# (detected by the lack of "OMVR-V190" in the file), or if the persist file already exists
#
store_factory_bonding()
{
    log -t $TAG Storing factory bonding

    # Check that remote pairing files exits
    log -t $TAG Checking for pairing file
    if [ ! -e $PAIRING_PATH ]; then
      log -p e -t $TAG Pairing file does not exist
      setprop $STORE_BONDING_RESULT_PROP no_pairing_file
      exit 1
    else
      log -t $TAG Pairing file exists.  Reading mac address

      # Read the contents of the mac address file
      MAC_ADDRESS=$(< $PAIRING_PATH)
    fi

    # Check that the mac address was read
    if [ -z "$MAC_ADDRESS" ]; then
      log -p e -t $TAG Mac address empty or failed to read
      setprop $STORE_BONDING_RESULT_PROP failed_read_mac
      exit 1
    else
      log -t $TAG Looking for mac address: $MAC_ADDRESS
      setprop $STORE_MAC_RESULT_PROP $MAC_ADDRESS
    fi

    # Check that the bonding information exists on data
    log -t $TAG Checking bluetooth data path
    if [ ! -e $DATA_PATH ]; then
      log -p e -t $TAG Bluetooth data file does not exist
      setprop $STORE_BONDING_RESULT_PROP no_bluetooth_data_file
      exit 1
    else
      log -t $TAG Bluetooth data file exists
    fi

    # Verify that the bluetooth config contains the mac address of the bonded controller
    log -t $TAG Checking for bonded controller in bluetooth configf
    if ! grep -i $MAC_ADDRESS $DATA_PATH; then
      log -p e -t $TAG Bonded oculus controller not found in bluetooth config
      setprop $STORE_BONDING_RESULT_PROP controller_not_bonded
      exit 1
    else
      log -t $TAG Bonded oculus controller found
    fi

    # Copy the file
    log -t $TAG Storing controller bonding information
    if cp $DATA_PATH $PERSIST_PATH; then
      chmod 0660 $PERSIST_PATH
      chown bluetooth $PERSIST_PATH
      chgrp bluetooth $PERSIST_PATH

      log -p i -t $TAG Successfully copied bonding information
      setprop $STORE_BONDING_RESULT_PROP success
    else
      log -p e -t $TAG Failed to copy bonding information
      setprop $STORE_BONDING_RESULT_PROP failed_to_copy
      exit 1
    fi
}

case $1 in
  --store )         store_factory_bonding
                    ;;
  --restore )       restore_factory_bonding
                    ;;
  * )               log -t $TAG Invalid argument $1
                    exit 1
esac
