# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: dotnet-pkg-utils.eclass
# @MAINTAINER:
# Gentoo Dotnet project <dotnet@gentoo.org>
# @AUTHOR:
# Anna Figueiredo Gomes <navi@vlhl.dev>
# Maciej Barć <xgqt@gentoo.org>
# @SUPPORTED_EAPIS: 8
# @PROVIDES: nuget
# @BLURB: common functions and variables for builds using .NET SDK
# @DESCRIPTION:
# This eclass is designed to provide common definitions for .NET packages.
#
# This eclass does not export any phase functions, for that see
# the "dotnet-pkg" eclass.

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_DOTNET_PKG_UTILS_ECLASS} ]] ; then
_DOTNET_PKG_UTILS_ECLASS=1

inherit edo multiprocessing nuget

# @ECLASS_VARIABLE: DOTNET_COMPAT
# @REQUIRED
# @PRE_INHERIT
# @DESCRIPTION:
# Allows to choose a slot for dotnet.
#
# Most .NET packages will lock onto one supported .NET major version.
# DOTNET_COMPAT should specify which version was chosen by package upstream.
# In case multiple .NET versions are specified in the project, then the highest
# should be picked by the maintainer.
if [[ ${CATEGORY}/${PN} != dev-dotnet/dotnet-runtime-nugets ]] ; then
	if [[ ! ${DOTNET_COMPAT} ]] ; then
		die "${ECLASS}: DOTNET_COMPAT not set"
	fi

	RDEPEND+=" virtual/dotnet-sdk:${DOTNET_COMPAT} "
	BDEPEND+=" ${RDEPEND} "

	if [[ ${CATEGORY}/${PN} != dev-dotnet/csharp-gentoodotnetinfo ]] ; then
		BDEPEND+=" dev-dotnet/csharp-gentoodotnetinfo "
	fi

	IUSE+=" debug "
fi

# Needed otherwise the binaries may break.
RESTRICT+=" strip "

# Everything is built by "dotnet".
QA_PREBUILT=".*"

# Special .NET SDK environment variables.
# Setting them either prevents annoying information from being generated
# or stops services that may interfere with a clean package build.
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export MSBUILDDISABLENODEREUSE=1
export POWERSHELL_TELEMETRY_OPTOUT=1
export POWERSHELL_UPDATECHECK=0
# Overwrite selected MSBuild properties ("-p:XYZ").
export UseSharedCompilation=false

# @ECLASS_VARIABLE: DOTNET_RUNTIME
# @DEFAULT_UNSET
# @DESCRIPTION:
# Sets the runtime used to build a package.
#
# This variable is set automatically by the "dotnet-pkg-utils_setup" function.

# @ECLASS_VARIABLE: DOTNET_EXECUTABLE
# @DEFAULT_UNSET
# @DESCRIPTION:
# Sets path of a "dotnet" executable.
#
# This variable is set automatically by the "dotnet-pkg-utils_setup" function.

# @ECLASS_VARIABLE: DOTNET_CONFIGURATION
# @DEFAULT_UNSET
# @DESCRIPTION:
# Configuration value passed to "dotnet" in the compile phase.
# Is either Debug or Release, depending on the "debug" USE flag.
#
# This variable is set automatically by the "dotnet-pkg-utils_setup" function.

# @ECLASS_VARIABLE: DOTNET_OUTPUT
# @DEFAULT_UNSET
# @DESCRIPTION:
# Path of the output directory, where the package artifacts are placed during
# the building of packages with "dotnet-pkg-utils_build" function.
#
# This variable is set automatically by the "dotnet-pkg-utils_setup" function.

# @VARIABLE: DOTNET_LAUNCHERDEST
# @INTERNAL
# @DESCRIPTION:
# Sets the path that .NET launchers are installed into by
# the "dotnet-pkg-utils_dolauncher" function.
#
# The function "dotnet-pkg-utils_launcherinto" is able to manipulate this
# variable.
#
# Defaults to "/usr/bin".
DOTNET_LAUNCHERDEST=/usr/bin

