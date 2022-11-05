#!/bin/bash
echo "deCONZ wrapper install script started."

init() {
    source ./settings.env
    SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
    SCRIPT_PATH=$(pwd ${BASH_SOURCE[0]})
    echo "Currently runnung as user: $(id -un):$(id -gn)"
    echo "Installer location is ${SCRIPT_PATH}/${SCRIPT_NAME}"
}
check_root_privileges() {
    if [ $(id -u) != 0 ]; then
        echo "Installation needs root privileges. Start again with root or sudo."
        echo "exiting now"
        exit 1
    fi
}
create_wrapper_data_folder() {
    echo "preparing wrapper data folder ${DECONZ_WRAPPER_INSTALL_PATH}"
    if [ -e "${DECONZ_WRAPPER_INSTALL_PATH}" ]; then
        echo "deCONZ wrapper folder ${DECONZ_WRAPPER_INSTALL_PATH} already existing. Files will be overwritten!"
    else
        mkdir -p "${DECONZ_WRAPPER_INSTALL_PATH}"
        if [ $? != 0 ]; then
            echo "Error! Data folder ${DECONZ_WRAPPER_INSTALL_PATH} could not be created."
            echo "exiting now"
            exit 1
        else
            echo "data folder created successfully"
        fi
    fi
    echo "Copying files..."
    # copy start wrapper
    cp -f "${SCRIPT_PATH}"/deCONZstart.sh "${DECONZ_WRAPPER_INSTALL_PATH}"
    if [ $? != 0 ]; then
        echo "Error! Filed to copy start wrapper file ${SCRIPT_PATH}/deCONZstart.sh."
        echo "exiting now"
        exit 1
    else
            echo "start wrapper file ${SCRIPT_PATH}/deCONZstart.sh copied successfully to ${DECONZ_WRAPPER_INSTALL_PATH}"
    fi
    # make start wrapper executable
    chmod +x "${DECONZ_WRAPPER_INSTALL_PATH}"/deCONZstart.sh
    if [ $? != 0 ]; then
        echo "Error! Failed to set executable flag for "${DECONZ_WRAPPER_INSTALL_PATH}"/deCONZstart.sh"
        echo "exiting now"
        exit 1
    else
            echo "${DECONZ_WRAPPER_INSTALL_PATH}/deCONZstart.sh has been flaged as executable"
    fi
    # copy settings file
    cp -f "${SCRIPT_PATH}"/settings.env "${DECONZ_WRAPPER_INSTALL_PATH}" 
    if [ $? != 0 ]; then
        echo "Error! Filed to copy settings file ${SCRIPT_PATH}/settings.env."
        echo "exiting now"
        exit 1
    else
        echo "settings file ${SCRIPT_PATH}/settings.env copied successfully to ${DECONZ_WRAPPER_INSTALL_PATH}"
    fi
    # copy installer file
    cp -f "${SCRIPT_PATH}"/${SCRIPT_NAME} "${DECONZ_WRAPPER_INSTALL_PATH}" 
    if [ $? != 0 ]; then
        echo "Error! Filed to copy installer file ${SCRIPT_PATH}/${SCRIPT_NAME}"
        echo "exiting now"
        exit 1
    else
        echo "settings file ${SCRIPT_PATH}/${SCRIPT_NAME} copied successfully to ${DECONZ_WRAPPER_INSTALL_PATH}"
    fi
    # allow permission to read to deconz user
    chmod -R +r ${DECONZ_WRAPPER_INSTALL_PATH}
    if [ $? != 0 ]; then
        echo "Error! Failed to make wrapper files folder readable for everyone"
        echo "exiting now"
        exit 1
    else
            echo "${DECONZ_WRAPPER_INSTALL_PATH} is now readable by everyone"
    fi
}
setup_apt_repo(){
    # Backup existing deconz.list file
    if [ -e "${DECONZ_APT_LIST_FILE}" ]; then
        cp -f "${DECONZ_APT_LIST_FILE}" "${DECONZ_WRAPPER_INSTALL_PATH}"/$(basename "${DECONZ_APT_LIST_FILE}").backup
        echo "Apt List file already existing. Backup stored to" "${DECONZ_WRAPPER_INSTALL_PATH}"/$(basename "${DECONZ_APT_LIST_FILE}").backup
    fi
    # download and install apt repo key
    # remove existing key file from wrapper folder
    if [ -e "${DECONZ_WRAPPER_INSTALL_PATH}"/"$(basename ${DECONZ_APT_KEY})" ]; then
        echo "Existing apt repo keyfile ${DECONZ_WRAPPER_INSTALL_PATH}/$(basename ${DECONZ_APT_KEY}) will be overwritten!"
        rm -f "${DECONZ_WRAPPER_INSTALL_PATH}"/"$(basename ${DECONZ_APT_KEY})"
    fi
    # remove existing gpg key from apt truststore
    if [ -e "${DECONZ_APT_GPG_FILE}" ]; then
        echo "Existing apt repo keyfile ${DECONZ_APT_GPG_FILE} will be overwritten!"
        rm -f "${DECONZ_APT_GPG_FILE}"
    fi
    # download new key to wrapper folder
    wget -q -O "${DECONZ_WRAPPER_INSTALL_PATH}"/"$(basename ${DECONZ_APT_KEY})" $DECONZ_APT_KEY
    if [ $? != 0 ]; then
        echo "failed to download new keyfile from ${DECONZ_APT_KEY}"
        echo "exiting now"
        exit 1
    else
        echo "successfully downloaded key file from ${DECONZ_APT_KEY} to ${DECONZ_WRAPPER_INSTALL_PATH}/$(basename ${DECONZ_APT_KEY})"
    fi
    # import new key to apt trust store
    cat "${DECONZ_WRAPPER_INSTALL_PATH}"/"$(basename ${DECONZ_APT_KEY})" | gpg  --dearmour -o "${DECONZ_APT_GPG_FILE}"
    if [ $? != 0 ]; then
        echo "Failed to add deCONZ Apt Key ${DECONZ_APT_GPG_FILE}"
        echo "exit now"
        exit 1
    else
        echo "Apt key import to ${DECONZ_APT_GPG_FILE} successfully"
    fi
    # set deconz apt list file
    echo $DECONZ_APT_REPO > "${DECONZ_APT_LIST_FILE}"
    if [ $? != 0 ]; then
        echo "Failed to add deCONZ Repository to ${DECONZ_APT_LIST_FILE}"
        echo "exit now"
        exit 1
    else
        echo "Add Apt repo to ${DECONZ_APT_LIST_FILE} successfully"
    fi
}
install_deconz(){
    # update apt
    echo "Running apt update"
    apt update
    if [ $? != 0 ]; then
        echo "Failed to update apt repositories"
        echo "exit now"
        exit 1
    else
        echo "apt repositories updated successfully"
    fi
    echo "install dependencies"
    echo $DECONZ_APT_DEPENDENCIES
    apt install -y $DECONZ_APT_DEPENDENCIES
    if [ $? != 0 ]; then
        echo "Failed to install dependencies"
        echo "exit now"
        exit 1
    else
        echo "Dependencies installed successfully"
    fi
    echo "install deconz"
    apt install -y --no-install-recommends deconz
    if [ $? != 0 ]; then
        echo "Failed to install deCONZ"
        echo "exit now"
        exit 1
    else
        echo "Dependencies installed deCONZ"
    fi
}
fix_udev_device_assignments() {
    # Backup existing 98-deCONZwrapper.rules
    if [ -e "${DECONZ_UDEV_FILE}" ]; then
        cp -f "${DECONZ_UDEV_FILE}" "${DECONZ_WRAPPER_INSTALL_PATH}"/$(basename "${DECONZ_UDEV_FILE}").backup
        echo "Udev Rules file already existing. Backup stored to" "${DECONZ_WRAPPER_INSTALL_PATH}"/$(basename "${DECONZ_UDEV_FILE}").backup
        rm -f "${DECONZ_UDEV_FILE}"
    fi
    # find deCONZ device
    # check if connected to usb
    #LSUSB_STRING=$(lsusb |grep ConBee)
    # get full path to serial device by name
    SERIAL_DEVICE_PATH=$(find /dev/serial/ -name "*ConBee_II*")
    if [ "$SERIAL_DEVICE_PATH" != "" ]; then
        echo "Serial device found at $SERIAL_DEVICE_PATH"
    else
        echo "Serial device not found. Make sure it is connected."
        echo "exiting now"
        exit 1
    fi
    # Get Serial No
    SERIAL_STRING=$(udevadm info $SERIAL_DEVICE_PATH  | grep ID_SERIAL_SHORT | grep -oP "=\K.*")
    VENDOR_STRING=$(udevadm info $SERIAL_DEVICE_PATH  | grep ID_VENDOR_ID | grep -oP "=\K.*")
    DEVICE_STRING=$(udevadm info $SERIAL_DEVICE_PATH  | grep ID_MODEL_ID | grep -oP "=\K.*")
    echo "Device Info found: $SERIAL_STRING ${VENDOR_STRING}:${DEVICE_STRING}"
    echo "Add Rule to Udev to map device to ${DECONZ_DEVICE}"
    # Create udev filte rrule to set group permissions for tty device and create symlink to fixed device name 
    echo "SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"${VENDOR_STRING}\", ATTRS{idProduct}==\"${DEVICE_STRING}\", ATTRS{serial}==\"${SERIAL_STRING}\", SYMLINK+=\"$(basename ${DECONZ_DEVICE})\", GROUP=\"${SYSTEM_DIALOUT_GROUP}\"" > "${DECONZ_UDEV_FILE}"
    if [ $? != 0 ]; then
        echo "Failed to install udev rule"
        echo "exit now"
        exit 1
    else
        echo "udev rule installed successfully"
    fi
}
change_systemd_config() {
    #Stop deCONZ Services if already running
    systemctl stop deconz deconz-init deconz-update 
    # Backup existing deconz.service file
    if [ -e "${DECONZ_SYSTEMD_OVERRIDE}" ]; then
        cp -f "${DECONZ_SYSTEMD_OVERRIDE}" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-override.backup
        echo "deCONZ Systemd override file already existing. Backup stored to" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-override.backup
    fi
    # Backup existing deconz-init.service file
    if [ -e "${DECOZ_INIT_SYSTEMD_OVERRIDE}" ]; then
        cp -f "${DECOZ_INIT_SYSTEMD_OVERRIDE}" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-init-override.backup
        echo "deCONZ-init Systemd override file already existing. Backup stored to" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-init-override.backup
    fi
    # Backup existing deconz-update.service file
    if [ -e "${DECOZ_UPDATE_SYSTEMD_OVERRIDE}" ]; then
        cp -f "${DECOZ_UPDATE_SYSTEMD_OVERRIDE}" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-update-override.backup
        echo "deCONZ-update Systemd override file already existing. Backup stored to" "${DECONZ_WRAPPER_INSTALL_PATH}"/deconz-update-override.backup
    fi
    mkdir -p "$(dirname ${DECONZ_SYSTEMD_OVERRIDE})"
    if [ $? != 0 ]; then
        echo "Error! deconz systemd override folder ${DECONZ_SYSTEMD_OVERRIDE} could not be created."
        echo "exiting now"
        exit 1
    else
        echo "deconz systemd override folder created successfully"
    fi
    mkdir -p "$(dirname ${DECOZ_INIT_SYSTEMD_OVERRIDE})"
    if [ $? != 0 ]; then
        echo "Error! deconz-init systemd override folder ${DECOZ_INIT_SYSTEMD_OVERRIDE} could not be created."
        echo "exiting now"
        exit 1
    else
        echo "deconz-init systemd override folder created successfully"
    fi
    mkdir -p "$(dirname ${DECOZ_UPDATE_SYSTEMD_OVERRIDE})"
    if [ $? != 0 ]; then
        echo "Error! deconz-update systemd override folder ${DECOZ_UPDATE_SYSTEMD_OVERRIDE} could not be created."
        echo "exiting now"
        exit 1
    else
        echo "deconz-update systemd override folder created successfully"
    fi
    echo "Wrting systemd override files"
    # Set content of deconu override file
    cat <<EOF >"${DECONZ_SYSTEMD_OVERRIDE}"
[Service]
User=root
Group=root
ExecStart=
ExecStart="${DECONZ_WRAPPER_INSTALL_PATH}/deCONZstart.sh"

[Unit]
Wants=
EOF
    if [ $? != 0 ]; then
        echo "Error! deconz systemd override file ${DECONZ_SYSTEMD_OVERRIDE} could not be created. "
        echo "exiting now"
        exit 1
    else
        echo "deconz systemd override file created successfully"
    fi

    # set content of deconz-init override file
    cat <<EOF >"${DECOZ_INIT_SYSTEMD_OVERRIDE}"
[Service]
ExecStart=
ExecStart=echo "skiped init"
EOF
    if [ $? != 0 ]; then
        echo "Error! deconz-init systemd override file ${DECOZ_INIT_SYSTEMD_OVERRIDE} could not be created. "
        echo "exiting now"
        exit 1
    else
        echo "deconz-init systemd override file created successfully"
    fi
    # set content of deconz-update override file
    cat <<EOF >"${DECOZ_UPDATE_SYSTEMD_OVERRIDE}"
[Service]
ExecStart=
ExecStart=echo "skiped init"
EOF
    if [ $? != 0 ]; then
        echo "Error! deconz-update systemd override file ${DECOZ_UPDATE_SYSTEMD_OVERRIDE} could not be created. "
        echo "exiting now"
        exit 1
    else
        echo "deconz-update systemd override file created successfully"
    fi
    # make systemd aware of changes
    echo "reload systemd to make it aware of changes"
    systemctl daemon-reload
    echo "enable deconz service"
    systemctl enable deconz
    if [ $? != 0 ]; then
        echo "Error! deconz service could not be enabled"
        echo "exiting now"
        exit 1
    else
        echo "deconz systemd service successfully enabled"
    fi
}

init
check_root_privileges
create_wrapper_data_folder
setup_apt_repo
install_deconz
fix_udev_device_assignments
change_systemd_config
echo "Attention! Reboot is required before starting deconz!"
echo "Installer finished successfully"