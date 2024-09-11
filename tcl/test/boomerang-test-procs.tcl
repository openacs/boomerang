ad_library {

    Automated tests.

}

aa_register_case -cats {
    smoke production_safe
} -procs {
    util::which
} boomerang_exec_dependencies {
    Test external command dependencies for this package.
} {
    foreach cmd [list \
                     [::util::which gzip] \
                    ] {
        aa_true "'$cmd' is executable" [file executable $cmd]
    }
}
