#
# Initialize shared daily log descriptors before requests are registered.
# Preopening tomorrow's file keeps descriptor creation out of request threads.
# The async writer is drained before the at-exit callback closes the files.
#
nsv_array set boomerang:logfiles {}
::boomerang::prepare_logfiles
nsv_set boomerang logfileSchedule \
    [ns_schedule_daily 0 0 ::boomerang::prepare_logfiles]
ns_atexit {
    foreach {filename fd} [nsv_array get boomerang:logfiles] {
        catch {ns_asynclogfile close $fd}
    }
}

#
# We should get the URL from the parameter and register this for every
# top-level subsite, on which boomerang is enabled
#
foreach url {/} {

    set node_info [site_node::get_from_url -url $url]
    set subsite_id [dict get $node_info object_id]
    set enabled_p [parameter::get \
                       -package_id $subsite_id \
                       -parameter BoomerangEnabled \
                       -default 0]
    if {$enabled_p} {
        set beaconURL [parameter::get \
                           -package_id $subsite_id \
                           -parameter BoomerangBeaconUrl \
                           -default /boomerang_handler]
        #
        # Register the beaconURL only, when it is not a fully qualified URL
        #
        if {[regexp {^https?://} $beaconURL] == 0} {
            foreach httpMethod {GET POST} {
                ns_register_proc $httpMethod ${url}[string trimleft $beaconURL /] {
                    set t0 [clock clicks -microseconds]
                    boomerang::handler record -ns_set [ns_getform] -peeraddr [ad_conn peeraddr]
                    ns_log notice "boomerang beacon [expr {[clock clicks -microseconds] - $t0}] microseconds"
                    ns_return 204 text/plain ""
                }
            }
        }
    }
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
