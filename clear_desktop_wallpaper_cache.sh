#!/bin/bash

# Alias programs for security
find='/usr/bin/find'
rm='/bin/rm'

# Remove cached lock screen
$rm -rf '/Library/Caches/Desktop Pictures'

# Remove cached desktop pictures
desktop_cache='/private/var/folders/*/*/C/com.apple.desktoppicture'
$rm -rf "$($find $desktop_cache -type d -maxdepth 0)"
