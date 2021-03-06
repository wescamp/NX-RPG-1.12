#!/usr/bin/env zsh
emulate zsh

default_wesnoth_tools_dir=~/src/wesnoth-old/data/tools

if [[ -z $1 || -z $2 || ( $2 != 1.<->.x && $2 != trunk && $2 != <-> ) ]]; then
	echo "usage: release.zsh <add-on> <server> [wesnoth_addon_manager-dir]

Uploads the add-on (specified as the path to the add-on’s directory, which
must contain its ‘_server.pbl’ file) to the specified add-ons server.

The directory containing the ‘wesnoth_addon_manager’ script may optionally be
specified. If it is not specified, this script will look for
‘wesnoth_addon_manager’ in PATH. If ‘wesnoth_addon_manager’ is not found by
either method, this script will look for it in:
   $default_wesnoth_tools_dir
This fallback location can be changed by editing line 3 of this script:
   $0

The add-ons server to release to must be specified as:
 * the version of Wesnoth that the server is intended for, in the form 1.N.x,
   where N is a number and x is a literal letter ‘x’; or
 * the word ‘trunk’, denoting the “trunk” version of Wesnoth; or
 * a port number."
	exit 2
fi

if [[ ! -e $1 ]]; then
	echo "‘$1’ does not exist.\nRelease aborted."
	exit 2
fi
if [[ ! -d $1 ]]; then
	echo "‘$1’ is not a directory.\nRelease aborted."
	exit 2
fi
typeset pbl="$1/_server.pbl"
if [[ ! -e $pbl ]]; then
	echo "‘$pbl’ does not exist.\nRelease aborted."
	exit 2
fi
if [[ ! -f $pbl ]]; then
	echo "‘$pbl’ is not a regular file.\nRelease aborted."
	exit 2
fi

typeset addon=${1##*/}
if [[ -z $addon ]]; then
	echo "The add-on’s path ($1) may not have a slash at the end.\nRelease aborted."
	exit 2
fi

if [[ -z $3 ]]; then
	3=${$(which wesnoth_addon_manager)%/*}
	if [[ $? != 0 ]]; then
		3=$default_wesnoth_tools_dir
	fi
fi
if [[ ! -e $3 ]]; then
	echo "wesnoth_addon_manager directory ‘$3’ does not exist.\nRelease aborted."
	exit 2
fi
if [[ ! -d $3 ]]; then
	echo "wesnoth_addon_manager directory ‘$3’ is not a directory.\nRelease aborted."
	exit 2
fi
if [[ ! -e ${3::=$3/wesnoth_addon_manager} ]]; then
	echo "‘$3’ does not exist.\nRelease aborted."
	exit 2
fi
if [[ ! -x ${3} ]]; then
	echo "‘$3’ is not executable.\nRelease aborted."
	exit 2
fi

## Force use of Python version 2 for running wesnoth_addon_manager.
typeset -a wam
if which python2.7 > /dev/null; then
	wam=(python2.7 $3)
elif which python2.6 > /dev/null; then
	wam=(python2.6 $3)
else
	echo 'Neither a `python2.7` command nor a `python2.6` command appears to be available.\nRelease aborted.'
	exit 2
fi

typeset addons="$($wam -V -p $2 -l)"
if [[ -z $addons ]]; then
	echo "Failed to retrieve add-on list from $2 add-ons server.\nRelease aborted."
	exit 7
fi

typeset oldver="$(grep -F "$addon" <(<<<$addons))"
if [[ -n $oldver ]]; then
	oldver="$(awk '{print $7}' <(<<<$oldver))"
	if [[ $oldver != <->.<->.<-> ]]; then
		echo "Failed to retrieve version of existing $addon release from $2 add-ons server (retrieved ‘$oldver’).\nRelease aborted."
		exit 3
	fi
fi

typeset newver="$(grep -F 'version=' "$pbl" | sed -E 's/version="(.*)"/\1/')"
if [[ $newver != <->.<->.<-> ]]; then
	echo "Failed to retrieve version of $addon to be released from ‘$pbl’ (retrieved ‘$newver’).\nRelease aborted."
	exit 4
fi

if [[ -n $oldver && $oldver = $newver ]]; then
	echo "Version of $addon to be released equals version of $addon on $2 add-ons server (version ‘$oldver’).\nRelease aborted."
	exit 5
fi

echo ----------------------------------------
echo "Version of $addon currently on $2 add-ons server: ${${oldver:+‘$oldver’}:-(none)}"
echo "Version of $addon to be released: ‘$newver’"
echo -n 'Confirm release? [Y/n] '

typeset x
read x
if [[ $x = Y ]]; then
	$wam -V -p $2 -u $1
	x=$?
	if [[ -f packet.dump ]]; then
		echo 'Note: wesnoth_addon_manager may have created a ‘packet.dump’ file, which you may want to delete.'
	fi
	echo ----------------------------------------
	if [[ $x = 0 ]]; then
		echo 'Release successful.'
		exit 0
	else
		echo 'Release failed.'
		exit 1
	fi
elif [[ $x = n ]]; then
	echo 'Release cancelled.'
	exit 6
else
	echo "Expected ‘Y’ or ‘n’, got ‘$x’.\nRelease aborted."
	exit 2
fi
