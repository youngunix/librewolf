# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6
WANT_AUTOCONF="2.1"

PYTHON_COMPAT=( python3_{5,6,7} )
PYTHON_REQ_USE='ncurses,sqlite,ssl,threads(+)'
MOZCONFIG_OPTIONAL_WIFI=1

LLVM_MAX_SLOT=8

inherit check-reqs flag-o-matic toolchain-funcs eutils gnome2-utils llvm \
		mozconfig-v6.${PV%%.*} pax-utils xdg-utils autotools
inherit eapi7-ver

MOZ_PV="$(ver_cut 1-3)esr"
# https://dist.torproject.org/torbrowser
TOR_PV="$(ver_cut 4-6)"
if [[ -z ${PV%%*_alpha} ]]; then
	TOR_PV="$(ver_rs 2 a ${TOR_PV})"
else
	KEYWORDS="~amd64 ~x86"
fi
TOR_PV="${TOR_PV%.0}"
# https://gitweb.torproject.org/tor-browser.git/refs/tags
GIT_TAG="$(ver_cut 4-5)-$(ver_cut 7-8)"
GIT_TAG="tor-browser-${MOZ_PV}-$(ver_rs 3 '-build' ${GIT_TAG})"

DESCRIPTION="The Tor Browser"
HOMEPAGE="
	https://www.torproject.org/projects/torbrowser.html
	https://gitweb.torproject.org/tor-browser.git"

SLOT="0"
# BSD license applies to torproject-related code like the patches
# icons are under CCPL-Attribution-3.0
LICENSE="BSD CC-BY-3.0 MPL-2.0 GPL-2 LGPL-2.1"
IUSE="hardened hwaccel jack -screenshot selinux test"

