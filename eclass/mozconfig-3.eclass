# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $
#
# mozconfig.eclass: the new mozilla.eclass

inherit multilib flag-o-matic mozcoreconf-2

IUSE="+alsa bindist gnome +dbus debug +ipc libnotify startup-notification system-sqlite +webm wifi"

RDEPEND="app-arch/zip
	app-arch/unzip
	>=app-text/hunspell-1.2
	dev-libs/expat
	>=dev-libs/glib-2.26
	>=dev-libs/libIDL-0.8.0
	>=dev-libs/libevent-1.4.7
	!<x11-base/xorg-x11-6.7.0-r2
	>=x11-libs/cairo-1.10.2[X]
	>=x11-libs/gtk+-2.8.6
	>=x11-libs/pango-1.10.1
	virtual/jpeg
	alsa? ( media-libs/alsa-lib )
	dbus? ( >=dev-libs/dbus-glib-0.72 )
	gnome? ( libnotify? ( >=x11-libs/libnotify-0.4 ) )
	startup-notification? ( >=x11-libs/startup-notification-0.8 )
	system-sqlite? ( >=dev-db/sqlite-3.7.4[fts3,secure-delete,unlock-notify,debug=] )
	webm? ( media-libs/libvpx 
		media-libs/alsa-lib )
	wifi? ( net-wireless/wireless-tools )"

DEPEND="${RDEPEND}"

mozconfig_config() {
	if ${SM} || ${XUL} || ${TB} || ${FF} || ${IC}; then
	    mozconfig_annotate thebes --enable-default-toolkit=cairo-gtk2
	else
	    mozconfig_annotate -thebes --enable-default-toolkit=gtk2
	fi

	if [[ ${PN} = firefox || ${PN} = thunderbird ]]; then
		mozconfig_use_enable !bindist official-branding
	fi

	mozconfig_use_enable alsa ogg
	mozconfig_use_enable alsa wave
	mozconfig_use_enable dbus
	mozconfig_use_enable debug
	mozconfig_use_enable debug tests
	mozconfig_use_enable debug debugger-info-modeules
	mozconfig_use_enable ipc
	mozconfig_use_enable libnotify
	mozconfig_use_enable startup-notification
	mozconfig_use_enable system-sqlite
	if use system-sqlite; then
		mozconfig_annotate '' --with-sqlite-prefix="${EPREFIX}"/usr
	fi
	mozconfig_use_enable wifi necko-wifi

	if ${SM} || ${XUL} || ${FF} || ${IC}; then
		if use webm && ! use alsa; then
			echo "Enabling alsa support due to webm request"
			mozconfig_annotate '+webm -alsa' --enable-ogg
			mozconfig_annotate '+webm -alsa' --enable-wave
			mozconfig_annotate '+webm' --enable-webm
		else
			mozconfig_use_enable webm
			mozconfig_use_with webm system-libvpx
		fi
	fi

	if ${SM} || ${XUL} || ${FF} || ${IC}; then
		if use amd64 || use x86 || use arm || use sparc; then
			mozconfig_annotate '' --enable-tracejit
		fi
	fi

	if ${SM} || ${TB} || ${XUL}; then
		MEXTENSIONS="default"
		mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	fi

	# These are enabled by default in all mozilla applications
	mozconfig_annotate '' --with-system-nspr --with-nspr-prefix="${EPREFIX}"/usr
	mozconfig_annotate '' --with-system-nss --with-nss-prefix="${EPREFIX}"/usr
	mozconfig_annotate '' --x-includes="${EPREFIX}"/usr/include --x-libraries="${EPREFIX}"/usr/$(get_libdir)
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-system-hunspell
	mozconfig_annotate '' --disable-gnomevfs
	mozconfig_annotate '' --enable-gio
	mozconfig_annotate '' --with-system-libevent="${EPREFIX}"/usr
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'broken' --disable-mochitest
}