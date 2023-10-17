# golem-nvidia-base

Docker base image for Golem applications using Nvidia GPU.

Depending on usecase application might need to start Xorg:

```bash
Xorg vt10 :0 &
export DISPLAY=:0
```

It will require `/etc/X11/xorg.conf`.

Example of a [xorg.conf](../self_test_img/xorg.conf.nvidia-headless) used by `ya-runtime-vm-nvidia`'s internal test app.
