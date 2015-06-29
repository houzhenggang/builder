weimarnetz firmware builder
===========================

* community: http://wireless.subsignal.org
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)


Need support?
join the [club](http://www.weimarnetz.de) or ask for [consulting](http://bittorf-wireless.de)

how to get a release for a specific hardware
--------------------------------------------
To build weimarnetz images on your own, you need some preparation steps and one line together with some options for hardware, features and packages. The commands are shown below.

All config options reside in openwrt-config/ and consist of fragments of openwrt config files or patch scripts you need to modify some files. You can add your own config file,hardware files must be named ```config_HARDWARE.NAME.txt```, features names are ```config_NAME.txt```.
Patch files must be saved in openwrt-patches/ and their name should descripe what they do.

With meta files we can group hardware bundles, patches and feature packs to use cases. They are named ```config_meta.NAME.txt```.

You need to choose exactly one hardware and use it as the first argument prefixed with ```HARDWARE.```, either in a meta package or in one build line (see example).

### Prerequisites

If you build OpenWrt or Weimarnetz firmware for the first time on your computer, you need to install some software before: 
	
	# be root user
	apt-get update
	LIST="build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev quilt screen"
	for PACKAGE in $LIST; do apt-get -y install $PACKAGE; done

### Build steps

Those steps describe how to build images for all ar71xx based devices:

* clone this repository: ```git clone https://github.com/weimarnetz/builder.git```
* change to directory builder
* run ```./build_release.sh <options>``` where options can be
 * a meta package like ```i./build_release.sh meta.ffweimar-4MBtrunk```
 * a complete build line ```./build_release.sh ffweimar_standard patch:901-minstrel-try-all-rates.patch patch:luci-remove-freifunk-firewall.patch ffweimar_luci_standard hostapd vtunnoZlibnoSSL i18n_german https owm shrink tc busybox busybox_swap use_trunk```
* both line will have the same result
* you'll find images in ```openwrt/bin/ar71xx/```

### Description of packages, bundles, patches and features

meta packages (see references to hardware, patches and features below):

meta package | comment
------------ | -------
meta.ffweimar-4MB | contains ffweimar_standard, patch:901-minstrel-try-all-rates.patch, patch:luci-remove-freifunk-firewall.patch, ffweimar_luci_standard, hostapd, vtunnoZlibnoSSL, i18n_german, https, owm, shrink, tc, busybox, busybox
meta.ffweimar-4MBtrunk | contains meta.ffweimar-4MB, use_trunke
meta.ffweimar-meshkit | contains meta.ffweimar-4MB, imagebuilder, options

hardware bundles:

hardware | comment
-------- | -------
ar71xx | build all ar71xx based hardware (recommanded)
TP-LINK TLWR841ND | build TP-Link WR841N/ND images
Ubiquiti Bullet M | build Ubiquity images, mostly suitable for Bullets and Nanostations

Sometimes we need to patch some errors, because the won't be fixed that fast in openwrt or our requirements differ from the default approach. A patch in a commandline starts with ```patch:``` followed by the file name.

patches:

patch | comment
----- | -------
luci-remove-freifunk-firewall.patch | removes the firewall package from dependencies as we use our own tools
901-minstrel-try-all-rates-patch | changes minstrel behaviour to try all Wifi rates, without this patch wifi will fall back very often to 1MBit/s
openwrt-remove-ppp-firewall-from-deps.patch | removes pppoe and firewall from standard build, helps to reduce size
openwrt-remove-wpad-mini-from-deps.patch | removes wpad-mini from standard build, helps to reduce size

There some features you can add to your image and to the build process. They're simply added to the commandline by name.

feature packs:

feature | explanation
------- | -----------
busybox | configures busybox standard features
busybox_swap | use swap tools from busybox instead of heavy original tools
ffweimar_standard | contains packages suitable and required for all weimarnetz installations
ffweimar_luci_standard | adds luci as standard web interface
hostapd | installs hostapd-mini to enable wireless AP (note: WPA isn't included)
https | enables https feature for uhhtpd
i18n_german | adds german translations
imagesbuilder | creates the imagebuilder file that is used for meshkit installations
options | creates a lot of modules that won't be included to the image by default. you can find these packages in bin/_arch_/packages
owm | installs openwifimap client to support http://map.weimarnetz.de
shrink | removes debug symbols to save space
switch | adds tools for advanced switch config (e.g. ethtool, mii-tool)
tc | adds traffic control, i.e. to optimize olsr links
vtunnoZlibnoSSL | vpn client configured to connect to our vpn servers
use_trunk | build latest openwrt trunk instead of revisions written in openwrt-config/git_revs. add this option at the end of your line.
use_bb1407 | build from trunk ofbarrier breaker 14.07 final repo instead of revisions written in openwrt-config/git_revs from dev repos. add this option at the end of your line.

