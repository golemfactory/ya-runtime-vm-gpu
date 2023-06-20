BUILDDIR=$(CURDIR)/build

all: $(BUILDDIR)


$(BUILDDIR): Dockerfile
	mkdir -p $(BUILDDIR)
	docker build -t golemfactory/build-qemu .
	$(SHELL) copy_img golemfactory/build-qemu vmrt $(BUILDDIR)/.
	$(SHELL) copy_img golemfactory/build-qemu /qemu/pc-bios/vgabios-stdvga.bin $(BUILDDIR)/.

clean:
	rm -rf $(BUILDDIR) > /dev/null 2>&1
	docker rmi -f golemfactory/build-qemu > /dev/null 2>&1

.PHONY: all
