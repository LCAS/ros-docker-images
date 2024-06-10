.PHONY: build run_nvidia run_ubuntu
.DEFAULT_GOAL:=build

NVIDIA_BASE_IMAGE:=nvidia/cuda:11.8.0-runtime-ubuntu22.04
NVIDIA_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:jammy-humble-cuda-opengl
UBUNTU_BASE_IMAGE:=ubuntu:jammy
UBUNTU_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:jammy-humble
ROS_DISTRO:=humble

nvidia:
	@echo "Building the nvidia image..."
	docker build -t $(NVIDIA_DEST_TAG) --build-arg BASE_IMAGE=$(NVIDIA_BASE_IMAGE) --build-arg ROS_DISTRO=$(ROS_DISTRO) -f Dockerfile.opengl .

ubuntu:
	@echo "Building the ubuntu image..."
	docker build -t $(UBUNTU_DEST_TAG) --build-arg BASE_IMAGE=$(UBUNTU_BASE_IMAGE) --build-arg ROS_DISTRO=$(ROS_DISTRO) -f Dockerfile.opengl .

build: nvidia ubuntu

run_nvidia: nvidia
	@echo "Running the project..."
	-docker run --rm --gpus all -p 5801:5801 -it $(NVIDIA_DEST_TAG) /bin/bash

run_ubuntu: ubuntu
	@echo "Running the project..."
	-docker run --rm -p 5801:5801 -it $(UBUNTU_DEST_TAG) /bin/bash

