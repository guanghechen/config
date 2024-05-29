#! /usr/bin/env bash

function _ghc_watch_fake_clipboard {
	local _fake_clipboard_file=$1
	local _fake_clipboard_dir=$(dirname "$_fake_clipboard_file")

	# Check if the directory exists
	if [ ! -d "$_fake_clipboard_dir" ]; then
		mkdir -p "$_fake_clipboard_dir"
	fi

	if [ ! -f "$_fake_clipboard_file" ]; then
		touch "$_fake_clipboard_file"
		chmod 666 "$_fake_clipboard_file"
	fi

	echo "Watching fake clipboard: $_fake_clipboard_file"

	# Watch the fake clipboard change and write the content into system clipboard
	fswatch -0 $_fake_clipboard_file | xargs -0 -n1 sh -c "cat $_fake_clipboard_file | pbcopy"
}

_ghc_watch_fake_clipboard "$1"
