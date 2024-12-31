.PHONY: build run_nvidia run_ubuntu
.DEFAULT_GOAL:=build

NVIDIA_BASE_IMAGE:=nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04
NVIDIA_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:noble-rolling-cuda12.6-opengl
UBUNTU_BASE_IMAGE:=ubuntu:noble
UBUNTU_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:noble-rolling
ROS_DISTRO:=rolling

nvidia:
	@echo "Building the nvidia image..."
	docker build -t $(NVIDIA_DEST_TAG) --build-arg BASE_IMAGE=$(NVIDIA_BASE_IMAGE) --build-arg ROS_DISTRO=$(ROS_DISTRO) --progress=plain -f nvidia.dockerfile .

ubuntu:
	@echo "Building the ubuntu image..."
	docker build -t $(UBUNTU_DEST_TAG) --build-arg BASE_IMAGE=$(UBUNTU_BASE_IMAGE) --build-arg ROS_DISTRO=$(ROS_DISTRO) -f nvidia.dockerfile .

build: nvidia ubuntu

run_nvidia: nvidia
	@echo "Running the project..."
	-docker run --rm --runtime runc -p 5801:5801 -it $(NVIDIA_DEST_TAG) /bin/bash

run_ubuntu: ubuntu
	@echo "Running the project..."
	-docker run --rm -p 6080 -it $(UBUNTU_DEST_TAG) /bin/bash

