# FruitOS

This repository contains files to build FruitOS image.


## How to build FruitOS image

1. Install required software:

	```
	apk update
	apk add make git
	```

2. Initialize and update git submodules

	```
	git submodule init
	git submodule update
	```

3. Ensure the following entries available in `/etc/apk/repositories`:

	```
	http://dl-cdn.alpinelinux.org/alpine/v3.6/main
	http://dl-cdn.alpinelinux.org/alpine/v3.6/community
	http://dl-cdn.alpinelinux.org/alpine/edge/testing
	```

4. Copy FruitOS private key into submodule **apks** to sign software packages:

	```
	cp fruit-apk-key.rsa apks/
	```

5. Build software packages and FruitOS image for Raspberry Pi 2, 3, and compute module 3:

	```
	make
	```
    If everything goes well, then you will find a FruitOS image file: `disk.img`.

    If you want to build an image for Raspberry Pi Zero, Zero-W, 1, and compute module, then you have to invoke:

	```
	MACHINE=rpi make
	```
