#!/bin/bash

# Minecraft Startup Script

MCDIR="/home/minecraft/paper"
JVMARGS="-server -Xms3G -Xmx3G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=32M"
MCJAR="paper.jar"
MCSCREENNAME="minecraft"

screen -dmS $MCSCREENNAME $(which bash)
screen -S $MCSCREENNAME -X stuff "cd ${MCDIR} \n"
screen -S $MCSCREENNAME -X stuff "$(which bash) -c \"exec -a minecraft $(which java) ${JVMARGS} -jar ${MCJAR} nogui\" \n"