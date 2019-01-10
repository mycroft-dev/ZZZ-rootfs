#!/usr/bin/env bash

date > /home/aawadm/update.log
echo "PATH is set to: ${PATH}" >> /home/aawadm/update.log

echo "==== Pull the latest Mycroft GUI and recompile"
cd /home/aawadm/mycroft-gui
/usr/bin/git pull
sudo -K
echo " " | sudo -S echo "Refreshed sudo key for 15 minutes"
. dev_setup.sh

echo "==== Pull the latest Mycroft Core and setup"
cd /home/aawadm/mycroft-core
/usr/bin/git pull
/usr/bin/git checkout dev
echo '{"use_branch": "dev", "auto_update": false}' > /home/aawadm/mycroft-core.dev_opts.json
sudo -K
echo " " | sudo -S echo "Refreshed sudo key for 15 minutes"
# bash /home/aawadm/mycroft-core/dev_setup.sh
md5sum requirements.txt test-requirements.txt dev_setup.sh > .installed


echo "==== Pull the latest Skils"
cd /opt/mycroft/skills/skill-mark-2.mycroftai
/usr/bin/git pull

cd /opt/mycroft/skills/mycroft-weather.mycroftai
/usr/bin/git checkout feature/mark2
/usr/bin/git pull

cd /opt/mycroft/skills/mycroft-date-time.mycroftai
/usr/bin/git checkout feature/mark-2
/usr/bin/git pull

sudo -K
echo " " | sudo -S echo "Refreshed sudo key for 15 minutes"

echo "==== Update the mycroft.conf to get the correct audio device"
cat << EOF | tee /home/aawadm/staged_mycroft.conf
{
     "enclosure" : {
         "platform" : "mycroft_mark_2"
     },
     "listener": {
         "mute_during_output" : false,
         "device_name": "aawsrc$"
     },
     "ipc_path": "/mnt/ramdisk/mycroft/ipc/"
}
EOF
sudo cp /home/aawadm/staged_mycroft.conf /etc/mycroft/mycroft.conf


echo "==== Update the xorg.conf"
cat << EOF | tee /home/aawadm/staged_xorg.conf
Section "InputDevice"
    Identifier  "System Mouse"
    Driver      "mouse"
    Option      "Device" "/dev/input/mouse0"
EndSection

Section "InputDevice"
    Identifier  "System Keyboard"
    Driver      "kbd"
    Option      "Device" "/dev/input/event0"
EndSection

Section "Device"
        Identifier      "ZynqMP"
        Driver          "armsoc"
        Option          "DRI2"                  "true"
        Option          "DRI2_PAGE_FLIP"        "false"
        Option          "DRI2_WAIT_VSYNC"       "true"
        Option          "SWcursorLCD"           "false"
        Option          "DEBUG"                 "true"
EndSection

Section "Extensions"
        Option          "GLX"                   "Disable"
EndSection

Section "Screen"
        Identifier      "DefaultScreen"
        Monitor         "MIPI"
        Device          "ZynqMP"
        DefaultDepth    24
        DefaultFbBpp    24
EndSection

Section "Monitor"
        Identifier      "MIPI"
        Option          "DPMS"                  "false"
EndSection

Section "ServerFlags"
        Option "BlankTime"   "0"
        Option "StandbyTime" "0"
        Option "SuspendTime" "0"
        Option "OffTime"     "0"
EndSection
EOF
sudo cp /home/aawadm/staged_xorg.conf /etc/X11/xorg.conf


echo "==== Setup the service to launch X"
cat << EOF | tee /home/aawadm/staged_test_x.service
[Unit]
After=network.target

[Service]
ExecStart=/home/aawadm/launch_x.sh

[Install]
WantedBy=default.target
EOF
sudo cp /home/aawadm/staged_test_x.service /etc/systemd/system/test_x.service

echo "==== Setup the service to launch Mycroft/GUI"
cat << EOF | tee /home/aawadm/staged_test_mycroft.service
[Unit]
After=network.target test_x

[Service]
User=aawadm
Group=aawadm
ExecStart=/home/aawadm/test_mycroft.sh

[Install]
WantedBy=default.target
EOF
sudo cp /home/aawadm/staged_test_mycroft.service /etc/systemd/system/test_mycroft.service

echo "==== Setup the scripts to launch X11"
cat << EOF | tee /home/aawadm/launch_x.sh
#! /bin/bash
export DISPLAY=:0
echo "Launching X11 server ${DISPLAY}"
echo " " | sudo -S X :0 -noreset > /home/aawadm/xorg_process.log 2>&1 &
sleep 5
xhost +
xeyes
EOF
sudo chmod a+x /home/aawadm/launch_x.sh

echo "==== Setup the scripts to launch Mycroft/GUI"
cat << EOF | tee /home/aawadm/test_mycroft.sh
#!/bin/bash

# This is intended to test the display operation with
# simple X11 tests.  It assumes you have
# already started X, e.g. "sudo X :0"

export DISPLAY=:0

touch > /tmp/test-mycroft-launched
if ! pgrep python ; then
    /home/aawadm/mycroft-core/start-mycroft.sh all
    /home/aawadm/mycroft-core/start-mycroft.sh enclosure
    /usr/local/bin/setgpio_dacamp_mute_off.sh
    /usr/local/bin/setgpio_line_mute_off.sh
fi

sleep 5  # give X time to start
echo "Looking..."
ps aux | grep "X"
xeyes &
sleep 1  # allows xeyes to be the "anchor" to X so it doesn't close
echo "Launched!"

echo "Disabling screen savers?"
xset s 9000 9000
xset s off
echo "Invert touchscreen"
xinput set-prop EP0250M09 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1

echo "Start time..." | tee -a /home/aawadm/xorg_process.log
date | tee -a /home/aawadm/xorg_process.log

echo "Launch GUI"
/usr/bin/mycroft-gui-app --autoconnect --maximize --hideTextInput > /home/aawadm/gui.log 2>&1
EOF
sudo chmod a+x /home/aawadm/test_mycroft.sh

sudo systemctl disable sddm
sudo systemctl enable test_x.service
sudo systemctl enable test_mycroft.service

echo "==== Update completed!"
echo "Update completed!" >> /home/aawadm/update.log
/home/aawadm/mycroft-core/mimic/bin/mimic -t "Update completed successfully, you can reboot me or I will automatically restart in 1 minute"

sudo -K
echo " " | sudo -S echo "Refreshed sudo key for 15 minutes"
sudo -S shutdown -r 1
