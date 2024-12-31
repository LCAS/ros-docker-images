# Official L-CAS enabled ROS base images

Use this as the base image for your ROS containerisation projects. 

Adds simple configuration layers on top of the official ROS images at https://hub.docker.com/_/ros. The additional config does the following:

1. add the L-CAS Ubuntu repository (and key), i.e. `"deb https://lcas.lincoln.ac.uk/apt/lcas $(lsb_release -sc) lcas"`
2. configure the L-CAS ROS distribution (which is an extension to the official ROS ones):
    * add the L-CAS rosdeps (which are an extension to the official ROS ones), see https://github.com/LCAS/rosdistro/tree/master/rosdep
    * configure the master index to be https://raw.githubusercontent.com/LCAS/rosdistro/master/index-v4.yaml

That's all. The images can be used from our registry as `lcas.lincoln.ac.uk/lcas/ros:<TAG>`, where `<TAG>` mirrors a subset of the [tags of the official ROS images](https://hub.docker.com/_/ros/tags) (configured in the [workflow](.github/workflows/docker-build.yaml)).

## Useful Notes

### Makefile
The [Makefile](https://github.com/LCAS/ros-docker-images/blob/main/Makefile) can be used for testing different builds with different base images. We provide two base images: one based on `nvidia`, which includes CUDA support, and the other based on `ubuntu`, which does not have CUDA support:

```bash
NVIDIA_BASE_IMAGE:=nvidia/cuda:11.8.0-runtime-ubuntu22.04
NVIDIA_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:jammy-humble-cuda-opengl
UBUNTU_BASE_IMAGE:=ubuntu:jammy
UBUNTU_DEST_TAG:=lcas.lincoln.ac.uk/lcas/ros:jammy-humble
ROS_DISTRO:=humble
```

To build both images, simply execute the Makefile in the terminal with `make`. To build a specific image, type `make nvidia`. To run the image, use `make run_nvidia` or `make run_ubuntu`.

The `nvidia` base image utilizes OpenGL for 3D GPU acceleration. To verify this after running the image, launch the following command inside the container:

```bash
/opt/VirtualGL/bin/glxspheres64
```

The output will report the processing frames per second:

```bash
ros@8b9788042eb6:/$ /opt/VirtualGL/bin/glxspheres64 
Polygons in scene: 62464 (61 spheres * 1024 polys/spheres)
GLX FB config ID of window: 0x11 (8/8/8/0)
Visual ID of window: 0x21
Context is Direct
OpenGL Renderer: NVIDIA GeForce GTX 1080 Ti/PCIe/SSE2
736.997364 frames/sec - 822.489059 Mpixels/sec
768.459693 frames/sec - 857.601017 Mpixels/sec
729.394007 frames/sec - 814.003712 Mpixels/sec
712.265822 frames/sec - 794.888657 Mpixels/sec
707.806523 frames/sec - 789.912080 Mpixels/sec
```

For visualization, open the following link in your browser: `http://localhost:5801/vnc.html`. If the code is still running, you should see this:
![image](https://github.com/LCAS/ros-docker-images/assets/47870260/4af26333-6640-42d8-b9a4-b6b95db42988)


### GitHub Actions Workflow: [Build OpenGL-supported Docker Images](https://github.com/LCAS/ros-docker-images/blob/main/.github/workflows/docker-build-opengl.yaml)
This GitHub Actions workflow automates the process of building and pushing Docker images with OpenGL support.

#### Workflow Trigger Conditions

This workflow is triggered under the following conditions:
- **Push Events**: When a push is made to the `main` branch or when any tag is pushed.
- **Pull Requests**: When a pull request is made to the `main` branch.
- **Scheduled Runs**: According to a cron schedule (`30 2 * * 0,2,4,6`), which means at 02:30 UTC on Sundays, Tuesdays, Thursdays, and Saturdays.
- **Manual Dispatch**: The workflow can also be triggered manually.

#### Jobs

##### Build Job

The `build` job runs on the `lcas` runner and uses a matrix strategy to build multiple Docker images based on different base images and ROS distributions.

###### Matrix Configuration

The matrix includes the following configurations:
- **Ubuntu Base Image**:
  - `base_image`: `ubuntu:jammy`
  - `ros_distro`: `humble`
  - `push_tag`: `lcas.lincoln.ac.uk/lcas/ros:jammy-humble`
- **NVIDIA Base Images**:
  - `base_image`: `nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04`
     - `ros_distro`: `humble`
     - `push_tag`: `lcas.lincoln.ac.uk/lcas/ros:jammy-humble-cuda11.8-opengl`
  - `base_image`: `nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04`
     - `ros_distro`: `humble`
     - `push_tag`: `lcas.lincoln.ac.uk/lcas/ros:jammy-humble-cuda12.1-opengl`
  - `base_image`: `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04`
     - `ros_distro`: `humble`
     - `push_tag`: `lcas.lincoln.ac.uk/lcas/ros:jammy-humble-cuda12.2-opengl`

###### Steps

1. **Setup Node.js**:
    - Uses the `actions/setup-node@v4` action to set up Node.js with version `^16.13.0` or `>=18.0.0`.

2. **Checkout Repository**:
    - Uses the `actions/checkout@v3` action to check out the repository.

3. **Set Branch Environment Variable**:
    - Runs a script to set the `BRANCH` environment variable to the current branch name.

4. **Docker Login to LCAS Registry**:
    - Uses the `docker/login-action@v3` action to log in to the LCAS Docker registry (skips this step for pull requests).
    - Requires `LCAS_REGISTRY_PUSHER` and `LCAS_REGISTRY_TOKEN` secrets for authentication.

5. **Build and Push Docker Image**:
    - Uses the `docker/build-push-action@v5` action to build and push the Docker image.
    - Builds the Docker image using the `./nvidia.dockerfile` file for opengl base image support with cuda, or `./Dockerfile` for normal ROS based images.
    - Sets the platform to `linux/amd64`.
    - Pushes the image unless it is a pull request.
    - Tags the image with the `matrix.push_tag`.
    - Sets build arguments for the base image, branch, and ROS distribution.
   ```bash
      with:
        context: .
        file: ./nvidia.dockerfile
        platforms: linux/amd64
        push: ${{ github.event_name != 'pull_request' }}
        tags: ${{ matrix.push_tag }}
        build-args: |
            BASE_IMAGE=${{ matrix.base_image }}
            BRANCH=${{ env.BRANCH }}
            ROS_DISTRO=${{ matrix.ros_distro }}
   ```
