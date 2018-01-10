ad_page_contract {
    @author Gustaf Neumann

    @creation-date Jan 10, 2018
} {
    {version:word,notnull ""}
}

set resource_prefix [acs_package_root_dir boomerang/www/resources]
set version_info [::boomerang::version_info]
set jsFile [lindex [dict get $version_info jsFiles] 0]
set plainFile $resource_prefix/$jsFile
set gzip [::util::which gzip]

if {$gzip ne ""} {
    ns_log notice "WANT TO COMPRESS <$resource_prefix> <$plainFile>"
    exec $gzip -9 -k $plainFile
}
ad_returnredirect .
ad_script_abort
