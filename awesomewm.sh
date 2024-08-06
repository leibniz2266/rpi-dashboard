#!/bin/bash

# This script is just to set up AwesomeWM on a new Arch device, for testing, until I figure everything out.


# Update and upgrade system packages
sudo pacman -Syu --noconfirm

# Install the necessary packages
sudo pacman -S --noconfirm git xorg-server lightdm awesome awesome-terminal-fonts lua lxtask htop picom dillo midori netsurf mousepad sc-im networkmanager pcmanfm feh lxappearance lxterminal neofetch rofi dmenu scrot

# Clone the lain library for Awesome WM
git clone https://github.com/lcpz/lain.git ~/.config/awesome/lain

# Clone the awesome-copycats repository with submodules
git clone --recurse-submodules --depth 1 https://github.com/lcpz/awesome-copycats.git

# Move the cloned files to the Awesome configuration directory
mv -bv awesome-copycats/{*,.[^.]*} ~/.config/awesome
rm -rf awesome-copycats

# Copy the template configuration file to rc.lua
cp ~/.config/awesome/rc.lua.template ~/.config/awesome/rc.lua

# Modify rc.lua as needed
sed -i 's/{5}/{7}/g' ~/.config/awesome/rc.lua

# Enable and start LightDM service
sudo systemctl enable lightdm
sudo systemctl start lightdm
