

#
# We should get the URL from the parameter and register this for every
# toplevel subsite, on which boomerang is enabled
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
