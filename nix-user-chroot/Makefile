ENV_PATH ?= ""

nix-user-chroot: main.cpp
	${CXX} -std=c++20 -o nix-user-chroot -DENV_PATH='$(ENV_PATH)' main.cpp
