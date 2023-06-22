all: vmlinuz-virt

vmlinuz-virt: Dockerfile
	docker build -t golemfactory/golem_nvidia_base .
	$(SHELL) copy_img golemfactory/golem_nvidia_base /boot/vmlinuz-5.10.29 ./vmlinuz-virt

clean:
	rm -f vmlinuz-virt > /dev/null 2>&1
	docker rmi -f golemfactory/golem_nvidia_base > /dev/null 2>&1

.PHONY: all
