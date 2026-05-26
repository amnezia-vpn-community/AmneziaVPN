#!/bin/bash

APP_NAME=AmneziaVPN
LOG_FOLDER=/var/log/$APP_NAME
LOG_FILE="$LOG_FOLDER/post-install.log"
APP_PATH=/opt/$APP_NAME
CONFIG_FOLDER=/etc/$APP_NAME
IPC_AUTH_ENV_FILE="$CONFIG_FOLDER/ipc-auth.env"

resolve_ipc_auth_uid() {
        for uid in "${SUDO_UID:-}" "${PKEXEC_UID:-}" "${DOAS_UID:-}"; do
                if [[ "$uid" =~ ^[0-9]+$ ]] && [[ "$uid" != "0" ]]; then
                        echo "$uid"
                        return 0
                fi
        done

        if command -v loginctl &> /dev/null; then
                uid=$(loginctl list-users --no-legend 2>/dev/null | awk '$1 != "0" { print $1; exit }')
                if [[ "$uid" =~ ^[0-9]+$ ]] && [[ "$uid" != "0" ]]; then
                        echo "$uid"
                        return 0
                fi
        fi

        return 1
}

if ! test -f $LOG_FOLDER; then
        sudo mkdir $LOG_FOLDER
        echo "AmneziaVPN log dir created at /var/log/"
fi

if ! test -f $LOG_FILE; then
        touch $LOG_FILE
        echo "AmneziaVPN log file created at /var/log/AmneziaVPN/post-install.log"
fi

date > $LOG_FILE
echo "Script started" >> $LOG_FILE
sudo killall -9 $APP_NAME 2>> $LOG_FILE

if command -v steamos-readonly &> /dev/null; then
        sudo steamos-readonly disable >> $LOG_FILE
        echo "steamos-readonly disabled" >> $LOG_FILE
fi

if sudo systemctl is-active --quiet $APP_NAME; then
	sudo systemctl stop $APP_NAME >> $LOG_FILE
	sudo systemctl disable $APP_NAME >> $LOG_FILE
	sudo rm -rf /etc/systemd/system/$APP_NAME.service >> $LOG_FILE
fi

sudo chmod -R a-w $APP_PATH/

sudo cp $APP_PATH/$APP_NAME.service /etc/systemd/system/ >> $LOG_FILE

IPC_AUTH_UID=$(resolve_ipc_auth_uid)
if [[ ! "$IPC_AUTH_UID" =~ ^[0-9]+$ ]] || [[ "$IPC_AUTH_UID" == "0" ]]; then
        echo "Failed to resolve non-root IPC auth uid; refusing to start service" >> $LOG_FILE
        exit 1
fi

sudo mkdir -p "$CONFIG_FOLDER" >> $LOG_FILE
printf 'AMNEZIAVPN_IPC_AUTH_UID=%s\n' "$IPC_AUTH_UID" | sudo tee "$IPC_AUTH_ENV_FILE" > /dev/null
sudo chmod 600 "$IPC_AUTH_ENV_FILE" >> $LOG_FILE

sudo systemctl start $APP_NAME >> $LOG_FILE
sudo systemctl enable $APP_NAME >> $LOG_FILE
sudo ln -sf $APP_PATH/bin/$APP_NAME /usr/local/sbin/$APP_NAME >> $LOG_FILE
sudo ln -sf $APP_PATH/bin/$APP_NAME /usr/local/bin/$APP_NAME >> $LOG_FILE

echo "user desktop creation loop started" >> $LOG_FILE
sudo cp $APP_PATH/$APP_NAME.desktop /usr/share/applications/ >> $LOG_FILE
sudo cp $APP_PATH/$APP_NAME.png /usr/share/pixmaps/ >> $LOG_FILE
sudo chmod 555 /usr/share/applications/$APP_NAME.desktop >> $LOG_FILE

echo "user desktop creation loop ended" >> $LOG_FILE

if command -v steamos-readonly &> /dev/null; then
        sudo steamos-readonly enable >> $LOG_FILE
        echo "steamos-readonly enabled" >> $LOG_FILE
fi

date >> $LOG_FILE
echo "Service status:" >> $LOG_FILE
sudo systemctl status $APP_NAME >> $LOG_FILE
date >> $LOG_FILE
echo "Script finished" >> $LOG_FILE
exit 0