# @VARIABLE: DOTNET_LAUNCHERVARS
# @INTERNAL
# @DESCRIPTION:
# Sets additional variables for .NET launchers created by
# the "dotnet-pkg-utils_dolauncher" function.
#
# The function "dotnet-pkg-utils_append_launchervar" is able to manipulate this
# variable.
#
# Defaults to a empty array.
DOTNET_LAUNCHERVARS=()

# @FUNCTION: dotnet-pkg-utils_get-configuration
# @DESCRIPTION:
# Return .NET configuration type of the current package.
#
# It is advised to refer to the "DOTNET_CONFIGURATION" variable instead of
# calling this function if necessary.
#
# Used by "dotnet-pkg-utils_setup".
dotnet-pkg-utils_get-configuration() {
	if in_iuse debug && use debug ; then
		echo Debug
	else
		echo Release
	fi
}

# @FUNCTION: dotnet-pkg-utils_get-output
# @USAGE: <name>
# @DESCRIPTION:
# Return a specially constructed name of a directory for output of
# "dotnet build" artifacts ("--output" flag, see "dotnet-pkg-utils_build").
#
# It is very rare that a maintainer would use this function in an ebuild.
#
# This function is used inside "dotnet-pkg-utils_setup".
dotnet-pkg-utils_get-output() {
	debug-print-function ${FUNCNAME} "${@}"

	[[ ! ${DOTNET_CONFIGURATION} ]] &&
		die "${FUNCNAME}: DOTNET_CONFIGURATION is not set."

	echo "${WORKDIR}"/${1}_net${DOTNET_COMPAT}_${DOTNET_CONFIGURATION}
}

# @FUNCTION: dotnet-pkg-utils_get-runtime
# @DESCRIPTION:
# Return the .NET runtime used for the current package.
#
# Used by "dotnet-pkg-utils_setup".
dotnet-pkg-utils_get-runtime() {
	local libc="$(usex elibc_musl "-musl" "")"

	if use amd64 ; then
		echo linux${libc}-x64
	elif use x86 ; then
		echo linux${libc}-x86
	elif use arm ; then
		echo linux${libc}-arm
	elif use arm64 ; then
		echo linux${libc}-arm64
	else
		die "${FUNCNAME}: Unsupported architecture: ${ARCH}"
	fi
}

# @FUNCTION: dotnet-pkg-utils_setup
# @DESCRIPTION:
# Sets up "DOTNET_EXECUTABLE" variable for later use in "edotnet".
# Also sets up "DOTNET_CONFIGURATION" and "DOTNET_OUTPUT"
# for "dotnet-pkg_src_configure" and "dotnet-pkg_src_compile".
#
# This functions should be called by "pkg_setup".
#
# Used by "dotnet-pkg_pkg_setup" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_setup() {
	local dotnet_compat_impl
	local dotnet_compat_impl_path
	for dotnet_compat_impl in dotnet{,-bin}-${DOTNET_COMPAT} ; do
		dotnet_compat_impl_path="$(type -P type ${dotnet_compat_impl})"

		if [[ "${dotnet_compat_impl_path}" ]] ; then
			DOTNET_EXECUTABLE=${dotnet_compat_impl}
			DOTNET_EXECUTABLE_PATH="${dotnet_compat_impl_path}"

			break
		fi
	done

	# Link "DOTNET_EXECUTABLE" to "dotnet" only for the package build.
	local dotnet_spoof_path="${T}"/dotnet_spoof/${DOTNET_COMPAT}
	mkdir -p "${dotnet_spoof_path}" || die
	ln -s "${DOTNET_EXECUTABLE_PATH}" "${dotnet_spoof_path}"/dotnet || die
	export PATH="${dotnet_spoof_path}:${PATH}"

	einfo "Using dotnet SDK \"${DOTNET_EXECUTABLE}\" from \"${DOTNET_EXECUTABLE_PATH}\"."

	# The picked "DOTNET_EXECUTABLE" should set "DOTNET_ROOT" internally
	# and not rely upon this environment variable.
	unset DOTNET_ROOT

	# Unset .NET and NuGet directories.
	unset DOTNET_DATA
	unset NUGET_DATA

	DOTNET_RUNTIME=$(dotnet-pkg-utils_get-runtime)
	DOTNET_CONFIGURATION=$(dotnet-pkg-utils_get-configuration)
	DOTNET_OUTPUT="$(dotnet-pkg-utils_get-output ${P})"
}

