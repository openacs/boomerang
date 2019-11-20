ad_library {

    Integration of the Boomerang Library into OpenACS

    The Boomerang Library is an open sourced library (BSD licence)
    for Real User Measurement (RUM) and measures the performance
    experience of real users by collecting quality indicators from the
    clients. e.g. based on the W3C Navigation Timing model

    Details:
    https://soasta.github.io/boomerang/doc/
    https://www.w3.org/TR/navigation-timing/#processing-model

    This package integrates boomerang as a Plugin in OpenACS.

    @author Gustaf Neumann
    @creation-date 2 Jan 2018
    @cvs-id $Id$
}

namespace eval ::boomerang {

    set package_id [apm_package_id_from_key "boomerang"]

    #
    # It is possible to configure the version of the boomerang
    # plugin also via NaviServer config file:
    #
    #   ns_section ns/server/${server}/acs/boomerang
    #      ns_param version 1.0.0
    #

    set version [parameter::get \
                     -package_id $package_id \
                     -parameter Version \
                     -default 1.0.0]

    #
    # Boomerang response handler
    #
    nx::Object create handler {

        #
        # Don't quote the following boomerang attributes when output
        # format is JSON.
        #
        foreach v {
            t_done

            rt.cstart xrt.tstart rt.bstart rt.end

            nt_con_end nt_con_st nt_dns_end nt_dns_st nt_domcomp
            nt_domcontloaded_end nt_domcontloaded_st nt_domint
            nt_domloading nt_fet_st nt_first_paint nt_load_end
            nt_load_st nt_nav_st nt_red_cnt nt_red_end nt_red_st nt_req_st
            nt_res_end nt_res_st nt_spdy nt_ssl_st nt_unload_end
            nt_unload_st

            nt_start_time nt_tcp_time nt_request_time nt_response_time
            nt_processing_time nt_total_time

            dom.res dom.doms dom.ln dom.sz dom.img dom.script dom.script.ext dom.iframe dom.link

            mem.total mem.limit mem.used

            bat.lvl
            cpu.cnc
            mob.rtt
            scr.dpx

        } {set :json_unquoted($v) 1}

        foreach v {
            restiming
        } {
            set :json_drop($v) 1
        }

        foreach {orig new} {
            dom.script.ext  dom.script_ext
            dom.img.uniq    dom.img_uniq
            dom.script.uniq dom.script_uniq
        } {
            set :json_map($orig) $new
        }

        :object method ms_to_utc {ms} {
            set seconds [expr {$ms / 1000}]
            set fraction [format %03d [expr {$ms - ($seconds * 1000)}]]
            return [clock format $seconds -format "%Y-%m-%dT%H:%M:%S" -gmt 1].${fraction}Z
        }

        :object method log_to_file {-content -filename} {
            set logdir [file dirname [file rootname [ns_config ns/parameters ServerLog]]]
            set F [open $logdir/$filename a]
            try {
                puts $F $content
            } finally {
                close $F
            }
        }

        :object method as_json {dict} {
            package require json::write
            #::json::write object {*}
            set result ""
            dict map {k v} $dict {
                #
                # Some fields (like e.g.restiming) can't be used
                # easily for elastic search, since it contains names
                # with dots, and keys starting with dots, which are
                # interpreted differently in elasticsearch
                #
                if {[info exists :json_drop($k)]} {
                    continue
                }
                #
                # We have to map some key containing dots.
                #
                if {[info exists :json_map($k)]} {
                    set k [set :json_map($k)]
                }
                set entry "\"$k\":"
                #
                # Some fields have to be quoted
                #
                if {[info exists :json_unquoted($k)]} {
                    append entry $v
                } else {
                    append entry [::json::write string $v]
                }
                lappend result $entry
            }
            return "{[join $result ,]}"
        }

        :public object method record {-ns_set:required -peeraddr:required} {
            set t0 [clock clicks -microseconds]
            #xotcl::Object log "boomerang::record start"

            set entries [ns_set array $ns_set]

            if {[ns_set size $ns_set] < 1 || ![dict exists $entries u]} {
                ns_log notice "boomerang: no (valid) measurement variablables are provided"
                return
            }

            #
            # We have a non-empty ns_set, that will not cause an
            # exception below. Add always the peer address to the
            # result dict.
            #
            dict set entries clientip $peeraddr

            if {[dict exists $entries err]} {
                ad_log warning "boomerang: returned error: [dict get $entries err]\n\
                       Request-info:\n[util::request_info -with_headers]"
                set record 0
            } elseif {![dict exists $entries rt.tstart]} {
                ns_log notice "boomerang: no rt.tstart value in $entries"
                set record 0
            } else {
                dict set entries @timestamp [:ms_to_utc [dict get $entries rt.tstart]]
                #
                # Do we have W3C "Navigation Timing" information?
                # Just record data containing this information.
                #
                # Other entries have often strange t_done values: e.g. a
                # reload of a page, having an automatic refresh after many
                # refreshes will cause such a beacon GET request with a
                # t_done time span reaching to the original load of the
                # page.
                #
                if {
                    [dict exists $entries nt_con_st]
                    && [dict exists $entries nt_req_st]
                } {
                    #
                    # Add nt_*_time variables according to the "Navigation Timing" W3C recommendation
                    # up to domComplete (see https://www.w3.org/TR/navigation-timing/#processing-model)
                    #
                    dict set entries nt_start_time [expr {[dict get $entries nt_req_st] - [dict get $entries nt_nav_st]}]
                    dict set entries nt_tcp_time [expr {[dict get $entries nt_con_end] - [dict get $entries nt_con_st]}]
                    dict set entries nt_request_time [expr {[dict get $entries nt_res_st] - [dict get $entries nt_req_st]}]
                    dict set entries nt_response_time [expr {[dict get $entries nt_res_end] - [dict get $entries nt_res_st]}]
                    if {![dict exists $entries nt_domcomp]} {
                        dict set entries nt_processing_time 0
                    } else {
                        dict set entries nt_processing_time [expr {[dict get $entries nt_domcomp] - [dict get $entries nt_res_end]}]
                    }
                    if {[dict exists $entries nt_load_end]} {
                        dict set entries nt_total_time [expr {[dict get $entries nt_load_end] - [dict get $entries nt_nav_st]}]
                    } elseif {[dict exists $entries t_done]} {
                        dict set entries nt_total_time [dict get $entries t_done]
                    } else {
                        ns_log error "boomerang: cannot determine nt_total_time (no load_end nor t_done)\nentries: $entries"
                        error "cannot determine nt_total_time"
                    }

                    #
                    # Sanity checks for the computed fields:
                    # - no *_time can be larger than t_done
                    # - no *_time must be negative
                    # - check for unrealistic high t_done times (caused be technicalities)
                    set t_done [dict get $entries t_done]
                    set max_time [expr {$t_done + 1}]
                    set time_fields {
                        nt_start_time nt_tcp_time nt_request_time nt_response_time
                        nt_processing_time nt_total_time
                    }
                    foreach time_field $time_fields {
                        set v [dict get $entries $time_field]
                        if {$v < 0 || $v > $max_time} {
                            ns_log Warning "boomerang: strange value for $time_field: <$v> computed from $entries"
                            dict set entries $time_field 0
                        }
                    }
                    if {[dict get $entries nt_total_time] + 500 < $t_done} {
                        ns_log Warning "boomerang: nt_total_time [dict get $entries nt_total_time] < t_done $t_done"
                    }
                    set record 1
                } else {
                    ns_log notice "boomerang: no value for 'nt_con_st' or 'nt_req_st' in dict $entries"
                    set record 0
                }
            }
            #
            # Drop most Navigation Timing timestamps, since we have
            # the relative times (might require more fine tuning).
            #
            foreach field {
                nt_con_end
                nt_con_st
                nt_dns_end
                nt_dns_st
                nt_domcomp
                nt_domcontloaded_end
                nt_domcontloaded_st
                nt_domint
                nt_domloading
                nt_fet_st
                nt_load_end
                nt_load_st
                nt_res_st
                nt_ssl_st
                nt_unload_end
                nt_unload_st
            } {
                dict unset entries $field
            }
            set t1 [clock clicks -microseconds]

            #
            # dict is finished, now record the data when requested
            #
            if {$record} {

                :log_to_file \
                    -content [:as_json $entries] \
                    -filename boomerang-[clock format [clock seconds] -format %Y-%m-%d].log

            }

            #
            # Some common parameters:
            # https://docs.soasta.com/whatsinbeacon/#urls
            #
            #  - nu:  URL clicked, if this beacon was a result of a click
            #  - pgu: Page URL if different from u
            #  - r2:  Referrer of current page if different from r
            #  - r:   URL of previous page that Boomerang wrote into a cookie
            #  - u:   URL of Page, XHR or SPA route that caused the beacon
            #
            if {![dict exists $entries r]} {
                set r ""
            } else {
                set r [dict get $entries r]
            }
            set u   [dict get $entries u]
            set pid [dict get $entries pid]
            if {$r ne "" && $r ne $u} {
                set r " r $r"
            } else {
                set r ""
            }
            ns_log notice "boomerang::record done $pid [ns_conn method] u $u$r record $record total [expr {[clock clicks -microseconds] - $t0}] microseconds record [expr {[clock clicks -microseconds] - $t1}] "
        }
    }


