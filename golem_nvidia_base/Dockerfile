ARG LINUX_VER=5.10.29
ARG NVIDIA_VER=525.85.05

FROM ubuntu:focal-20230605 as linux

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \ 
	&& apt-get install -y \
	wget \
	kmod \
	gcc \
	make \
	xz-utils \
	flex \
	bison \
	libssl-dev \
	libelf-dev \
	bc \
	pkg-config \
	&& rm -rf /var/lib/apt/lists/*

FROM linux as linux_builder

ARG LINUX_VER
ARG NVIDIA_VER

WORKDIR /usr/src

RUN wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.xz \
	&& tar xavf linux-${LINUX_VER}.tar.xz \
	&& wget https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VER}/NVIDIA-Linux-x86_64-${NVIDIA_VER}-no-compat32.run \
	&& chmod +x NVIDIA-Linux-x86_64-${NVIDIA_VER}-no-compat32.run

FROM linux_builder

ARG LINUX_VER
ARG NVIDIA_VER

WORKDIR /usr/src

COPY config-virt config-virt

RUN mv config-virt linux-${LINUX_VER}/.config \ 
	&& cd linux-${LINUX_VER} \
	&& make olddefconfig \
	&& make -j $(($(nproc --all)-1)) \
	&& make install \
	&& make modules_install \
	&& cd .. \
	&& ./NVIDIA-Linux-x86_64-${NVIDIA_VER}-no-compat32.run -k ${LINUX_VER} -s --kernel-source-path=/usr/src/linux-${LINUX_VER} \
	&& rm -rf /usr/src/*
