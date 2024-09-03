ad_page_contract {
    Sitewide Admin UI for Boomerang Plugin
}

set what "Boomerang Plugin"
set title "Sitewide Admin for $what"
set context [list $title]

set resource_prefix [acs_package_root_dir boomerang/www/resources]

set resource_info [::boomerang::resource_info]
set version [dict get $resource_info configuredVersion]
#
# Get version info about the resource files of this package. If not
# locally installed, offer a link for download.
#
set prefix [dict get $resource_info prefix]
set jsFile [lindex [dict get $resource_info jsFiles] 0]
set downloadURL [lindex [dict get $resource_info downloadURLs] 0]
set plainFile $resource_prefix/$jsFile
set gzip [::util::which gzip]

set writable [file writable $resource_prefix]
set jsFileExists [file readable $plainFile]

if {$writable} {
    ns_log notice "check for <$plainFile.gz>"
    if {[file exists $plainFile.gz]} {
        set compressedFile $plainFile.gz
    }
} else {
    set path $resource_prefix
}


# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
