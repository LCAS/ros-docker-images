ARG BASE_IMAGE=ros:humble-ros-base-jammy

FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y lsb-release curl software-properties-common apt-transport-https && \
    apt-get clean

RUN sh -c 'echo "deb https://lcas.lincoln.ac.uk/apt/lcas $(lsb_release -sc) lcas" > /etc/apt/sources.list.d/lcas-latest.list' && \
    curl -s https://lcas.lincoln.ac.uk/apt/repo_signing.gpg | tee /etc/apt/trusted.gpg.d/lcas-latest.gpg

RUN rosdep init || true
RUN curl -o /etc/ros/rosdep/sources.list.d/20-default.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/20-default.list && \
    curl -o /etc/ros/rosdep/sources.list.d/50-lcas.list https://raw.githubusercontent.com/LCAS/rosdistro/master/rosdep/sources.list.d/50-lcas.list

ENV ROSDISTRO_INDEX_URL=https://raw.github.com/LCAS/rosdistro/master/index-v4.yaml
