FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.12.3
ARG BAZEL_VERSION=6.3.2

# --------------------------
# Essential tools & deps
# --------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common wget git zip build-essential curl gnupg lsb-release \
    locales apt-transport-https pkg-config libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
    libncurses5-dev libreadline-dev libsqlite3-dev libssl-dev tk-dev uuid-dev zlib1g-dev libasio-dev \
    libboost-test-dev libboost-filesystem-dev libgmock-dev libgtest-dev doxygen cmake unzip \
    nlohmann-json3-dev libtclap-dev python3-pip cmake-format ninja-build make gdb lldb valgrind cppcheck bear universal-ctags lcov gcovr \
    clang lld clangd clang-tidy g++ \
    && rm -rf /var/lib/apt/lists/*

# --------------------------
# Install Bazel
# --------------------------
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /usr/share/keyrings/bazel-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list

RUN apt-get update && apt-get install -y bazel-${BAZEL_VERSION} && \
    ln -s /usr/bin/bazel-${BAZEL_VERSION} /usr/bin/bazel && rm -rf /var/lib/apt/lists/*

# --------------------------
# Build and install Python 3.12.x from source
# --------------------------
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xzf Python-${PYTHON_VERSION}.tgz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && make -j$(nproc) && make install && \
    cd .. && rm -rf Python-${PYTHON_VERSION} Python-${PYTHON_VERSION}.tgz

# Setup python and pip links
RUN ln -sf /usr/local/bin/python3 /usr/local/bin/python

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    /usr/local/bin/python3 get-pip.py && rm get-pip.py

# Upgrade pip, setuptools, wheel and install empy for ROS python tools
RUN /usr/local/bin/python3 -m pip install --upgrade pip setuptools wheel empy

# --------------------------
# Setup locale and ROS2 repo
# --------------------------
RUN locale-gen en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-dev-tools \
    ros-jazzy-desktop \
    ros-jazzy-ros-base \
    ros-jazzy-turtlesim \
    '~nros-jazzy-rqt*' \
    && rm -rf /var/lib/apt/lists/*

# --------------------------
# Source ROS in shell config
# --------------------------
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "export LANG=en_US.UTF-8" >> /root/.bashrc && \
    echo "export LC_ALL=en_US.UTF-8" >> /root/.bashrc

# --------------------------
# Install and build GoogleTest (required for cucumber-cpp)
# --------------------------
RUN cd /usr/src/googletest && cmake . && make && cp lib/*.a /usr/lib || true

# --------------------------
# Install cucumber-cpp for C++
# --------------------------
WORKDIR /opt
RUN git clone https://github.com/cucumber/cucumber-cpp.git
RUN cd cucumber-cpp && mkdir build && cd build && \
    cmake .. -DCUKE_ENABLE_EXAMPLES=off -DCUKE_ENABLE_TESTS=off -DCUKE_USE_GTEST=on && \
    make -j$(nproc) && make install

# --------------------------
# Install cucumber + debug tools for Python
# --------------------------

RUN /usr/local/bin/python3 -m pip install \
    pre-commit \
    pre-commit-hooks \
    autopep8 \
    pylint \
    mypy \
    isort \
    shellcheck-py \
    black \
    shfmt-py \
    clang-format \
    gitlint \
    behave \
    robber \ 
    pytest \ 
    coverage \
    ruff 
# --------------------------
# Cleanup and environment
# --------------------------
ENV PATH="/usr/local/bin:${PATH}"
ENV PYTHONPATH="/usr/local/lib/python3.12/site-packages:${PYTHONPATH}"

RUN apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/requirements_cpp /tmp/requirements_python ~/.cache/pip

WORKDIR /vision_training