    ad_proc -private get_relevant_subsite {} {

        Find the best "top" subsite on the instance.  The code is
        based on the "register subsite", which is in plain sites
        (single subsite) the top subsite, or on host-node-mapped
        subsites to mapped subsite (when the host-node map points to a
        subsite) or the main subsite. This code makes sure, we can
        provide a URL on this site. We should distinguish between
        cases where we provide a URL (e.g. the beacon) or just
        include stuff, in which case it works as well for host-node
        entries, which are no subsites..... but these cases are rare
        enough, such we don't care so far.

    } {
        set dict [security::get_register_subsite]
        if {![dict exists $dict subsite_id]} {
            set host_node_id [dict get $dict host_node_id]
            if {$host_node_id == 0} {
                #
                # Provide compatibility with older versions of
                # get_register_subsite, not returning the
                # host_node_id. In such cases, we get the host_node_id
                # via the URL
                #
                set node_info [site_node::get_from_url -url [dict get $dict url]]
                set host_node_id [dict get $node_info node_id]
            }
            set subsite_id [site_node::get_object_id -node_id $host_node_id]
        } else {
            set subsite_id [dict get $dict subsite_id]
        }
        return $subsite_id
    }


    ad_proc initialize_widget {
        {-subsite_id ""}
        {-version ""}
    } {

        Initialize an boomerang widget.

    } {
        #set t0 [clock clicks -microseconds]
        if {$subsite_id eq ""} {
            set subsite_id [get_relevant_subsite]
        }
        if {$version eq ""} {
            set version ${::boomerang::version}
        }

        set enabled_p [parameter::get \
                           -package_id $subsite_id \
                           -parameter BoomerangEnabled \
                           -default 0]
        #
        # When the package is enabled, and we are not in a "bots"
        # connection pool, look in more details.
        #
        if {$enabled_p && [ns_conn pool] ne "bots"} {
            #
            # Check, if we should sample this request
            #
            set sample [parameter::get \
                            -package_id $subsite_id \
                            -parameter BoomerangSample \
                            -default 1]
            if {$sample < 1} {
                set sample 1
            }

            if {[nsv_incr boomerange counter] % $sample == 0} {
                #
                # Yes, we can!
                #
                # Get the URL and add JavaScript to the page
                #
                set beaconURL [parameter::get \
                                   -package_id $subsite_id \
                                   -parameter BoomerangBeaconUrl \
                                   -default /boomerang_handler]

                set version_info [version_info]
                set prefix [dict get $version_info prefix]
                foreach jsFile [dict get $version_info jsFiles] {
                    template::head::add_javascript -src ${prefix}/$jsFile
                }
                #
                # One could add additional plugins here, but many are
                # already included in the provided .min.js file via the
                # upstream provided plugins.json
                #
                #        "plugins/auto-xhr.js",
                #        "plugins/spa.js",
                #        "plugins/history.js",
                #        "plugins/rt.js",
                #        "plugins/bw.js",
                #        "plugins/navtiming.js",
                #        "plugins/restiming.js",
                #        "plugins/mobile.js",
                #        "plugins/memory.js",
                #        "plugins/cache-reload.js",
                #        "plugins/md5.js",
                #        "plugins/compression.js",
                #        "plugins/errors.js",
                #        "plugins/third-party-analytics.js",
                #        "plugins/usertiming.js",
                #        "plugins/mq.js"
                #

                template::head::add_javascript -order 2 -script [subst {
                    BOOMR.init({
                        beacon_url: "$beaconURL",
                        log: null
                    });
                }]
            }
        }
        #ns_log notice "boomerang::initialize_widget [expr {[clock clicks -microseconds] - $t0}] microseconds"
    }


    ad_proc version_info {
        {-version ""}
    } {

        Get information about available version(s) of the
        boomerang packages, either from the local file system, or
        from CDN.

    } {
        #
        # If no version of the boomerange library was specified,
        # use the name-spaced variable as default.
        #
        if {$version eq ""} {
            set version ${::boomerang::version}
        }

        #
        # Provide paths for loading either via resources or CDN
        #
        set resource_prefix [acs_package_root_dir boomerang/www/resources]
        set cdn             "//cdnjs.cloudflare.com/ajax/libs"

        #
        # If the resources are not available locally, these will be
        # loaded via CDN and the CDN host is set (necessary for CSP).
        # The returned "prefix" indicates the place, from where the
        # resource will be loaded.
        #
        if {[file exists $resource_prefix]} {
            set prefix /resources/boomerang
        } else {
            #
            # So far there is no CDN form boomerang, we distribute
            # boomerang.js via static file.
            #
            set prefix $cdn/$version/
            lappend result host "cdnjs.cloudflare.com"
        }

        lappend result \
            cdn $cdn \
            prefix $prefix \
            cssFiles {} \
            jsFiles  [list boomerang-${version}.min.js]

        return $result
    }
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