SRC_URI="mirror://tor/${PN}/${TOR_PV}"
PATCH="firefox-${PV%%.*}.6-patches-05"
PATCH=( https://dev.gentoo.org/~{anarchy,axs,polynomial-c}/mozilla/patchsets/${PATCH}.tar.xz )
SRC_URI="
	https://gitweb.torproject.org/tor-browser.git/snapshot/${GIT_TAG}.tar.gz
	-> ${GIT_TAG}.tar.gz
	x86? (
		${SRC_URI}/tor-browser-linux32-${TOR_PV}_en-US.tar.xz
	)
	amd64? (
		${SRC_URI}/tor-browser-linux64-${TOR_PV}_en-US.tar.xz
	)
	${PATCH[@]}
"
RESTRICT="primaryuri"

ASM_DEPEND=">=dev-lang/yasm-1.1"

RDEPEND="
	>=dev-libs/nss-3.36.7
	>=dev-libs/nspr-4.19
	>=net-vpn/tor-0.3.3.9
	system-icu? ( >=dev-libs/icu-60.2 )
	jack? ( virtual/jack )
	selinux? ( sec-policy/selinux-mozilla )"

DEPEND="
	${RDEPEND}
	amd64? ( ${ASM_DEPEND} virtual/opengl )
	x86? ( ${ASM_DEPEND} virtual/opengl )"

S="${WORKDIR}/${GIT_TAG}"

QA_PRESTRIPPED="usr/lib*/${PN}/${PN}"

BUILD_OBJ_DIR="${WORKDIR}/torb"

llvm_check_deps() {
	if ! has_version "sys-devel/clang:${LLVM_SLOT}" ; then
		ewarn "sys-devel/clang:${LLVM_SLOT} is missing! Cannot use LLVM slot ${LLVM_SLOT} ..."
		return 1
	fi

	if use clang ; then
		if ! has_version "=sys-devel/lld-${LLVM_SLOT}*" ; then
			ewarn "=sys-devel/lld-${LLVM_SLOT}* is missing! Cannot use LLVM slot ${LLVM_SLOT} ..."
			return 1
		fi
	fi

	einfo "Will use LLVM slot ${LLVM_SLOT}!"
}

pkg_setup() {
	moz_pkgsetup

	# Avoid PGO profiling problems due to enviroment leakage
	# These should *always* be cleaned up anyway
	unset DBUS_SESSION_BUS_ADDRESS \
		DISPLAY \
		ORBIT_SOCKETDIR \
		SESSION_MANAGER \
		XDG_SESSION_COOKIE \
		XAUTHORITY

	addpredict /proc/self/oom_score_adj

	llvm_pkg_setup
}

pkg_pretend() {
	# Ensure we have enough disk space to compile
	CHECKREQS_DISK_BUILD="4G"

	check-reqs_pkg_setup
}

src_prepare() {
	local PATCHES=(
		"${WORKDIR}"/firefox

		# Revert "Change the default Firefox profile directory to be TBB-relative"
		"${FILESDIR}"/torbrowser-60.5.0-Do_not_store_data_in_the_app_bundle.patch
		"${FILESDIR}"/torbrowser-60.5.0-Change_the_default_Firefox_profile_directory.patch

		# FIXME: prevent warnings in bundled nss
		"${FILESDIR}"/torbrowser-60.5.0-nss-fixup-warnings.patch
	)

	# Enable gnomebreakpad
	if use debug ; then
		sed -i -e "s:GNOME_DISABLE_CRASH_DIALOG=1:GNOME_DISABLE_CRASH_DIALOG=0:g" \
			"${S}"/build/unix/run-mozilla.sh || die "sed failed!"
	fi

	# Ensure that our plugins dir is enabled as default
	sed -i -e "s:/usr/lib/mozilla/plugins:/usr/lib/nsbrowser/plugins:" \
		"${S}"/xpcom/io/nsAppFileLocationProvider.cpp || die "sed failed to replace plugin path for 32bit!"
	sed -i -e "s:/usr/lib64/mozilla/plugins:/usr/lib64/nsbrowser/plugins:" \
		"${S}"/xpcom/io/nsAppFileLocationProvider.cpp || die "sed failed to replace plugin path for 64bit!"

	# Fix sandbox violations during make clean, bug 372817
	sed -e "s:\(/no-such-file\):${T}\1:g" \
		-i "${S}"/config/rules.mk \
		-i "${S}"/nsprpub/configure{.in,} \
		|| die

	# Don't exit with error when some libs are missing which we have in
	# system.
	sed '/^MOZ_PKG_FATAL_WARNINGS/s@= 1@= 0@' \
		-i "${S}"/browser/installer/Makefile.in || die

	# Don't error out when there's no files to be removed:
	sed 's@\(xargs rm\)$@\1 -f@' \
		-i "${S}"/toolkit/mozapps/installer/packager.mk || die

	# Keep codebase the same even if not using official branding
	sed '/^MOZ_DEV_EDITION=1/d' \
		-i "${S}"/browser/branding/aurora/configure.sh || die

	default

	# Autotools configure is now called old-configure.in
	# This works because there is still a configure.in that happens to be for the
	# shell wrapper configure script
	eautoreconf old-configure.in

	# Must run autoconf in js/src
	cd "${S}"/js/src || die
	eautoconf old-configure.in
}

src_configure() {
	MEXTENSIONS="default"

	# Add information about TERM to output (build.log) to aid debugging
	# blessings problems
	if [[ -n "${TERM}" ]] ; then
		einfo "TERM is set to: \"${TERM}\""
	else
		einfo "TERM is unset."
	fi

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	# enable JACK, bug 600002
	mozconfig_use_enable jack

	# Add full relro support for hardened
	if use hardened; then
		append-ldflags "-Wl,-z,relro,-z,now"
		mozconfig_use_enable hardened hardening
	fi

	# Disable built-in ccache support to avoid sandbox violation, #665420
	# Use FEATURES=ccache instead!
	mozconfig_annotate '' --without-ccache
	sed -i -e 's/ccache_stats = None/return None/' \
		python/mozbuild/mozbuild/controller/building.py || \
		die "Failed to disable ccache stats call"

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"

	# allow elfhack to work in combination with unstripped binaries
	# when they would normally be larger than 2GiB.
	append-ldflags "-Wl,--compress-debug-sections=zlib"

	if use clang ; then
		# https://bugzilla.mozilla.org/show_bug.cgi?id=1423822
		mozconfig_annotate 'elf-hack is broken when using Clang' --disable-elf-hack
	fi

	echo "mk_add_options MOZ_OBJDIR=${BUILD_OBJ_DIR}" >> "${S}"/.mozconfig
	echo "mk_add_options XARGS="${EPREFIX}"/usr/bin/xargs" >> "${S}"/.mozconfig

	# Use .mozconfig settings from torbrowser (setting this here since it gets overwritten by mozcoreconf-v6.eclass)
	# see https://gitweb.torproject.org/tor-browser.git/tree/.mozconfig?h=tor-browser-60.2.0esr-8.0-1
	echo "mk_add_options MOZ_APP_DISPLAYNAME=\"Tor Browser\"" >> "${S}"/.mozconfig
	echo "mk_add_options MOZILLA_OFFICIAL=1" >> "${S}"/.mozconfig
	echo "mk_add_options BUILD_OFFICIAL=1" >> "${S}"/.mozconfig
	mozconfig_annotate 'torbrowser' --enable-official-branding
	mozconfig_annotate 'torbrowser' --disable-webrtc
	mozconfig_annotate 'torbrowser' --disable-eme
	mozconfig_annotate 'torbrowser' --enable-proxy-bypass-protection

	# Rename the binary and set the profile location
	mozconfig_annotate 'torbrowser' --with-app-name="${PN}"
	mozconfig_annotate 'torbrowser' --with-app-basename="${PN}"

	# see https://gitweb.torproject.org/tor-browser.git/tree/old-configure.in?h=tor-browser-60.2.0esr-8.0-1#n3205
	mozconfig_annotate 'torbrowser' --with-tor-browser-version="${TOR_PV}"
	mozconfig_annotate 'torbrowser' --disable-tor-browser-update

	echo "mk_add_options MOZ_OBJDIR=${BUILD_OBJ_DIR}" >> "${S}"/.mozconfig
	echo "mk_add_options XARGS="${EPREFIX}"/usr/bin/xargs" >> "${S}"/.mozconfig

	# Default mozilla_five_home no longer valid option
	sed '/with-default-mozilla-five-home=/d' -i "${S}"/.mozconfig

	# Finalize and report settings
	mozconfig_final

	# workaround for funky/broken upstream configure...
	SHELL="${SHELL:-${EPREFIX}/bin/bash}" MOZ_NOSPAM=1 \
	./mach configure || die
}

src_compile() {
	MOZ_MAKE_FLAGS="${MAKEOPTS}" SHELL="${SHELL:-${EPREFIX}/bin/bash}" MOZ_NOSPAM=1 \
	./mach build --verbose || die
}

src_install() {
	cd "${BUILD_OBJ_DIR}" || die

	# Pax mark xpcshell for hardened support, only used for startupcache creation.
	pax-mark m "${BUILD_OBJ_DIR}"/dist/bin/xpcshell

	touch "${BUILD_OBJ_DIR}/dist/bin/browser/defaults/preferences/all-gentoo.js" \
		|| die

	mozconfig_install_prefs \
		"${BUILD_OBJ_DIR}/dist/bin/browser/defaults/preferences/all-gentoo.js"

	# Augment this with hwaccel prefs
	if use hwaccel ; then
		printf 'pref("%s", true);\npref("%s", true);\n' \
		layers.acceleration.force-enabled webgl.force-enabled >> \
		"${BUILD_OBJ_DIR}/dist/bin/browser/defaults/preferences/all-gentoo.js" \
		|| die
	fi

	if ! use screenshot; then
		echo "pref(\"extensions.screenshots.disabled\", true);" >> \
			"${BUILD_OBJ_DIR}/dist/bin/browser/defaults/preferences/all-gentoo.js" \
			|| die
	fi

	# Must ensure we use bundled nss/nspr during signing and not system
	cd "${S}"
	MOZ_MAKE_FLAGS="${MAKEOPTS}" SHELL="${SHELL:-${EPREFIX}/bin/bash}" MOZ_NOSPAM=1 \
	DESTDIR="${D}" ./mach install || die

	# Install icons and .desktop for menu entry
	local size icon_path
	icon_path="${S}/browser/branding/official"
	for size in 16 32 48 64 128 256; do
		newicon -s ${size} "${icon_path}/default${size}.png" ${PN}.png
	done
	make_desktop_entry ${PN} "Tor Browser" ${PN} "Network;WebBrowser" "StartupWMClass=Torbrowser"

	# Add StartupNotify=true bug 237317
	if use startup-notification ; then
		echo "StartupNotify=true"\
			 >> "${ED}/usr/share/applications/${PN}-${PN}.desktop" \
			|| die
	fi

	# Required in order to use plugins and even run torbrowser on hardened.
	pax-mark m "${ED}"${MOZILLA_FIVE_HOME}/{${PN},plugin-container}

	# Profile with settings and extensions
	insinto ${MOZILLA_FIVE_HOME}/defaults/profile
	doins -r "${WORKDIR}"/tor-browser_en-US/Browser/TorBrowser/Data/Browser/profile.default/{extensions,bookmarks.html}

	# see: https://trac.torproject.org/projects/tor/ticket/11751#comment:2
	# see: https://github.com/Whonix/anon-ws-disable-stacked-tor/blob/master/usr/lib/anon-ws-disable-stacked-tor/torbrowser.sh
	dodoc "${FILESDIR}/99torbrowser.example"

	dodoc "${WORKDIR}/tor-browser_en-US/Browser/TorBrowser/Docs/ChangeLog.txt"
}

pkg_preinst() {
	gnome2_icon_savelist

	# if the apulse libs are available in MOZILLA_FIVE_HOME then apulse
	# doesn't need to be forced into the LD_LIBRARY_PATH
	if use pulseaudio && has_version ">=media-sound/apulse-0.1.9" ; then
		einfo "APULSE found - Generating library symlinks for sound support"
		local lib
		pushd "${ED}"${MOZILLA_FIVE_HOME} &>/dev/null || die
		for lib in ../apulse/libpulse{.so{,.0},-simple.so{,.0}} ; do
			# a quickpkg rolled by hand will grab symlinks as part of the package,
			# so we need to avoid creating them if they already exist.
			if ! [ -L ${lib##*/} ]; then
				ln -s "${lib}" ${lib##*/} || die
			fi
		done
		popd &>/dev/null || die
	fi
}

pkg_postinst() {
	ewarn "This patched firefox build is _NOT_ recommended by Tor upstream but uses"
	ewarn "the exact same sources. Use this only if you know what you are doing!"
	elog "Torbrowser uses port 9150 to connect to Tor. You can change the port"
	elog "in the connection settings to match your setup."

	gnome2_icon_cache_update
	xdg_desktop_database_update

	if use pulseaudio && has_version ">=media-sound/apulse-0.1.9"; then
		elog "Apulse was detected at merge time on this system and so it will always be"
		elog "used for sound.  If you wish to use pulseaudio instead please unmerge"
		elog "media-sound/apulse."
		elog
	fi
}

pkg_postrm() {
	gnome2_icon_cache_update
	xdg_desktop_database_update
}
