# Building FruitOS image

1. Replace the content of `/etc/apk/repositories` with:

	```
	http://dl-cdn.alpinelinux.org/alpine/v3.8/main
	http://dl-cdn.alpinelinux.org/alpine/v3.8/community
	```

2. Install required software:

	```
	apk update
	apk add make git
	```

3. Initialize and update git submodules

	```
	git submodule init
	git submodule update
	```

4. Copy FruitOS private and public keys into submodule **apks** to
   sign software packages. For example, if `fruit-apk-key.rsa` is the
   private key file and `fruit-apk-key.rsa.pub` is the public key
   file, then invoke:

	```
	cp fruit-apk-key.rsa fruit-apk-key.rsa.pub apks/
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
