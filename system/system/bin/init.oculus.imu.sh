#!/system/bin/sh

# move IMU related kthreads into new cpuset to prevent them
# from stealing time from top app (UIThread, RenderThread, TimeWarp, audio)
PROCS=(spi5 lsm6dsl lis2mdl tsvc-hmd-imu bmi055)
CSET="/dev/cpuset/imu"
TAG=imucpusets

ps -t | sed 's/  */\t/g' | \
while read -r line
do
    set -- $line
    user=$1
    pid=$2
    task=$9

    for proc in "${PROCS[@]}"
    do
        if [[ $user != root ]] && [[ $user != system ]]
        then
            continue
        fi
        if [[ $task = *${proc}* ]]
        then
            echo "$pid" > "$CSET"/tasks
            log -t $TAG -p d "pid=$pid($task) matches $proc, adding to $CSET"
        fi
    done
done
