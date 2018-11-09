# FruitOS

Latest version: <b>0.4.0</b>.

A lean Linux OS distribution for Raspberry Pi, developed based on
[Alpine Linux](https://alpinelinux.org), featuring:

- A/B Root Partitions
- Over-the-Air update
- Remote configuration managements
- Support Docker and Singularity containers

FruitOS image files can be downloaded from: https://fruit-testbed.org/os/images/

Supported boards:
- RaspberryPi [Zero](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi0.img.gz),
  [Zero-W](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi0.img.gz),
  [1](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi1.img.gz),
  [2](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi2.img.gz),
  3 ([32-bit](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi3.img.gz),
     [64-bit](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi3-aarch64.img.gz)),
  3B+ ([32-bit](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi3.img.gz),
       [64-bit](https://fruit-testbed.org/os/images/fruitos-0.4.0-raspberrypi3-aarch64.img.gz))


## Setup Raspberry Pi

1. Install [fruit-cli](https://github.com/fruit-testbed/fruit-cli) through Python Pip:

    ```sh
    $ pip install fruit-cli
    ```

2. Register your account by following [the instructions](https://github.com/fruit-testbed/fruit-cli#registering-an-account).

3. Download a [FruitOS image](https://fruit-testbed.org/os/images) that is suitable for your Raspberry Pi,
   and burn it on an SD card using [Etcher](https://etcher.io) or **dd**.

4. Make a note of your new account's public key by running `fruit-cli
   account public-key`. You will need it in the next step.

    ```sh
    $ fruit-cli account public-key
    aNsXAGLzB3C5j-tQSl4McNzVjqeegY4TKbDCeFYCUvc
    ```

5. Mount the boot partition of the SD card (label: FRUITOS,
   filesystem: FAT32), and open file `fruit.json` with a text editor.
   Put your public key into field `public-key` and save the change.
   Close the file and unmount the SD card.

6. Mount the SD card to your Raspberry Pi, then power it up. If the
   configurations are correct, then the OS will automatically register
   the node to the management server. You can check it by listing the
   registered node using:

   ```sh
   $ fruit-cli node list
   ```

   To get the IP address of your Raspberry Pi, look at the `network`
   field of the output of `fruit-cli node monitor`:

   ```sh
   $ fruit-cli node monitor --node <pi-node-id>
   ```

   You can automate this by using a tool such as [`jq`](https://stedolan.github.io/jq/):

   ```sh
   $ fruit-cli --json node monitor --node <pi-node-id> | jq 'to_entries[].value.network'
   ```


## Accessing Raspberry Pi

Every Raspberry Pi can be accessed through:

1. Serial console, by connecting monitor and keyboard to Pi's display and USB ports respectively.
   The default username is `root` without password.

2. SSH with public key authentication (password-authentication is disabled). You can use **fruit-cli**
   to add your public key to the management server:

   ```sh
   $ fruit-cli key add --keyfile <my-public-key-file>
   ```

   Afterwards, the management server will distribute the public key to your Raspberry Pis so that you
   can SSH (username: root):

   ```
   $ ssh -i <my-private-key-file> root@<pi-address>
   ```
