# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/mozilla-firefox/mozilla-firefox-2.0.0.9.ebuild,v 1.7 2007/11/12 16:57:25 drac Exp $

WANT_AUTOCONF="2.1"

inherit flag-o-matic toolchain-funcs eutils mozconfig-minefield makeedit multilib fdo-mime autotools mozilla-launcher

#PATCH="${PN}-2.0.0.8-patches-0.2"
LANGS="be ca cs de el es-AR es-ES eu fi fr fy-NL gu-IN ja ko nb-NO nl pa-IN  pl pt-PT ro ru sk sv-SE tr uk zh-CN"
NOSHORTLANGS="es-AR"

MY_PV=${PV/_beta/b}
MY_P="${PN}-${MY_PV}"

DESCRIPTION="Firefox Web Browser"
HOMEPAGE="http://www.mozilla.org/projects/firefox/"

KEYWORDS="~alpha ~amd64 ~ia64 ~ppc ~sparc ~x86 ~x86-fbsd"
SLOT="0"
LICENSE="MPL-1.1 GPL-2 LGPL-2.1"
IUSE="java mozdevelop bindist xforms restrict-javascript filepicker +xulrunner"
EAPI="1"

MOZ_URI="http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${MY_PV}"
SRC_URI="${MOZ_URI}/source/firefox-${MY_PV}-source.tar.bz2"
#	mirror://gentoo/${PATCH}.tar.bz2"


