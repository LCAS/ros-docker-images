ARG BASE_IMAGE=nvidia/cuda:11.8.0-runtime-ubuntu22.04

###########################################
FROM ${BASE_IMAGE} as base
ARG ROS_DISTRO=humble

ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive

# Install language
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
  locales \
  && locale-gen en_US.UTF-8 \
  && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8

# Install timezone
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y --no-install-recommends tzdata \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get -y upgrade \
    && rm -rf /var/lib/apt/lists/*

# Install common programs
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    lsb-release \
    sudo \
    python3-setuptools \
    software-properties-common \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install ROS2
RUN add-apt-repository universe \
  && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
  && apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-ros-base \
    python3-argcomplete \
  && rm -rf /var/lib/apt/lists/*

################
# Expose the nvidia driver to allow opengl 
# Dependencies for glvnd and X11.
################
RUN apt-get update \
 && apt-get install -y -qq --no-install-recommends \
  libglvnd0 \
  libgl1 \
  libglx0 \
  libegl1 \
  libxext6 \
  libx11-6 \
  && rm -rf /var/lib/apt/lists/*

# Env vars for the nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES all
# enable all capabilities for the container
# Explained here: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.10.0/user-guide.html#driver-capabilities
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV QT_X11_NO_MITSHM 1

ENV AMENT_PREFIX_PATH=/opt/ros/${ROS_DISTRO}
ENV COLCON_PREFIX_PATH=/opt/ros/${ROS_DISTRO}
ENV LD_LIBRARY_PATH=/opt/ros/${ROS_DISTRO}/lib
ENV PATH=/opt/ros/${ROS_DISTRO}/bin:$PATH
ENV PYTHONPATH=/opt/ros/${ROS_DISTRO}/local/lib/python3.10/dist-packages:/opt/ros/${ROS_DISTRO}/lib/python3.10/site-packages
ENV ROS_PYTHON_VERSION=3
ENV ROS_VERSION=2
ENV DEBIAN_FRONTEND=

###########################################
#  Develop image
###########################################
FROM base AS dev

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  bash-completion \
  build-essential \
  cmake \
  gdb \
  git \
  openssh-client \
  python3-argcomplete \
  python3-pip \
  ros-dev-tools \
  ros-${ROS_DISTRO}-ament-* \
  vim \
  && rm -rf /var/lib/apt/lists/*

RUN rosdep init || echo "rosdep already initialized"

ARG USERNAME=ros
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Create a non-root user
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  # Add sudo support for the non-root user
  && apt-get update \
  && apt-get install -y --no-install-recommends sudo \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && rm -rf /var/lib/apt/lists/*

# Set up autocompletion for user
RUN apt-get update && apt-get install -y git-core bash-completion \
  && echo "if [ -f /opt/ros/${ROS_DISTRO}/setup.bash ]; then source /opt/ros/${ROS_DISTRO}/setup.bash; fi" >> /home/$USERNAME/.bashrc \
  && echo "if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash; fi" >> /home/$USERNAME/.bashrc \
  && rm -rf /var/lib/apt/lists/* 

ENV DEBIAN_FRONTEND=
ENV AMENT_CPPCHECK_ALLOW_SLOW_VERSIONS=1

###########################################
#  Full image
###########################################
FROM dev AS full

ENV DEBIAN_FRONTEND=noninteractive
# Install the full release
RUN apt-get update && apt-get install -y --no-install-recommends \
  ros-${ROS_DISTRO}-desktop \
  && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=
ENV LD_LIBRARY_PATH=/opt/ros/${ROS_DISTRO}/lib


###########################################
FROM dev as lcas

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y lsb-release curl software-properties-common unzip apt-transport-https && \
    rm -rf /var/lib/apt/lists/* 

RUN sh -c 'echo "deb https://lcas.lincoln.ac.uk/apt/lcas $(lsb_release -sc) lcas" > /etc/apt/sources.list.d/lcas-latest.list' && \
    curl -s https://lcas.lincoln.ac.uk/apt/repo_signing.gpg > /etc/apt/trusted.gpg.d/lcas-latest.gpg

RUN rosdep init || true
RUN curl -o /etc/ros/rosdep/sources.list.d/20-default.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/20-default.list && \
    curl -o /etc/ros/rosdep/sources.list.d/50-lcas.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/50-lcas.list

ENV ROSDISTRO_INDEX_URL=https://raw.github.com/LCAS/rosdistro/master/index-v4.yaml

# install Zenoh
# RUN mkdir -p /tmp/zenoh-build && \ 
#     cd /tmp/zenoh-build && \
#     (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y) && \
#     git clone --depth 1 -b 1.1.0 https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds.git && \
#     cd /tmp/zenoh-build/zenoh-plugin-ros2dds && \
#     /bin/bash -c "source '$HOME/.cargo/env'; cargo build --release -p zenoh-bridge-ros2dds" && \
#     install target/release/zenoh-bridge-ros2dds /usr/local/bin/

ENV ZENOH_BRIDGE_VERSION=1.1.0
RUN cd /tmp; \
    if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
      curl -L -O https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${ZENOH_BRIDGE_VERSION}/zenoh-plugin-ros2dds-${ZENOH_BRIDGE_VERSION}-aarch64-unknown-linux-gnu-standalone.zip; \
    else \
      curl -L -O https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${ZENOH_BRIDGE_VERSION}/zenoh-plugin-ros2dds-${ZENOH_BRIDGE_VERSION}-x86_64-unknown-linux-gnu-standalone.zip; \
    fi; \
    unzip zenoh-plugin-ros2dds-*.zip && \
    mv zenoh-bridge-ros2dds /usr/local/bin/ && \
    chmod +x /usr/local/bin/zenoh-bridge-ros2dds && \
    ldconfig && \
    rm -rf zenoh-*

# install nodejs
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
RUN apt-get update && apt-get install -y nodejs sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


###########################################
FROM lcas as openglvnc

ARG ENTRY_POINT=/opt/entrypoint.sh
ARG TARGETARCH
ENV ENTRY_POINT=${ENTRY_POINT}

ENV DEBIAN_FRONTEND=noninteractive
RUN curl -L -O https://github.com/VirtualGL/virtualgl/releases/download/3.1.1/virtualgl_3.1.1_${TARGETARCH}.deb && \
    apt-get update && \
    apt-get -y install ./virtualgl_3.1.1_${TARGETARCH}.deb && \
    rm virtualgl_3.1.1_${TARGETARCH}.deb && rm -rf /var/lib/apt/lists/* 
RUN curl -L -O https://github.com/TurboVNC/turbovnc/releases/download/3.1.1/turbovnc_3.1.1_${TARGETARCH}.deb && \
    apt-get update && \
    apt-get -y install ./turbovnc_3.1.1_${TARGETARCH}.deb && \
    rm turbovnc_3.1.1_${TARGETARCH}.deb && rm -rf /var/lib/apt/lists/* 
RUN addgroup --gid 1002 vglusers && adduser ros video && adduser ros vglusers
RUN apt-get update && \
    apt-get -y install xfce4-session xfce4-panel xfce4-terminal thunar xterm x11-utils python3-minimal python3-pip python3-numpy python3-venv unzip less tmux screen \
        geany-plugins geany \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        && \
    rm -rf /var/lib/apt/lists/*

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp


# Install noVNC

ENV NOVNC_VERSION=1.4.0
ENV WEBSOCKETIFY_VERSION=0.10.0

RUN mkdir -p /usr/local/novnc && \
    curl -sSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.zip -o /tmp/novnc-install.zip && \
    unzip /tmp/novnc-install.zip -d /usr/local/novnc && \
    cp /usr/local/novnc/noVNC-${NOVNC_VERSION}/vnc.html /usr/local/novnc/noVNC-${NOVNC_VERSION}/index.html && \
    curl -sSL https://github.com/novnc/websockify/archive/v${WEBSOCKETIFY_VERSION}.zip -o /tmp/websockify-install.zip && \
    unzip /tmp/websockify-install.zip -d /usr/local/novnc && \
    ln -s /usr/local/novnc/websockify-${WEBSOCKETIFY_VERSION} /usr/local/novnc/noVNC-${NOVNC_VERSION}/utils/websockify && \
    rm -f /tmp/websockify-install.zip /tmp/novnc-install.zip && \
    sed -i -E 's/^python /python3 /' /usr/local/novnc/websockify-${WEBSOCKETIFY_VERSION}/run

RUN cat <<EOF > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
    {
        "file_format_version" : "1.0.0",
        "ICD" : {
            "library_path" : "libEGL_nvidia.so.0"
        }
    }
EOF

COPY start-turbovnc.sh /opt/nvidia/entrypoint.d/90-turbovnc.sh
COPY start-turbovnc.sh /opt/entrypoint.d/90-turbovnc.sh 
RUN chmod +x /opt/nvidia/entrypoint.d/90-turbovnc.sh /opt/entrypoint.d/90-turbovnc.sh

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /opt/nvidia/entrypoint.d/89-ros.sh
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /opt/entrypoint.d/89-ros.sh

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

COPY lcas.jpg /usr/share/backgrounds/xfce/
COPY lcas.png /usr/share/backgrounds/xfce/

ENTRYPOINT ["/opt/entrypoint.sh"]
EXPOSE 5801

###########################################
# Install VSCode

RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
        curl -k -L -o /tmp/vscode.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64' ; \
    else \
        curl -k -L -o /tmp/vscode.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' ; \
    fi && \
    apt-get update && apt-get install -y /tmp/vscode.deb && \
    rm /tmp/vscode.deb && rm -rf /var/lib/apt/lists/*

# Install zrok
RUN curl -sSLfo /tmp/zrok-install.bash https://get.openziti.io/install.bash && \
    bash /tmp/zrok-install.bash zrok && \
    rm /tmp/zrok-install.bash


RUN mkdir -p /opt/image

###########################################
FROM openglvnc as user
USER ros
ENV HOME=/home/ros
WORKDIR ${HOME}
RUN mkdir -p ${HOME}/.local/bin 

# install a Python venv overlay to allow pip and friends
ENV PYTHONUNBUFFERED=1
RUN python3 -m venv --system-site-packages --upgrade-deps ${HOME}/.local/venv 
# Enable venv
ENV PATH="${HOME}/.local/venv/bin:$PATH"
COPY --chown=ros:ros requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt
# needed as quick fix for https://github.com/pypa/setuptools/issues/4483
RUN pip install -U setuptools[core]

USER root
COPY .gi? /tmp/gittemp/.git
RUN git -C /tmp/gittemp log -n 1 --pretty=format:"%H" > /opt/image/version

RUN echo "# Welcome to the L-CAS Desktop Container.\n" > /opt/image/info.md; \
    echo "This is a Virtual Desktop provided by [L-CAS](https://lcas.lincoln.ac.uk/)." >> /opt/image/info.md; \
    echo "It provides an installation of ROS2 **'${ROS_DISTRO}'**, running on **Ubuntu '$(lsb_release -s -c)'** on architecture **'$(uname -m)'**.\n" >> /opt/image/info.md; \
    echo "You can access it via a web browser at port 5801, e.g. http://localhost:5801 (or wherever you have exposed its internal port)." >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "*built from https://github.com/LCAS/ros-docker-images\n(commit: [\`$(cat /opt/image/version)\`](https://github.com/LCAS/ros-docker-images/tree/$(cat /opt/image/version)/)),\nprovided to you by [L-CAS](https://lcas.lincoln.ac.uk/).*" >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "## Installed Software\n" >> /opt/image/info.md; \
    echo "The following software is installed:" >> /opt/image/info.md; \
    echo "* ROS2 \`${ROS_DISTRO}\`, with rudimentary packages installed (base)." >> /opt/image/info.md; \
    echo "* VSCode (use as \`code\`, sandbox disabled)" >> /opt/image/info.md; \
    echo "* The L-CAS ROS2 [apt repositories](https://lcas.lincoln.ac.uk/apt/lcas) are enabled." >> /opt/image/info.md; \
    echo "* The L-CAS [rosdistro](https://github.com/LCAS/rosdistro) is enabled." >> /opt/image/info.md; \
    echo "* The Zenoh ROS2 bridge \`zenoh-bridge-ros2dds\` (version: ${ZENOH_BRIDGE_VERSION})." >> /opt/image/info.md; \
    echo "* A Python Venv overlay in \`/home/ros/.local/venv\` (version: \`$(python --version)\`, active by default)." >> /opt/image/info.md; \
    echo "* Node.js (with npm) in version $(node --version)." >> /opt/image/info.md; \
    echo "* password-less \`sudo\` to install more packages." >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "## Tips & Tricks\n" >> /opt/image/info.md; \
    echo "* run \`code tunnel user login\` to register for remote VSCode tunnel access, then run \`code tunnel\` to start a tunnel" >> /opt/image/info.md; \
    echo "* use [zrok](https://zrok.io/) to forward local ports" >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "## Default Environment\n" >> /opt/image/info.md; \
    echo "The following environment variables are set by default:" >> /opt/image/info.md; \
    echo '```' >> /opt/image/info.md; \
    env >> /opt/image/info.md; \
    echo '```' >> /opt/image/info.md; \
    chmod -w /opt/image/info.md
COPY README.md /opt/image/README.md
    
USER ros

RUN mkdir -p ${HOME}/Desktop/ && \
    ln -s /opt/image/info.md ${HOME}/Desktop/info.md && \
    ln -s /opt/image/README.md ${HOME}/Desktop/README.md

# disable sandbox in VSCode
RUN echo "alias code='code --no-sandbox'" >> ${HOME}/.bashrc

RUN mkdir -p ${HOME}/.vscode && \
    echo "{" > ${HOME}/.vscode/argv.json && \
    echo "    \"disable-chromium-sandbox\": true," >> ${HOME}/.vscode/argv.json && \
    echo "    \"enable-crash-reporter\": false" >> ${HOME}/.vscode/argv.json && \
    echo "}" >> ${HOME}/.vscode/argv.json

RUN mkdir -p ~/.config/rosdistro && echo "index_url: https://raw.github.com/LCAS/rosdistro/master/index-v4.yaml" > ~/.config/rosdistro/config.yaml
RUN rosdep update --rosdistro=$ROS_DISTRO
RUN sudo apt-get purge -y xfce4-screensaver

ENV DISPLAY=:1
ENV TVNC_VGL=1
ENV VGL_ISACTIVE=1
ENV VGL_FPS=25
ENV VGL_COMPRESS=0
ENV VGL_DISPLAY=egl
ENV VGL_WM=1
ENV VGL_PROBEGLX=0
ENV LD_PRELOAD=/usr/lib/libdlfaker.so:/usr/lib/libvglfaker.so
ENV SHELL=/bin/bash


