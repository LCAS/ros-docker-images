# Official L-CAS enabled ROS base images

Use this as the base image for your ROS containerisation projects. 

Adds simple configuration layers on top of the official ROS images at https://hub.docker.com/_/ros. The additional config does the following:

1. add the L-CAS Ubuntu repository (and key), i.e. `"deb https://lcas.lincoln.ac.uk/apt/lcas $(lsb_release -sc) lcas"`
1. configure the L-CAS ROS distribution (which is an extension to the official ROS ones):
    * add the L-CAS rosdeps (which are an extension to the official ROS ones), see https://github.com/LCAS/rosdistro/tree/master/rosdep
    * configure the master index to be https://raw.githubusercontent.com/LCAS/rosdistro/master/index-v4.yaml

That's all. The images can be used from our registry as `lcas.lincoln.ac.uk/lcas/ros:<TAG>`, where `<TAG>` mirrors a subset of the [tags of the official ROS images](https://hub.docker.com/_/ros/tags) (configured in the [workflow](.github/workflows/docker-build.yaml)).
