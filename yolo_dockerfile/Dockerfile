# NVIDIA CUDA + Ubuntu 22.04 (matches host ROS 2 Humble Python 3.10)
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# System deps + ROS 2 apt source prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    ca-certificates \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libqt5gui5 \
    && rm -rf /var/lib/apt/lists/*

# ROS 2 Humble apt source (official method, docs.ros.org)
RUN add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
        > /etc/apt/sources.list.d/ros2.list

# ROS 2 Humble base (provides rclpy) + CycloneDDS RMW.
# CycloneDDS is required: FastDDS shared memory transport breaks across
# container boundary even with --ipc host (verified 2026-04-29).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ros-base \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Python deps — ultralytics + torch resolve numpy automatically (numpy 2.x supported)
RUN pip3 install --upgrade pip \
    && pip3 install --no-cache-dir ultralytics opencv-python scipy

WORKDIR /workspace

ENV QT_X11_NO_MITSHM=1

# Source ROS 2 setup before exec'ing command
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
