set what "Boomerang Plugin"
set title "Sitewide Admin for $what"
set context [list $title]

set resource_prefix [acs_package_root_dir boomerang/www/resources]
set version $::boomerang::version

#
# Get version info about the resource files of this package. If not
# locally installed, offer a link for download.
#
set version_info [::boomerang::version_info]
set prefix [dict get $version_info prefix]
set jsFile [lindex [dict get $version_info jsFiles] 0]
set plainFile $resource_prefix/$jsFile
set gzip [::util::which gzip]

set writable [file writable $resource_prefix]

if {$writable} {
    ns_log notice "check for <$plainFile.gz>"
    if {[file exists $plainFile.gz]} {
	set compressedFile $plainFile.gz
    }
} else {
    set path $resource_prefix
}

