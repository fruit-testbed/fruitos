# Building FruitOS image

1. Clone the repository:

  ```
  git clone https://github.com/fruit-testbed/fruitos
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

4. Ensure `/etc/apk/repositories` contains:

	```
	http://dl-cdn.alpinelinux.org/alpine/v3.7/main
	http://dl-cdn.alpinelinux.org/alpine/v3.7/community
	```

5. Copy FruitOS private key into submodule **apks** to sign software packages.
   For example, if `fruit-apk-key.rsa` is the private key file, then invoke:

	```
	cp fruit-apk-key-20180528.rsa apks/
	```

6. Copy FruitOS public key into host:

  ```
  cp apks/packages/fruit-keys/fruit-apk-key-20180528.rsa.pub /etc/apk/keys/
  ```

7. Build FruitOS images:

  a. For Raspberry Pi **Zero**, **Zero-W**, and **1**:

    ```
    MACHINE=rpi make
    ```

  b. For Raspberry Pi **2** and **3 (32-bit)**:

    ```
    MACHINE=rpi2 make
    ```

  The above commands produce an image file `fruitos.img.gz`.



## Clean-Up

Invoke `make clean`.

