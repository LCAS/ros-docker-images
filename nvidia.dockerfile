ARG BASE_IMAGE=lcas.lincoln.ac.uk/lcas/docker_cuda_desktop:jammy-cuda12.2-1

###########################################
FROM ${BASE_IMAGE} AS base
ARG ROS_DISTRO=humble
USER root

ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive

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
    ros-${ROS_DISTRO}-ros-base \
    python3-argcomplete \
    bash-completion \
    build-essential \
    cmake \
    gdb \
    git \
    openssh-client \
    python3-argcomplete \
    python3-pip \
    python3-venv \
    ros-dev-tools \
    ros-${ROS_DISTRO}-ament-* \
    vim \  
    lsb-release \
    curl \
    software-properties-common \
    unzip \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

ENV AMENT_PREFIX_PATH=/opt/ros/${ROS_DISTRO}
ENV COLCON_PREFIX_PATH=/opt/ros/${ROS_DISTRO}
ENV LD_LIBRARY_PATH=/opt/ros/${ROS_DISTRO}/lib
ENV PATH=/opt/ros/${ROS_DISTRO}/bin:$PATH
ENV PYTHONPATH=/opt/ros/${ROS_DISTRO}/local/lib/python3.10/dist-packages:/opt/ros/${ROS_DISTRO}/lib/python3.10/site-packages
ENV ROS_PYTHON_VERSION=3
ENV ROS_VERSION=2

RUN rosdep init || echo "rosdep already initialized"
RUN curl -o /etc/ros/rosdep/sources.list.d/20-default.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/20-default.list && \
    curl -o /etc/ros/rosdep/sources.list.d/50-lcas.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/50-lcas.list

# Set up autocompletion for user
RUN  echo "if [ -f /opt/ros/${ROS_DISTRO}/setup.bash ]; then source /opt/ros/${ROS_DISTRO}/setup.bash; fi" >> /home/$USERNAME/.bashrc \
  && echo "if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash; fi" >> /home/$USERNAME/.bashrc

ENV AMENT_CPPCHECK_ALLOW_SLOW_VERSIONS=1

###########################################
FROM base AS additions

ARG TARGETARCH

# install cyclone DDS and other ROS and system dependencies
RUN apt-get update && \
    apt-get -y install \
        geany-plugins geany \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        ros-${ROS_DISTRO}-rviz2 \
        && \
    rm -rf /var/lib/apt/lists/*

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /opt/entrypoint.d/89-ros.sh


###########################################
# Install VSCode (disabled)

# RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
#         curl -k -L -o /tmp/vscode.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64' ; \
#     else \
#         curl -k -L -o /tmp/vscode.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' ; \
#     fi && \
#     apt-get update && apt-get install -y /tmp/vscode.deb && \
#     rm /tmp/vscode.deb && rm -rf /var/lib/apt/lists/*

# Install zrok
RUN curl -sSLfo /tmp/zrok-install.bash https://get.openziti.io/install.bash && \
    bash /tmp/zrok-install.bash zrok && \
    rm /tmp/zrok-install.bash


# prepare a user venv
RUN mkdir -p /opt/image && mkdir -p /opt/venv && chown ros:ros /opt/venv

###########################################
FROM additions AS user
USER ros
ENV HOME=/home/ros
WORKDIR ${HOME}
RUN mkdir -p ${HOME}/.local/bin 

# install a Python venv overlay to allow pip and friends
RUN python3 -m venv --system-site-packages --upgrade-deps /opt/venv 
# Enable venv
ENV PATH="/opt/venv/bin:$PATH"
# needed as quick fix for https://github.com/pypa/setuptools/issues/4483
RUN pip install -U setuptools[core]
COPY --chown=ros:ros requirements.txt /tmp/requirements.txt
# install some basic python pip packages
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# provide preconfigured zrok endpoint for lcas
RUN mkdir -p ${HOME}/.zrok && echo '{"api_endpoint": "https://zrok.zrok.lcas.group", "default_frontend": ""}' > ${HOME}/.zrok/config.json
RUN mkdir -p ~/.config/rosdistro && echo "index_url: https://raw.github.com/LCAS/rosdistro/master/index-v4.yaml" > ~/.config/rosdistro/config.yaml

# switch to root for further setup ##############################################
USER root
COPY .gi? /tmp/gittemp/.git
RUN git -C /tmp/gittemp log -n 1 --pretty=format:"%H" > /opt/image/version

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
ENV DEBIAN_FRONTEND=


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
    echo "* The L-CAS ROS2 [apt repositories](https://lcas.lincoln.ac.uk/apt/lcas) are enabled." >> /opt/image/info.md; \
    echo "* The L-CAS [rosdistro](https://github.com/LCAS/rosdistro) is enabled." >> /opt/image/info.md; \
    echo "* The Zenoh ROS2 bridge \`zenoh-bridge-ros2dds\` (version: ${ZENOH_BRIDGE_VERSION})." >> /opt/image/info.md; \
    echo "* A Python Venv overlay in \`/opt/venv\` (version: \`$(python --version)\`, active by default for the main user)." >> /opt/image/info.md; \
    echo "* Node.js (with npm) in version $(node --version)." >> /opt/image/info.md; \
    echo "* password-less \`sudo\` to install more packages." >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "## Tips & Tricks\n" >> /opt/image/info.md; \
    echo "* use [zrok](https://zrok.io/) to forward local ports" >> /opt/image/info.md; \
    echo "\n" >> /opt/image/info.md; \
    echo "## Default Environment\n" >> /opt/image/info.md; \
    echo "The following environment variables are set by default:" >> /opt/image/info.md; \
    echo '```' >> /opt/image/info.md; \
    env >> /opt/image/info.md; \
    echo '```' >> /opt/image/info.md; \
    chmod -w /opt/image/info.md
COPY README.md /opt/image/README.md

# switch to main user `ros` for further setup ##############################################
USER ros

RUN mkdir -p ${HOME}/Desktop/ && \
    ln -sf /opt/image/info.md ${HOME}/Desktop/info.md && \
    ln -sf /opt/image/README.md ${HOME}/Desktop/README.md

RUN rosdep update --rosdistro=${ROS_DISTRO}