# @FUNCTION: dotnet-pkg-utils_remove-global-json
# @USAGE: [directory]
# @DESCRIPTION:
# Remove the "global.json" if it exists.
# The file in question might lock target package to a specified .NET
# version, which might be unnecessary (as it is in most cases).
#
# Optional "directory" argument defaults to the current directory path.
#
# Used by "dotnet-pkg_src_prepare" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_remove-global-json() {
	debug-print-function ${FUNCNAME} "${@}"

	local file="${1:-.}"/global.json

	if [[ -f "${file}" ]] ; then
		ebegin "Removing the global.json file"
		rm "${file}"
		eend ${?} || die "${FUNCNAME}: failed to remove ${file}"
	fi
}

# @FUNCTION: edotnet
# @USAGE: <command> [args...]
# @DESCRIPTION:
# Call dotnet, passing the supplied arguments.
edotnet() {
	debug-print-function ${FUNCNAME} "${@}"

	if [[ ! "${DOTNET_EXECUTABLE}" ]] ; then
	   die "${FUNCNAME}: DOTNET_EXECUTABLE not set. Was dotnet-pkg-utils_setup called?"
	fi

	edo "${DOTNET_EXECUTABLE}" "${@}"
}

# @FUNCTION: dotnet-pkg-utils_info
# @DESCRIPTION:
# Show information about current .NET SDK that is being used.
#
# Depends upon the "gentoo-dotnet-info" program installed by
# the "dev-dotnet/csharp-gentoodotnetinfo" package.
#
# Used by "dotnet-pkg_src_configure" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_info() {
	if [[ ${CATEGORY}/${PN} == dev-dotnet/csharp-gentoodotnetinfo ]] ; then
		debug-print-function "${FUNCNAME}: ${P} is a special package, skipping dotnet-pkg-utils_info"
	elif ! command -v gentoo-dotnet-info >/dev/null ; then
		ewarn "${FUNCNAME}: gentoo-dotnet-info not available"
	else
		gentoo-dotnet-info || die "${FUNCNAME}: failed to execute gentoo-dotnet-info"
	fi
}

# @FUNCTION: dotnet-pkg-utils_foreach-solution
# @USAGE: <function> [directory]
# @DESCRIPTION:
# Execute a function for each solution file (.sln) in a specified directory.
# This function may yield no real results because solutions are discovered
# automatically.
#
# Optional "directory" argument defaults to the current directory path.
#
# Used by "dotnet-pkg_src_configure" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_foreach-solution() {
	debug-print-function ${FUNCNAME} "${@}"

	local dotnet_solution
	local dotnet_solution_name
	while read dotnet_solution ; do
		dotnet_solution_name="$(basename "${dotnet_solution}")"

		ebegin "Running \"${1}\" for solution: \"${dotnet_solution_name}\""
		"${1}" "${dotnet_solution}"
		eend $? "${FUNCNAME}: failed for solution: \"${dotnet_solution}\"" || die
	done < <(find "${2:-.}" -maxdepth 1 -type f -name "*.sln")
}

# @FUNCTION: dotnet-pkg-utils_restore
# @USAGE: [directory] [args] ...
# @DESCRIPTION:
# Restore the package using "dotnet restore" in a specified directory.
#
# Optional "directory" argument defaults to the current directory path.
#
# Additionally any number of "args" maybe be given, they are appended to
# the "dotnet" command invocation.
#
# Used by "dotnet-pkg_src_configure" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_restore() {
	debug-print-function ${FUNCNAME} "${@}"

	local directory
	if [[ "${1}" ]] ; then
		directory="${1}"
		shift
	else
		directory="$(pwd)"
	fi

	local -a restore_args=(
		--runtime ${DOTNET_RUNTIME}
		--source "${NUGET_PACKAGES}"
		-maxCpuCount:$(makeopts_jobs)
		"${@}"
	)

	edotnet restore "${restore_args[@]}" "${directory}"
}

