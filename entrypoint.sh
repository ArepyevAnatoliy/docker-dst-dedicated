#!/bin/bash
set -e
set -o pipefail

function append_date_to_log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date --rfc-3339="s")" "$line";
        #logger -i --skip-empty -p user.info -t "${DST_SERVER_NAME}" "$line"
    done
    return 0
}

# Save start dir
START_DIR=$(pwd)

FROM_SCRATCH='false'

# Check if var with steamcmd folder is not empty and exist
if [[ -z $STEAM_CMD_DIR || ! -e $STEAM_CMD_DIR ]]; then
    echo '**** STEAM_CMD_DIR variable is empty or folder does not exist! ****' | append_date_to_log
    echo "**** STEAM_CMD_DIR=${STEAM_CMD_DIR} ****" | append_date_to_log 
    exit 1
else
    echo "**** STEAM_CMD_DIR=${STEAM_CMD_DIR} ****" | append_date_to_log
fi

# Check if var with steamcmd entrypoint is not empty and exist
if [[ -z $STEAM_CMD_ENTRYPOINT || ! -e $STEAM_CMD_ENTRYPOINT ]]; then
    echo '**** STEAM_CMD_ENTRYPOINT variable is empty or file does not exist! ****' | append_date_to_log
    echo "**** STEAM_CMD_ENTRYPOINT=${STEAM_CMD_ENTRYPOINT} ****" | append_date_to_log
    exit 1
else
    echo "**** STEAM_CMD_ENTRYPOINT=${STEAM_CMD_ENTRYPOINT} ****" | append_date_to_log
fi

# Check if var with application path is not empty and exist 
if [[ -z $DST_APP_DIR || ! -e $DST_APP_DIR ]]; then
    echo '**** DST_APP_DIR variable is empty or file does not exist! ****' | append_date_to_log
    echo "**** DST_APP_DIR=${DST_APP_DIR} ****" | append_date_to_log
    exit 1
else
    echo "**** DST_APP_DIR=${DST_APP_DIR} ****" | append_date_to_log
fi

# Check if var with destanation path for server configuration is not empty and exist
if [[ -z $DST_CONFIG_DIR || ! -e $DST_CONFIG_DIR ]]; then
    echo '**** DST_CONFIG_DIR variable is empty or file does not exist! ****' | append_date_to_log
    echo "**** DST_CONFIG_DIR=${DST_CONFIG_DIR} ****" | append_date_to_log
    exit 1
else
    echo "**** DST_CONFIG_DIR=${DST_CONFIG_DIR} ****" | append_date_to_log
fi

# Get DST server name. Use default one if it was not define
DST_SERVER_NAME=${SERVER_NAME:-"DedicatedServer-$HOSTNAME"}
echo "**** DST_SERVER_NAME=${DST_SERVER_NAME} ****" | append_date_to_log

# Trying to check if folder with server configuration is already exist
DST_SERVER_CONF_DIR="$(find "$DST_CONFIG_DIR" -maxdepth 1 -type d -name "$DST_SERVER_NAME" -print)"

if [[ -z $DST_SERVER_CONF_DIR || ! -e $DST_SERVER_CONF_DIR ]]; then
    echo '**** DST_SERVER_CONF_DIR variable is empty or file does not exist! ****' | append_date_to_log
    echo "**** DST_SERVER_CONF_DIR=${DST_SERVER_CONF_DIR} ****" | append_date_to_log
    echo "**** There is no directory with the cluster name $DST_SERVER_NAME, so a new one will be created. ****" | append_date_to_log

    mkdir -p -v $DST_CONFIG_DIR/$DST_SERVER_NAME | append_date_to_log

    DST_SERVER_CONF_DIR="$(find "$DST_CONFIG_DIR" -maxdepth 1 -name "$DST_SERVER_NAME" -print)"
    echo "**** DST_SERVER_CONF_DIR=${DST_SERVER_CONF_DIR} ****" | append_date_to_log

    echo "**** Set FROM_SCRATCH to true! ****" | append_date_to_log
    FROM_SCRATCH='true'
else
    echo "**** DST_SERVER_CONF_DIR=${DST_SERVER_CONF_DIR} ****" | append_date_to_log
fi

