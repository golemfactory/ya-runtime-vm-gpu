all: vmlinuz-virt

build: build-img vmlinuz-virt

vmlinuz-virt:
	$(SHELL) copy_img golemfactory/golem_nvidia_base /boot/vmlinuz-5.10.29 ./vmlinuz-virt

build-img: Dockerfile 
	docker build -t golemfactory/golem_nvidia_base .

clean:
	rm -f vmlinuz-virt > /dev/null 2>&1
	docker rmi -f golemfactory/golem_nvidia_base > /dev/null 2>&1

.PHONY: all