# @FUNCTION: dotnet-pkg-utils_restore_tools
# @USAGE: [config-file] [args] ...
# @DESCRIPTION:
# Restore dotnet tools for a project in the current directory.
#
# Optional "config-file" argument is used to specify a file for the
# "--configfile" option which records what tools should be restored.
#
# Additionally any number of "args" maybe be given, they are appended to
# the "dotnet" command invocation.
dotnet-pkg-utils_restore_tools() {
	debug-print-function ${FUNCNAME} "${@}"

	local -a tool_restore_args=(
		--add-source "${NUGET_PACKAGES}"
	)

	if [[ "${1}" ]] ; then
		tool_restore_args+=( --configfile "${1}" )
		shift
	fi

	tool_restore_args+=( "${@}" )

	edotnet tool restore "${tool_restore_args[@]}"
}

# @FUNCTION: dotnet-pkg-utils_build
# @USAGE: [directory] [args] ...
# @DESCRIPTION:
# Build the package using "dotnet build" in a specified directory.
#
# Optional "directory" argument defaults to the current directory path.
#
# Additionally any number of "args" maybe be given, they are appended to
# the "dotnet" command invocation.
#
# Used by "dotnet-pkg_src_compile" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_build() {
	debug-print-function ${FUNCNAME} "${@}"

	local directory
	if [[ "${1}" ]] ; then
		directory="${1}"
		shift
	else
		directory="$(pwd)"
	fi

	local -a build_args=(
		--configuration "${DOTNET_CONFIGURATION}"
		--no-restore
		--no-self-contained
		--output "${DOTNET_OUTPUT}"
		--runtime ${DOTNET_RUNTIME}
		-maxCpuCount:$(makeopts_jobs)
		"${@}"
	)

	if ! use debug ; then
		build_args+=(
			-p:StripSymbols=true
			-p:NativeDebugSymbols=false
		)
	fi

	edotnet build "${build_args[@]}" "${directory}"
}

# @FUNCTION: dotnet-pkg-utils_test
# @USAGE: [directory] [args] ...
# @DESCRIPTION:
# Test the package using "dotnet test" in a specified directory.
#
# Optional "directory" argument defaults to the current directory path.
#
# Additionally any number of "args" maybe be given, they are appended to
# the "dotnet" command invocation.
#
# Used by "dotnet-pkg_src_test" from the "dotnet-pkg" eclass.
dotnet-pkg-utils_test() {
	debug-print-function ${FUNCNAME} "${@}"

	local directory
	if [[ "${1}" ]] ; then
		directory="${1}"
		shift
	else
		directory="$(pwd)"
	fi

	local -a test_args=(
		--configuration "${DOTNET_CONFIGURATION}"
		--no-restore
		-maxCpuCount:$(makeopts_jobs)
		"${@}"
	)

	edotnet test "${test_args[@]}" "${directory}"
}