# These are in
#
#  http://releases.mozilla.org/pub/mozilla.org/firefox/releases/${PV}/linux-i686/xpi/
#
# for i in $LANGS $SHORTLANGS; do wget $i.xpi -O ${P}-$i.xpi; done
for X in ${LANGS} ; do
	SRC_URI="${SRC_URI}
		linguas_${X/-/_}? ( http://dev.gentooexperimental.org/~armin76/dist/${MY_P}-xpi/${MY_P}-${X}.xpi )"
	IUSE="${IUSE} linguas_${X/-/_}"
	# english is handled internally
	if [ "${#X}" == 5 ] && ! has ${X} ${NOSHORTLANGS}; then
		SRC_URI="${SRC_URI}
			linguas_${X%%-*}? ( http://dev.gentooexperimental.org/~armin76/dist/${MY_P}-xpi/${MY_P}-${X}.xpi )"
		IUSE="${IUSE} linguas_${X%%-*}"
	fi
done

RDEPEND="java? ( virtual/jre )
	>=www-client/mozilla-launcher-1.39
	>=sys-devel/binutils-2.16.1
	>=dev-libs/nss-3.12_alpha1
	>=dev-libs/nspr-4.7.0_pre20071218
	>=app-text/hunspell-1.1.9
	>=media-libs/lcms-1.17
	xulrunner? ( >=net-libs/xulrunner-1.9_beta2 )"


DEPEND="${RDEPEND}
	java? ( >=dev-java/java-config-0.2.0 )"

PDEPEND="restrict-javascript? ( x11-plugins/noscript )"

S="${WORKDIR}/mozilla"

# Needed by src_compile() and src_install().
# Would do in pkg_setup but that loses the export attribute, they
# become pure shell variables.
export MOZ_CO_PROJECT=browser
export BUILD_OFFICIAL=1
export MOZILLA_OFFICIAL=1

linguas() {
	local LANG SLANG
	for LANG in ${LINGUAS}; do
		if has ${LANG} en en_US; then
			has en ${linguas} || linguas="${linguas:+"${linguas} "}en"
			continue
		elif has ${LANG} ${LANGS//-/_}; then
			has ${LANG//_/-} ${linguas} || linguas="${linguas:+"${linguas} "}${LANG//_/-}"
			continue
		elif [[ " ${LANGS} " == *" ${LANG}-"* ]]; then
			for X in ${LANGS}; do
				if [[ "${X}" == "${LANG}-"* ]] && \
					[[ " ${NOSHORTLANGS} " != *" ${X} "* ]]; then
					has ${X} ${linguas} || linguas="${linguas:+"${linguas} "}${X}"
					continue 2
				fi
			done
		fi
		ewarn "Sorry, but mozilla-firefox does not support the ${LANG} LINGUA"
	done
}

pkg_setup(){
	if ! built_with_use x11-libs/cairo X; then
		eerror "Cairo is not built with X useflag."
		eerror "Please add 'X' to your USE flags, and re-emerge cairo."
		die "Cairo needs X"
	fi

	if ! use bindist; then
		elog "You are enabling official branding. You may not redistribute this build"
		elog "to any users on your network or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
		elog "You can disable it by emerging ${PN} _with_ the bindist USE-flag"

	fi

	use moznopango && warn_mozilla_launcher_stub
}

src_unpack() {
	unpack firefox-${MY_PV}-source.tar.bz2 
# ${PATCH}.tar.bz2
	
	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_unpack "${MY_P}-${X}.xpi"
	done
	if [[ ${linguas} != "" ]]; then
		einfo "Selected language packs (first will be default): ${linguas}"
	fi

	# Apply our patches
	cd "${S}" || die "cd failed"
	EPATCH_SUFFIX="patch" \
	EPATCH_FORCE="yes" \
#	epatch "${WORKDIR}"/patch

	epatch "${FILESDIR}"/hppa.patch
#	epatch "${FILESDIR}"/ia64.patch
	epatch "${FILESDIR}"/fbsd.patch
	epatch "${FILESDIR}"/055_firefox-2.0_gfbsd-pthreads.patch
#	epatch "${FILESDIR}"/888_fix_nss_fix_389872.patch
#	epatch "${FILESDIR}"/033_firefox-2.0_ppc_powerpc.patch

	#correct the cairo/glitz mess, if using system libs
	epatch "${FILESDIR}"/666_mozilla-glitz-cairo.patch
	#add the standard gentoo plugins dir
	epatch "${FILESDIR}"/064_firefox-nsplugins-v3.patch
	#make it use the system iconv
	epatch "${FILESDIR}"/165_native_uconv.patch
	#make it use system hunspell and correct the loading of dicts
	epatch "${FILESDIR}"/100_system_myspell-v2.patch
	#make it use system sqlite3
	#epatch "${FILESDIR}"/101_system_sqlite3.patch
	#make loading certs behave with system nss
	epatch "${FILESDIR}"/068_firefox-nss-gentoo-fix.patch
	#
	epatch "${FILESDIR}"/667_typeahead-broken-v2.patch
	#system headers should be wrapped thanks b33fc0d3 for the hint
	#epatch "${FILESDIR}"/668_system-headers.patch
	#some forgotten parts of some revised patch, breaking happily builds
	epatch "${FILESDIR}"/669_forgotten_tales_387196.patch
	#make minefield install its icon 
	epatch "${FILESDIR}"/998_install_icon.patch
	if use xulrunner; then
		#make minefield build against xulrunner
		epatch "${FILESDIR}"/999_minefield_against_xulrunner-v2.patch
	fi
	#fix the unfixable gnome loves firefox
	if ! use gnome; then
		epatch "${FILESDIR}"/777_minefield-no-icons.patch
	fi


	####################################
	#
	# behavioral fixes
	#
	####################################

	#rpath patch
	epatch "${FILESDIR}"/063_firefox-rpath-3.patch
	eautoreconf || die "failed  running eautoreconf"
}

src_compile() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS="default,typeaheadfind"

	#if use xforms; then
	#	MEXTENSIONS="${MEXTENSIONS},xforms"
	#fi
	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate 'broken' --disable-mochitest
	mozconfig_annotate 'broken' --disable-crashreporter
	mozconfig_annotate '' --enable-native-uconv
	mozconfig_annotate '' --enable-system-hunspell
	#mozconfig_annotate '' --enable-system-sqlite3
	mozconfig_annotate '' --enable-image-encoder=all
	mozconfig_annotate '' --enable-canvas
	mozconfig_annotate '' --with-system-nspr
	mozconfig_annotate '' --with-system-nss
	mozconfig_annotate '' --enable-system-lcms
	mozconfig_annotate '' --enable-oji --enable-mathml
	mozconfig_annotate 'places' --enable-storage --enable-places --enable-places_bookmarks

	# Other ff-specific settings
	#mozconfig_use_enable mozdevelop jsd
	#mozconfig_use_enable mozdevelop xpctools
	mozconfig_use_extension mozdevelop venkman
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}
	if use xulrunner; then
		# Add xulrunner variable
		mozconfig_annotate '' --with-libxul-sdk
	fi

	if ! use bindist; then
		mozconfig_annotate '' --enable-official-branding
	fi

	# Finalize and report settings
	mozconfig_final

	# -fstack-protector breaks us
	if gcc-version ge 4 1; then
		gcc-specs-ssp && append-flags -fno-stack-protector
	else
		gcc-specs-ssp && append-flags -fno-stack-protector-all
	fi
	filter-flags -fstack-protector -fstack-protector-all

	####################################
	#
	#  Configure and build
	#
	####################################

	CPPFLAGS="${CPPFLAGS} -DARON_WAS_HERE" \
	CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
	econf || die

	# It would be great if we could pass these in via CPPFLAGS or CFLAGS prior
	# to econf, but the quotes cause configure to fail.
	sed -i -e \
		's|-DARON_WAS_HERE|-DGENTOO_NSPLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsplugins\\\" -DGENTOO_NSBROWSER_PLUGINS_DIR=\\\"/usr/'"$(get_libdir)"'/nsbrowser/plugins\\\"|' \
		${S}/config/autoconf.mk \
		${S}/toolkit/content/buildconfig.html

	# This removes extraneous CFLAGS from the Makefiles to reduce RAM
	# requirements while compiling
	edit_makefiles

	# Should the build use multiprocessing? Not enabled by default, as it tends to break
	[ "${WANT_MP}" = "true" ] && jobs=${MAKEOPTS} || jobs="-j1"
	emake ${jobs} || die
}

pkg_preinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	einfo "Removing old installs with some really ugly code.  It potentially"
	einfo "eliminates any problems during the install, however suggestions to"
	einfo "replace this are highly welcome.  Send comments and suggestions to"
	einfo "mozilla@gentoo.org."
	rm -rf "${ROOT}"/"${MOZILLA_FIVE_HOME}"
}

src_install() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	if use xulrunner; then
		PKG_CONFIG=`which pkg-config`
		X_DATE=`date +%Y%m%d`
		XULRUNNER_VERSION=`${PKG_CONFIG} --modversion xulrunner-xpcom`
		XULRUNNER=`which xulrunner`
	fi

	# Most of the installation happens here
	dodir "${MOZILLA_FIVE_HOME}"
	cp -RL "${S}"/dist/bin/* "${D}"/"${MOZILLA_FIVE_HOME}"/ || die "cp failed"

	linguas
	for X in ${linguas}; do
		[[ ${X} != "en" ]] && xpi_install "${WORKDIR}"/"${MY_P}-${X}"
	done

	local LANG=${linguas%% *}
	if [[ -n ${LANG} && ${LANG} != "en" ]]; then
		elog "Setting default locale to ${LANG}"
		dosed -e "s:general.useragent.locale\", \"en-US\":general.useragent.locale\", \"${LANG}\":" \
			"${MOZILLA_FIVE_HOME}"/defaults/pref/firefox.js \
			"${MOZILLA_FIVE_HOME}"/defaults/pref/firefox-l10n.js || \
			die "sed failed to change locale"
	fi

	# Install icon and .desktop for menu entry
	if ! use bindist; then
		doicon "${FILESDIR}"/icon/firefox-icon.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5.desktop \
			mozilla-firefox-2.0.desktop
	else
		doicon "${FILESDIR}"/icon/firefox-icon-unbranded.png
		newmenu "${FILESDIR}"/icon/mozilla-firefox-1.5-unbranded.desktop \
			mozilla-firefox-2.0.desktop
	fi

	dodir ${MOZILLA_FIVE_HOME}/greprefs
	cp ${FILESDIR}/gentoo-default-prefs.js ${D}${MOZILLA_FIVE_HOME}/greprefs/all-gentoo.js
	dodir ${MOZILLA_FIVE_HOME}/defaults/pref
	cp ${FILESDIR}/gentoo-default-prefs.js ${D}${MOZILLA_FIVE_HOME}/defaults/pref/all-gentoo.js

	if use xulrunner; then
		#set the application.ini
		sed -i -e "s|BuildID=.*$|BuildID=${X_DATE}GentooMozillaFirefox|"	"${D}"/usr/$(get_libdir)/${PN}/application.ini
		sed -i -e "s|MinVersion=.*$|MinVersion=${XULRUNNER_VERSION}|" "${D}"/usr/$(get_libdir)/${PN}/application.ini
		sed -i -e "s|MaxVersion=.*$|MaxVersion=${XULRUNNER_VERSION}|" "${D}"/usr/$(get_libdir)/${PN}/application.ini

		echo "#!/bin/bash" > "${T}"/firefox
		echo "${XULRUNNER} ${MOZILLA_FIVE_HOME}/application.ini \"\$@\"" >> "${T}"/firefox
		dobin "${T}"/firefox
	else
		# Create /usr/bin/firefox
		install_mozilla_launcher_stub firefox "${MOZILLA_FIVE_HOME}"

		# Install files necessary for applications to build against firefox
		einfo "Installing includes and idl files..."
		cp -LfR "${S}"/dist/include "${D}"/"${MOZILLA_FIVE_HOME}" || die "cp failed"
		cp -LfR "${S}"/dist/idl "${D}"/"${MOZILLA_FIVE_HOME}" || die "cp failed"
		# Dirty hack to get some applications using this header running
		dosym "${MOZILLA_FIVE_HOME}"/include/necko/nsIURI.h \
			"${MOZILLA_FIVE_HOME}"/include/nsIURI.h

		# Install pkgconfig files
#		insinto /usr/"$(get_libdir)"/pkgconfig
#		doins "${S}"/build/unix/*.pc
	fi

	
}

pkg_postinst() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	ewarn "This is a preliminary version of mozilla-firefox"
	ewarn "so all the stuff against, won't work, please don't"
	ewarn "file any bugs about this"

	# This should be called in the postinst and postrm of all the
	# mozilla, mozilla-bin, firefox, firefox-bin, thunderbird and
	# thunderbird-bin ebuilds.
	update_mozilla_launcher_symlinks

	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update

	elog "Please remember to rebuild any packages that you have built"
	elog "against Firefox. Some packages might be broken by the upgrade; if this"
	elog "is the case, please search at http://bugs.gentoo.org and open a new bug"
	elog "if one does not exist. Before filing any bugs, please move or remove"
	elog " ~/.mozilla and test with a clean profile directory."
}

pkg_postrm() {
	declare MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	update_mozilla_launcher_symlinks
}

