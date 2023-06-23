all: vmlinuz-virt

build: build-img vmlinuz-virt

vmlinuz-virt:
	$(SHELL) copy_img pwalski/golem_nvidia_base /boot/vmlinuz-5.10.29 ./vmlinuz-virt

build-img: Dockerfile 
	docker build -t pwalski/golem_nvidia_base .

clean:
	rm -f vmlinuz-virt > /dev/null 2>&1
	docker rmi -f pwalski/golem_nvidia_base > /dev/null 2>&1

.PHONY: all
