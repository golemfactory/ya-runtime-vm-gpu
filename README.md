# ya-runtime-vm-nvidia

$${\color{red}WARNING! }$$ [here

Please be aware that this experimental runtime's (`ya-runtime-vm-nvidia`) goal is to provide GPU support to Golem Network. If configured correctly it will make your GPU available as a resource on Golem Network via PCI Passthrough.

It is an experimental feature in its very early stage and consequently comes with **NO** guarantees. It was tested on a limited number of hosts and supports Nvidia GPU only. Downloading and installing this runtime (`ya-runtime-vm-nvidia`) is not sufficient to make this experimental feature to work. Some changes on host setup itself are required too. High level instruction of such changes and other important information should be available in this Github Repository.

As an extremely experimental feature Golem Factory gives **NO** guarantees regarding its security or that it will even work. There is a chance that Golem Factory will not be able to help you out in case that something does not work or go wrong. Please proceed with caution.

If still in doubt please refer to Disclaimer, User Interaction Guidelines and Privacy Policy available at Golem webpage: https://www.golem.network/

## Installation

Running this provider is supported only via Live USB image:
https://github.com/golemfactory/golem-gpu-live

## Apps

Apps meant to be executed on `ya-runtime-vm-nvidia` should use [golem-nvidia-base](golem_nvidia_base/README.md) as a base image.

In order to match with GPU offering provider an app needs to list `!exp:gpu` among its required [capabilities](https://yapapi.readthedocs.io/en/latest/api.html#module-yapapi.payload.vm).
