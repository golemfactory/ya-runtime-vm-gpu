all: vmlinuz-virt

vmlinuz-virt: Dockerfile
	docker build -t golemfactory/vmlinuz_nvidia .
	$(SHELL) copy_img golemfactory/vmlinuz_nvidia /boot/vmlinuz-5.10.29 ./vmlinuz-virt

clean:
	rm -f vmlinuz-virt > /dev/null 2>&1
	docker rmi -f golemfactory/vmlinuz_nvidia > /dev/null 2>&1

.PHONY: all
