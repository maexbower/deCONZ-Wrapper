#!/bin/bash
echo "deCONZ wrapper start script started."

init() {
    source ./settings.env
    SCRIPT_NAME=$0
    echo "Currently runnung as user: $(id -un):$(id -gn)"
}

determine_real_interface() {
    # Determine the real interface like ttyACM0
    REALDEV=$(readlink -e ${DECONZ_DEVICE})
    if [ $? != 0 ]; then
        echo "Failed to find device ${DECONZ_DEVICE}. Please make sure it's connected."
        echo "Exiting now."
        exit 1
    else
        echo  "Found real device for configured device ${DECONZ_DEVICE} in ${REALDEV}"
    fi
}

check_device_access() {
    # check access 
    echo "trying access to ${REALDEV} with user ${DECONZ_USER}"
    if [ $(id -u) != ${DECONZ_USER} ]; then 
        gosu ${DECONZ_USER} touch "${REALDEV}"
        LOCAL_ERROR_LEVEL=$?
    else
        touch "${REALDEV}"
        LOCAL_ERROR_LEVEL=$?
    fi
    
    if [ $LOCAL_ERROR_LEVEL != 0 ]; then
        echo "Access rights for ${REALDEV} do not fit. Trying to add group write permission."
        chmod g+rw ${REALDEV}
        if [ $? != 0 ]; then
            echo "not sufficient permission to change access rights."
            echo "Please make sure the file ${REALDEV} has group read and write permission (g+rw)"
            echo "exiting now"
            exit 1
        else
            echo "Access rights for ${REALDEV} changed to $(stat -c '%A' ${REALDEV})"
            echo "trying access again"
            gosu ${DECONZ_USER} touch ${REALDEV}
            if [ $? != 0 ]; then
                echo "Permissions still not sufficiant. Make sure the user is in the right groups."
                echo "exiting now"
                exit 1
            else
                echo "User is able to access the device ${REALDEV}"
            fi
        fi
    else
        echo "Access rights on device ${REALDEV} are looking fine."
    fi
}

check_and_change_user() {
    #Check if run with right user
    if [ $(id -u) != ${DECONZ_USER} ]; then
        SUDO_REQUIRED=1
        echo "User ID $(id -u) does not match ${DECONZ_USER}. Sudo required"
        echo "Try to run script as target user: ${DECONZ_USER}:${DECONZ_GROUP}"
        gosu ${DECONZ_USER} ${SCRIPT_NAME}
        if [ $? != 0 ]; then
            echo "Starting with target user & group failed. Stoping now."
            exit 1
        fi
        # stop after running with target user
        exit 0
    else
        echo "Curent User ID match."
    fi

    if [ $(id -g) != ${DECONZ_GROUP} ]; then
        SUDO_REQUIRED=1
        echo "Group ID $(id -g) does not match ${DECONZ_GROUP}. Sudo required"
        echo "Try to run script as target user: ${DECONZ_USER}:${DECONZ_GROUP}"
        gosu ${DECONZ_USER} ${SCRIPT_NAME}
        if [ $? != 0 ]; then
            echo "Starting with target user & group failed. Stoping now."
            exit 1
        fi
        # stop after running with target user
        exit 0
    else
        echo "Curent Group ID match."
    fi
}
run_deconz() {
    if [ -e "${DECONZ_PATH}" ]; then
        "${DECONZ_PATH}" $DECONZ_OPTS --dev="${DECONZ_DEVICE}" --http-port=$DECONZ_HTTP_PORT  --ws-port=$DECONZ_WS_PORT --upnp=$DECONZ_UPNP --http-listen=$DECONZ_INTERFACE $DECONZ_DEBUG_OPTS
    else
        echo "deCONZ executable not found in path ${DECONZ_PATH}"
        echo "exiting now"
        exit 1
    fi
}
init
determine_real_interface
check_device_access
check_and_change_user
run_deconz
