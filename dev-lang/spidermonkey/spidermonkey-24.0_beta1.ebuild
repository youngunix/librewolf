# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-lang/spidermonkey/spidermonkey-17.0.0-r1.ebuild,v 1.1 2013/08/10 02:43:06 axs Exp $

EAPI="5"
WANT_AUTOCONF="2.1"
PYTHON_COMPAT=( python2_{6,7} )
PYTHON_REQ_USE="threads"
inherit eutils toolchain-funcs multilib python-any-r1 versionator pax-utils

MY_PN="mozjs"
MY_P="${MY_PN}-${PV}"
DESCRIPTION="Stand-alone JavaScript C library"
HOMEPAGE="http://www.mozilla.org/js/spidermonkey/"
SRC_URI="http://dev.gentoo.org/~axs/distfiles/${MY_P}.tar.bz2"

LICENSE="NPL-1.1"
SLOT="24"
KEYWORDS="~alpha ~amd64 ~arm ~hppa -ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~x86-fbsd"
IUSE="debug jit minimal static-libs test"

REQUIRED_USE="debug? ( jit )"

S="${WORKDIR}/${MY_P}"
BUILDDIR="${S}/js/src"

RDEPEND=">=dev-libs/nspr-4.9.4
	virtual/libffi"
DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	app-arch/zip
	virtual/pkgconfig"

pkg_setup(){
	if [[ ${MERGE_TYPE} != "binary" ]]; then
		python-any-r1_pkg_setup
		export LC_ALL="C"
	fi
}

src_prepare() {
	epatch_user

	if [[ ${CHOST} == *-freebsd* ]]; then
		# Don't try to be smart, this does not work in cross-compile anyway
		ln -sfn "${BUILDDIR}/config/Linux_All.mk" "${S}/config/$(uname -s)$(uname -r).mk" || die
	fi
}

src_configure() {
	cd "${BUILDDIR}" || die

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" \
	AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)" \
	LD="$(tc-getLD)" \
	econf \
		${myopts} \
		--enable-jemalloc \
		--enable-readline \
		--enable-threadsafe \
		--with-system-nspr \
		--enable-system-ffi \
		--enable-jemalloc \
		--enable-system-icu \
		$(use_enable debug) \
		$(use_enable jit tracejit) \
		$(use_enable jit methodjit) \
		$(use_enable static-libs static) \
		$(use_enable test tests)
}

src_compile() {
	cd "${BUILDDIR}" || die
	if tc-is-cross-compiler; then
		make CFLAGS="" CXXFLAGS="" \
			CC=$(tc-getBUILD_CC) CXX=$(tc-getBUILD_CXX) \
			AR=$(tc-getBUILD_AR) RANLIB=$(tc-getBUILD_RANLIB) \
			jscpucfg host_jsoplengen host_jskwgen || die
		make CFLAGS="" CXXFLAGS="" \
			CC=$(tc-getBUILD_CC) CXX=$(tc-getBUILD_CXX) \
			AR=$(tc-getBUILD_AR) RANLIB=$(tc-getBUILD_RANLIB) \
			-C config nsinstall || die
		mv {,native-}jscpucfg || die
		mv {,native-}host_jskwgen || die
		mv {,native-}host_jsoplengen || die
		mv config/{,native-}nsinstall || die
		sed -e 's@./jscpucfg@./native-jscpucfg@' \
			-e 's@./host_jskwgen@./native-host_jskwgen@' \
			-e 's@./host_jsoplengen@./native-host_jsoplengen@' \
			-i Makefile || die
		sed -e 's@/nsinstall@/native-nsinstall@' -i config/config.mk || die
		rm -f config/host_nsinstall.o \
			config/host_pathsub.o \
			host_jskwgen.o \
			host_jsoplengen.o || die
	fi
	emake
}

src_test() {
	cd "${BUILDDIR}/jsapi-tests" || die
	emake check
}

src_install() {
	cd "${BUILDDIR}" || die
	emake DESTDIR="${D}" install

	if ! use minimal; then
		if use jit; then
			pax-mark m "${ED}/usr/bin/js${SLOT}"
		fi
	else
		rm -f "${ED}/usr/bin/js${SLOT}"
	fi

	if ! use static-libs; then
		# We can't actually disable building of static libraries
		# They're used by the tests and in a few other places
		find "${D}" -iname '*.a' -delete || die
	fi
}