# Checking if the var with server configuration source directory path exists
if [[ -z $DST_CONFIG_SRS || ! -e $DST_CONFIG_SRS ]]; then
    echo '**** DST_CONFIG_SRS variable is empty or folder does not exist! ****' | append_date_to_log
    echo "**** DST_CONFIG_SRS=${DST_CONFIG_SRS} ****" | append_date_to_log
    exit 1
else
    echo "**** DST_CONFIG_SRS=${DST_CONFIG_SRS} ****" | append_date_to_log
fi

# Check if var with steamcmd folder is not empty and exist at all
if [[ $(find $DST_CONFIG_SRS -mindepth 1 -print | grep -vE "backups/*" | wc -l) -eq 0 ]]; then
    echo '**** Apparently DST_CONFIG_SRS is empty and contains no files or directories (except backups)! ****' | append_date_to_log    
    echo "**** DST_CONFIG_SRS=${DST_CONFIG_SRS} ****" | append_date_to_log
    ls -slta $DST_CONFIG_SRS | append_date_to_log    
    exit 1
fi

# Detect folder with server config in DST_CONFIG_SRS
if [[ $(find $DST_CONFIG_SRS -name "cluster.ini" -print | wc -l) -ne 0 && $(find $DST_CONFIG_SRS -name "cluster_token.txt" -print | wc -l) -ne 0 ]]; then
    DST_SERVER_CONF_SRS_DIR="$(find $DST_CONFIG_SRS -name "cluster.ini" -print)"
    DST_SERVER_CONF_SRS_DIR="${DST_SERVER_CONF_SRS_DIR%/*}"
    echo "**** DST_SERVER_CONF_SRS_DIR=${DST_SERVER_CONF_SRS_DIR} ****" | append_date_to_log
else
    echo "**** $DST_CONFIG_SRS folder does not contain any DST server configuration with cluster.ini and cluster_token.txt! ****" | append_date_to_log
    exit 1
fi


if [[ $(find $DST_SERVER_CONF_SRS_DIR -name "FROM_SCRATCH" -print | wc -l) -ne 0 && ( $(find $DST_SERVER_CONF_SRS_DIR -name "FROM_SCRATCH" -exec cat {} \; | tr '[:upper:]' '[:lower:]') == 'true' || "$FROM_SCRATCH" == 'true' ) ]]; then
    echo "**** FROM_SCRATCH file in $DST_SERVER_CONF_SRS_DIR contain \'true\' or $DST_CONFIG_DIR/$DST_SERVER_NAME was not exist! ****" | append_date_to_log
    
    FROM_SCRATCH=true
else
    echo "**** FROM_SCRATCH file in $DST_SERVER_CONF_SRS_DIR is not exist or not contain \'true\'! ****" | append_date_to_log
    
    echo 'false' > "$DST_SERVER_CONF_SRS_DIR/FROM_SCRATCH"
    
    FROM_SCRATCH=false
fi

