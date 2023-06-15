#!/bin/bash

pacman -Syyu --noconfirm
pacman -S --noconfirm openssl openssh curl gmp libev hidapi python
