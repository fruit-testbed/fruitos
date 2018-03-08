# Building FruitOS image

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

3. Replace the content of `/etc/apk/repositories` with:

	```
	http://dl-cdn.alpinelinux.org/alpine/v3.7/main
	http://dl-cdn.alpinelinux.org/alpine/v3.7/community
	```

4. Copy FruitOS private key into submodule **apks** to sign software packages.
   For example, if `fruit-apk-key.rsa` is the private key file, then invoke:

	```
	cp fruit-apk-key.rsa apks/
	```

5. Build software packages and FruitOS image for Raspberry Pi 2, 3, and compute module 3:

	```
	make
	```
    If everything goes well, then you will find a FruitOS image file: `fruitos.img.gz`.

    If you want to build an image for Raspberry Pi Zero, Zero-W, 1, and compute module, then you have to invoke:

	```
	MACHINE=rpi make
	```
