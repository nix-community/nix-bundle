# UNSTABLE, Breaking changes may be done without warning.

# nix-bundle

nix-bundle is a way to package Nix attributes into single-file executables.

## Benefits

* Single-file output
* Can be run by non-root users
* No runtime
* Distro agnostic
* No installation

## Getting started

Make sure you have installed Nix already. See http://nixos.org/nix/ for more details.

Once you have a working Nix install, you can run:

```sh
$ ./nix-bundle.sh hello /bin/hello
```

```hello``` indicates the Nix derivation from NixPkgs that you want to use, while ```/bin/hello``` indicates the path of the executable relative to ```hello``` that you want to run. This will create the file "hello". Running it:

```sh
$ ./hello
Hello, world!
```

This is a standalone file that is completely portable! As long as you are running the same architecture Linux kernel and have a shell interpreter available it will run.

Some others to try:

```sh
./nix-bundle.sh nano /bin/nano
```

```sh
./nix-bundle.sh emacs /bin/emacs
```

Or if you want to try graphical applications:

```sh
# Simple X game. Very few dependencies. Quick to build and load. ~13MB
./nix-bundle.sh xskat /bin/xskat
```

```sh
./nix-bundle.sh firefox /bin/firefox
```

```sh
# SDL-based game. ~228MB
./nix-bundle.sh ivan /bin/ivan
```

### Using the `nix bundle` command

This command is provided by Nix, so that Nix ends up calling `nix-bundle` for you.
It requires the `nix-command` and `flakes` experimental features to be enabled.

We use `meta.mainProgram` attribute and other indicators to decide which executable to bundle.

```sh
nix bundle nixpkgs#hello --bundler github:nix-community/nix-bundle
```

## Self-bundling (meta)

Starting with v0.1.3, you can bundle nix-bundle! To do this, just use nix-bundle normally:

```sh
NIX_PATH="nixpkgs=https://github.com/matthewbauer/nixpkgs/archive/nix-bundle.tar.gz" ./nix-bundle.sh nix-bundle /bin/nix-bundle
```

## [Experimental] Create AppImage executables from Nix expressions

"nix-bundle.sh" tends to create fairly large outputs. This is largely because nix-bundle.sh "extracts" its payload up front. AppImage uses a different method where extraction only takes place when the file is accessed (through FUSE and SquashFS). You can now create a compliant "AppImage" using the "nix2appimage.sh" script:

```sh
./nix2appimage.sh emacs
```

This will create a file at Emacs-x86_64.AppImage which you can execute.

Notice that there is only one argument for nix2appimage.sh. This is because the target executable will be detected from the .desktop file in ```/share/applications/*.desktop```. As a side-effect, AppImage requires your package to have a .desktop file, so packages like "hello", "coreutils", etc. will not work.

Some other examples to try:

```sh
./nix2appimage.sh firefox
```

```sh
./nix2appimage.sh vlc
```

```sh
./nix2appimage.sh 0ad
```

```sh
./nix2appimage.sh wireshark-gtk
```

These may take a while because of the large closure size.

Note that these do not currently work out of the box with NixOS. Other Linux distros should work.

## Comparison with AppImage, FlatPak, Snap

| Name       | Distro-agnostic | Runtime required | Root required | Storage |
| ---------- | --------------- | ---------------- | ------------- | ------- |
| nix-bundle | yes | no  | no  | Arx tarball                    | 
| AppImage   | yes | no  | no  | Squashfs w/ lzma compression   |
| FlatPak    | yes | yes | no  | ?                              |
| Snap       | yes | yes | no  | squashFS                       |

## How it works

Nix-bundle glues together four different projects to work correctly:

* [Arx](https://github.com/solidsnack/arx) - an archive execution tool
* Creates single-file archive executable that can unpack themselves and then run some command. nix-bundle calls nix-user-chroot to bootstrap the Nix environment. It outputs a "./nix" folder.
* [nix-user-chroot](https://github.com/lethalman/nix-user-chroot) - a small bootstrap that uses Linux namespaces to call chroot
  * This will create sub namespace and bind mount the "./nix" to "/nix" so that the Nix references function properly.
* [Nix](https://nixos.org/nix/) - a functional package manager
  * Used to build runtime closures that are self-contained.
* [nixpkgs](https://nixos.org/nixpkgs/)
  * Provides lots of different packages to choose from.

## Drawbacks

Nix-bundle has some drawbacks that need to be worked on:

* Slow startup
* Large files (Firefox 150MB)
* Only compatible Linux
* Outputs built on x86-64 will not run on i386
* Requires Linux kernel with CAP_SYS_USER_NS on and permissions setup correctly