# @FUNCTION: dotnet-pkg-utils_install
# @USAGE: [directory]
# @DESCRIPTION:
# Install the contents of "DOTNET_OUTPUT" into a directory, defaults to
# "/usr/share/${P}".
#
# Installation directory is relative to "ED".
dotnet-pkg-utils_install() {
	debug-print-function ${FUNCNAME} "${@}"

	local installation_directory="${1:-/usr/share/${P}}"

	dodir "${installation_directory}"
	cp -r "${DOTNET_OUTPUT}"/* "${ED}/${installation_directory}/" || die
}

# @FUNCTION: dotnet-pkg-utils_launcherinto
# @USAGE: <directory>
# @DESCRIPTION:
# Changes the path .NET launchers are installed into via subsequent
# "dotnet-pkg-utils_dolauncher" calls.
#
# For more info see the "DOTNET_LAUNCHERDEST" variable.
dotnet-pkg-utils_launcherinto() {
	debug-print-function ${FUNCNAME} "${@}"

	[[ ! "${1}" ]] && die "${FUNCNAME}: no directory specified"

	DOTNET_LAUNCHERDEST="${1}"
}

# @FUNCTION: dotnet-pkg-utils_append_launchervar
# @USAGE: <variable-setting>
# @DESCRIPTION:
# Appends a given variable setting to the "DOTNET_LAUNCHERVARS".
#
# WARNING: This functions modifies a global variable permanently!
# This means that all launchers created in subsequent
# "dotnet-pkg-utils_dolauncher" calls of a given package will have
# the given variable set.
#
# Example:
# @CODE
# dotnet-pkg-utils_append_launchervar "DOTNET_EnableAlternateStackCheck=1"
# @CODE
#
# For more info see the "DOTNET_LAUNCHERVARS" variable.
dotnet-pkg-utils_append_launchervar() {
	debug-print-function ${FUNCNAME} "${@}"

	[[ ! "${1}" ]] && die "${FUNCNAME}: no variable setting specified"

	DOTNET_LAUNCHERVARS+=( "${1}" )
}

# @FUNCTION: dotnet-pkg-utils_dolauncher
# @USAGE: <executable-path> [filename]
# @DESCRIPTION:
# Make a wrapper script to launch an executable built from a .NET package.
#
# If no file name is given, the `basename` of the executable is used.
#
# Parameters:
# ${1} - path of the executable to launch,
# ${2} - filename of launcher to create (optional).
#
# Example:
# @CODE
# dotnet-pkg-utils_install
# dotnet-pkg-utils_dolauncher /usr/share/${P}/${PN^}
# @CODE
#
# The path is prepended by "EPREFIX".
dotnet-pkg-utils_dolauncher() {
	debug-print-function ${FUNCNAME} "${@}"

	local executable_path executable_name

	if [[ "${1}" ]] ; then
		local executable_path="${1}"
		shift
	else
		die "${FUNCNAME}: No executable path given."
	fi

	if [[ ${#} = 0 ]] ; then
		executable_name="$(basename "${executable_path}")"
	else
		executable_name="${1}"
		shift
	fi

	local executable_target="${T}/${executable_name}"

	cat <<-EOF > "${executable_target}" || die
	#!/bin/sh

	# Lanucher script for ${executable_path} (${executable_name}),
	# created from package "${CATEGORY}/${P}",
	# compatible with dotnet version ${DOTNET_COMPAT}.

	for __dotnet_root in \\
		${EPREFIX}/usr/$(get_libdir)/dotnet-sdk-${DOTNET_COMPAT} \\
		${EPREFIX}/opt/dotnet-sdk-bin-${DOTNET_COMPAT} ; do
		[ -d \${__dotnet_root} ] && break
	done

	DOTNET_ROOT="\${__dotnet_root}"
	export DOTNET_ROOT

	$(for var in "${DOTNET_LAUNCHERVARS[@]}" ; do
		echo "${var}"
		echo "export ${var%%=*}"
	done)

	exec "${EPREFIX}${executable_path}" "\${@}"
	EOF

	dodir "${DOTNET_LAUNCHERDEST}"
	exeinto "${DOTNET_LAUNCHERDEST}"
	doexe "${executable_target}"
}

# @FUNCTION: dotnet-pkg-utils_dolauncher_portable
# @USAGE: <dll-path> <filename>
# @DESCRIPTION:
# Make a wrapper script to launch a .NET DLL file built from a .NET package.
#
# Parameters:
# ${1} - path of the DLL to launch,
# ${2} - filename of launcher to create.
#
# Example:
# @CODE
# dotnet-pkg-utils_dolauncher_portable \
#     /usr/share/${P}/GentooDotnetInfo.dll gentoo-dotnet-info
# @CODE
#
# The path is prepended by "EPREFIX".
dotnet-pkg-utils_dolauncher_portable() {
	debug-print-function ${FUNCNAME} "${@}"

	local dll_path="${1}"
	local executable_name="${2}"
	local executable_target="${T}/${executable_name}"

	cat <<-EOF > "${executable_target}" || die
	#!/bin/sh

	# Lanucher script for ${dll_path} (${executable_name}),
	# created from package "${CATEGORY}/${P}",
	# compatible with any dotnet version, built on ${DOTNET_COMPAT}.

	$(for var in "${DOTNET_LAUNCHERVARS[@]}" ; do
		echo "${var}"
		echo "export ${var%%=*}"
	done)

	exec dotnet exec "${EPREFIX}${dll_path}" "\${@}"
	EOF

	dodir "${DOTNET_LAUNCHERDEST}"
	exeinto "${DOTNET_LAUNCHERDEST}"
	doexe "${executable_target}"
}

fi
