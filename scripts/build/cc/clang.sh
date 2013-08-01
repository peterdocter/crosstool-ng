# This file adds the function to build the clang C compiler
# Copyright 2012 Yann Diorcet
# Licensed under the GPL v2. See COPYING in the root of this package

# Override variable depending on configuration
if [ "${CT_CC_CLANG_V_3_1}" = "y" ]; then
	CLANG_SUFFIX=".src"
else
	CLANG_SUFFIX=""
fi

CT_CLANG_FULLNAME="clang-${CT_CC_CLANG_VERSION}${CLANG_SUFFIX}"

# Download clang
do_clang_get() {
    CT_GetFile "${CT_CLANG_FULLNAME}" \
               http://llvm.org/releases/${CT_CC_CLANG_VERSION}
}

# Extract clang
do_clang_extract() {
    CT_Extract "${CT_CLANG_FULLNAME}"
    
    CT_Pushd "${CT_SRC_DIR}/${CT_CLANG_FULLNAME}"
    CT_Patch nochdir "clang" "${CT_CC_CLANG_VERSION}"
    CT_Popd
}

#------------------------------------------------------------------------------
# Core clang pass 1
do_clang_core_pass_1() {
    :
}

# Core clang pass 2
do_clang_core_pass_2() {
    :
}

#------------------------------------------------------------------------------
# Build core clang
do_clang_core_backend() {
    :
}

#------------------------------------------------------------------------------
# Build complete clang to run on build
do_clang_for_build() {
    local -a final_opts

    # In case we're canadian or cross-native, it seems that a
    # real, complete compiler is needed?!? WTF? Sigh...
    # Otherwise, there is nothing to do.
    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing final clang compiler for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-clang-final-build"
    
    final_opts+=( "host=${CT_BUILD}" )
    final_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    final_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    final_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )     

    do_clang_backend "${final_opts[@]}"

    CT_Popd
    CT_EndStep
}

#------------------------------------------------------------------------------
# Build final clang to run on host
do_clang_for_host() {
    local -a final_opts

    CT_DoStep INFO "Installing final clang compiler"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-clang-final"
    
    final_opts+=( "host=${CT_HOST}" )
    final_opts+=( "prefix=${CT_PREFIX_DIR}" )
    final_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    final_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )     

    do_clang_backend "${final_opts[@]}"

    CT_Popd
    CT_EndStep
}

#------------------------------------------------------------------------------
# Build the final clang
do_clang_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    cp -r "${CT_SRC_DIR}/${CT_LLVM_FULLNAME}/"* "."
    mkdir "tools/clang"
    cp -r "${CT_SRC_DIR}/${CT_CLANG_FULLNAME}/"* "tools/clang/"
    if [ "${CT_LLVM_COMPILER_RT}" = "y" ]; then
	mkdir "projects/compiler-rt"
	cp -r "${CT_SRC_DIR}/compiler-rt-${CT_LLVM_VERSION}.src/"* "projects/compiler-rt/"
    fi

    CT_DoLog EXTRA "Configuring clang"

    CT_DoExecLog CFG                  \
    CFLAGS="${cflags}"                \
    CXXFLAGS="${cflags}"              \
    LDFLAGS="${ldflags}"              \
    ./configure                       \
        --build=${CT_BUILD}           \
        --host=${host}                \
        --prefix="${prefix}"          \
        --target=${CT_TARGET}         \
        

    CT_DoLog EXTRA "Building clang"
    CT_DoExecLog ALL                  \
    make ${JOBSFLAGS}                 \
        CFLAGS="${cflags}"            \
        CXXFLAGS="${cflags}"          \
        LDFLAGS="${ldflags}"          \
        ONLY_TOOLS="clang"            \

    CT_Pushd "tools/clang/"

    CT_DoLog EXTRA "Installing clang"
    CT_DoExecLog ALL make install     \
        ONLY_TOOLS="clang"            \
        
    CT_Popd
        
    # Create default clang clang++
    for cc in clang clang++; do
        gcc=${cc/clang/gcc}
        gcc=${gcc/gcc++/g++}
	cat > ${prefix}/bin/${CT_TARGET}-${cc} << EOF
#!/bin/sh
\`dirname \$0\`/${cc} \
-ccc-gcc-name ${CT_TARGET}-${gcc} \
-ccc-host-triple ${CT_TARGET} \
\$*
EOF
	chmod +x ${prefix}/bin/${CT_TARGET}-${cc}
    done
    
}