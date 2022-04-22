ARG FROM=arepyevanatoliy/steamcmd:latest
ARG DST_SERVER_NAME=''

FROM ${FROM}

ENV DST_ROOT_DIR=/opt/server
ENV DST_APP_DIR=${DST_ROOT_DIR}/app
ENV DST_CONFIG_SRS=${DST_ROOT_DIR}/srs
ENV DST_CONFIG_DIR=$STEAM_HOME/.klei/DoNotStarveTogether

RUN echo "**** enable multiarch binaries support  ****" && \
    dpkg --add-architecture i386 && \
    echo "**** sync lists of packages  ****" && \
    apt-get update && \
    echo "**** install packages ****" && \
    apt-get install sed \
                    screen \
                    lib32gcc1 \                    
                    lib32gcc1 \
                    libcurl4-gnutls-dev \
                    libcurl4-gnutls-dev:i386 \
                    lib32stdc++6 \
                    libgcc1 \
                    locales \
                    -y && \
    echo "**** create all dirs for volumes ****" && \
    mkdir -pv $DST_APP_DIR $DST_CONFIG_DIR && \
    echo "**** Setting the directory owner to steamcmd:steamcmd for $DST_ROOT_DIR ****" && \
    chown -R steamcmd:steamcmd $DST_ROOT_DIR && \
    echo "**** Setting the directory owner to steamcmd:steamcmd for $DST_APP_DIR ****" && \
    chown -R steamcmd:steamcmd $DST_APP_DIR && \
    echo "**** Setting the directory owner to steamcmd:steamcmd for $DST_CONFIG_DIR ****" && \
    chown -R steamcmd:steamcmd $DST_CONFIG_DIR

ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8   

VOLUME [ "$DST_APP_DIR" ]
VOLUME [ "$DST_CONFIG_DIR" ]

COPY --chown=steamcmd:steamcmd entrypoint.sh $STEAM_HOME/
COPY --chown=steamcmd:steamcmd steamcmd-script/* $STEAM_HOME/steamcmd-script/

USER steamcmd:steamcmd

CMD ["/bin/bash", "-c", "$STEAM_HOME/entrypoint.sh"]