if [[ $FROM_SCRATCH == 'true' && $(find $DST_SERVER_CONF_DIR -mindepth 1 -print | wc -l) -ne 0 ]]; then
    # We need to update server config and it's already exist in conatiner
    echo "**** $DST_SERVER_CONF_DIR is not empty! Creating backup archive... ****" | append_date_to_log
    
    BACKUP_ARCHIVE_NAME="$(echo "backup_$DST_SERVER_NAME" | tr '[:upper:]' '[:lower:]' | tr [:blank:] '_' )_$(date +%F_%H-%M-%S_utc%z).tar.gz"
    
    tar -czvf "$DST_CONFIG_SRS/backups/$BACKUP_ARCHIVE_NAME" $DST_SERVER_CONF_DIR/ | append_date_to_log
    
    echo "**** $BACKUP_ARCHIVE_NAME was created successfully in $DST_CONFIG_SRS/backups/$DST_SERVER_NAME... ****" | append_date_to_log

    echo "**** Clean $DST_SERVER_CONF_DIR... ****" | append_date_to_log

    rm -rfv $DST_SERVER_CONF_DIR/*

    echo "**** $DST_SERVER_CONF_DIR cleaned up successfully! ****" | append_date_to_log

    echo "**** Copy server configuration files"  | append_date_to_log
    echo "from $DST_SERVER_CONF_SRS_DIR... ****" | append_date_to_log
    echo "to $DST_SERVER_CONF_DIR... ****" | append_date_to_log
    
    cp -Rv $DST_SERVER_CONF_SRS_DIR/* $DST_SERVER_CONF_DIR/

    echo "**** DST server configuration files were copied successfully! ****" | append_date_to_log

elif [[ $FROM_SCRATCH == 'true' && $(find $DST_SERVER_CONF_DIR -mindepth 1 -print | wc -l) -eq 0 ]]; then
    # We need to update server config and it's not exist in conatiner
    echo "**** Copy server configuration files:"  | append_date_to_log
    echo "****    from $DST_SERVER_CONF_SRS_DIR... ****" | append_date_to_log
    echo "****    to $DST_SERVER_CONF_DIR... ****" | append_date_to_log
    
    cp -Rv $DST_SERVER_CONF_SRS_DIR/* $DST_SERVER_CONF_DIR/

    echo "**** DST server configuration files were copied successfully! ****" | append_date_to_log
else
    echo "TODO: Need to check server config and backup it if needed before start"
fi

# Check execution permission
if [[ -x $STEAM_CMD_ENTRYPOINT ]]; then
    chmod -v +x "$STEAM_CMD_ENTRYPOINT" | append_date_to_log
fi

# Replace all special labels on the values ​​of the current value context.
echo "**** Replace _SERVER_APP_DIR_ in steamcmd scripts with ${DST_APP_DIR} ****" | append_date_to_log
find ~/steamcmd-script/ -name "*.steamcmd" \
                        -exec echo "**** ==>> {} <<== ****" \; \
                        -exec sed -i -e "s@_SERVER_APP_DIR_@${DST_APP_DIR}@g" {} \; \
                        -exec echo "**** ================== ****!" \; | append_date_to_log 
echo "**** Done! ****"  | append_date_to_log

echo "**** Replace _SERVER_CONFIG_DIR_ in steamcmd scripts with ${DST_CONFIG_DIR} ****" | append_date_to_log 
find ~/steamcmd-script/ -name "*.steamcmd" \
                        -exec echo "**** ==>> {} <<== ****" \; \
                        -exec sed -i -e "s@_SERVER_CONFIG_DIR_@${DST_CONFIG_DIR}@g" {} \; \
                        -exec cat {} \; \
                        -exec echo "**** ================== ****!" \; | append_date_to_log
echo "**** Done! ****"  | append_date_to_log

# Get all available scripts with *.steamcmd extension and run them one by one.
echo "****Get all available scripts with *.steamcmd extension and run them one by one ****" | append_date_to_log 
find ~/steamcmd-script/ -name "*.steamcmd" \
                        -exec echo "**** ==>> {} <<== ****" \; \
                        -exec bash -c "$STEAM_CMD_ENTRYPOINT +runscript {} 2>&1 | tee -a $DST_APP_DIR/instal.log " \; \
                        -exec echo "**** ================== ****!" \; | append_date_to_log

# Goto DST bin folder
cd "$DST_APP_DIR/bin64/" || echo "**** Can not cd to ${DST_APP_DIR}/bin64/ ****" | append_date_to_log 1>&2

# Start Main server
echo "Starting..." | append_date_to_log
echo "Cluster: $DST_SERVER_NAME" | append_date_to_log
echo "Shard: Master" | append_date_to_log
nohup ./dontstarve_dedicated_server_nullrenderer_x64    -cluster "$DST_SERVER_NAME" \
                                                        -shard Master 2>&1 | append_date_to_log &
echo "Master was Started..." | append_date_to_log

# Start Caves server
echo "Starting..." | append_date_to_log
echo "Cluster: $DST_SERVER_NAME" | append_date_to_log
echo "Shard: Caves" | append_date_to_log
nohup ./dontstarve_dedicated_server_nullrenderer_x64    -cluster "$DST_SERVER_NAME" \
                                                        -shard Caves 2>&1 | append_date_to_log &
echo "Caves was Started..." | append_date_to_log

cd "$START_DIR" || echo "**** Can not cd to $START_DIR ****" | append_date_to_log

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?