# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="5"
WANT_AUTOCONF="2.1"
PYTHON_COMPAT=( python2_{6,7} )
PYTHON_REQ_USE="threads"
inherit autotools eutils toolchain-funcs multilib python-any-r1 versionator pax-utils

MY_PN="mozjs"
MY_PV="${PV/_alpha/a}"
MY_PV="${PV/_beta/b}"
MY_P="${MY_PN}-${MY_PV/_/.}"
DESCRIPTION="Stand-alone JavaScript C library"
HOMEPAGE="http://www.mozilla.org/js/spidermonkey/"
#SRC_URI="https://ftp.mozilla.org/pub/mozilla.org/js/${MY_P}.tar.bz2"
SRC_URI="http://people.mozilla.org/~sstangl/${MY_P}.tar.bz2"

LICENSE="NPL-1.1"
SLOT="31"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~x86-fbsd"
IUSE="debug +jit icu minimal static-libs +system-icu test"

RESTRICT="ia64? ( test )"
REQUIRED_USE="debug? ( jit )"

S="${WORKDIR}/${MY_P%.rc*}"
BUILDDIR="${WORKDIR}/jsbuild"

RDEPEND=">=dev-libs/nspr-4.9.4
	virtual/libffi
	>=sys-libs/zlib-1.1.4
	system-icu? ( >=dev-libs/icu-1.51:= )"
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

src_configure() {
	mkdir "${BUILDDIR}" && cd "${BUILDDIR}" || die

        local myopts=""
        if use icu; then # make sure system-icu flag only affects icu-enabled build
                myopts+="$(use_with system-icu)"
        else
                myopts+="--without-system-icu"
        fi

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" \
	AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)" \
	LD="$(tc-getLD)" \
	ECONF_SOURCE="${S}/js/src" \
	econf ${myopts} \
		--disable-trace-malloc \
		--enable-jemalloc \
		--enable-readline \
		--enable-threadsafe \
		--with-system-nspr \
		--enable-system-ffi \
		--disable-optimize \
		$(use_with icu intl-api) \
		$(use_enable debug) \
		$(use_enable jit ion) \
		$(use_enable jit yarr-jit) \
		$(use_enable static-libs static) \
		$(use_enable test tests)
}

src_compile() {
	cd "${BUILDDIR}" || die
	if tc-is-cross-compiler; then
		make CFLAGS="" CXXFLAGS="" \
			CC=$(tc-getBUILD_CC) CXX=$(tc-getBUILD_CXX) \
			AR=$(tc-getBUILD_AR) RANLIB=$(tc-getBUILD_RANLIB) \
			MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" \
			HOST_OPTIMIZE_FLAGS="" MODULE_OPTIMIZE_FLAGS="" \
			MOZ_PGO_OPTIMIZE_FLAGS="" \
			jscpucfg host_jsoplengen host_jskwgen || die
		make CFLAGS="" CXXFLAGS="" \
			CC=$(tc-getBUILD_CC) CXX=$(tc-getBUILD_CXX) \
			AR=$(tc-getBUILD_AR) RANLIB=$(tc-getBUILD_RANLIB) \
			MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" HOST_OPTIMIZE_FLAGS="" \
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
	emake \
		MOZ_OPTIMIZE_FLAGS="" MOZ_DEBUG_FLAGS="" \
		HOST_OPTIMIZE_FLAGS="" MODULE_OPTIMIZE_FLAGS="" \
		MOZ_PGO_OPTIMIZE_FLAGS=""
}

src_test() {
	cd "${BUILDDIR}/js/src/jsapi-tests" || die
	emake check
	cd "${BUILDDIR}" || die
	emake check-jit-test
}

src_install() {
	cd "${BUILDDIR}" || die
	emake DESTDIR="${D}" install
	mv "${ED}"/usr/bin/js "${ED}"/usr/bin/js${SLOT}
	mv "${ED}"/usr/bin/js-config "${ED}"/usr/bin/js${SLOT}-config

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
