ad_library {

    Callback procs for Boomerang Library into OpenACS

    @author Gustaf Neumann
    @creation-date 2 Jan 2018
    @cvs-id $Id$
}

namespace eval ::boomerang {

    #
    # Provide hooks for installing/uninstalling the package
    #
    ad_proc -private after-install {} {
	#
	# Add additional parameters to acs-subsite
	#
	foreach {name description default datatype} {
	    "Enabled"
	    "Enable/Disable Boomerang for this Subsite"
	    "0" "number"

	    "BeaconUrl"
	    "URL for the Beacon. Either a relative URL for the subsite, or and absolute URL pointing to a different Server"
	    "/boomerang_handler" "string"

	    "Sample"
	    "Integer greater or equal 1, indicating how many requests should be sampled (e.g. 10 means: sample every 10th request)"
	    "1" "number"

	} {
	    apm_parameter_register "Boomerang$name" \
		$description "acs-subsite" $default $datatype "Boomerang"
	}
    }

    ad_proc -private before-uninstall {} {
	#
	# Remove the package specific parameters from acs-subsite
	#
	foreach parameter {
	    Enabled
	    BeaconUrl
	    Sample
	} {
	    ns_log notice [list apm_parameter_unregister \
			       -parameter "Boomerang$parameter" \
			       -package_key "acs-subsite" \
			       "" ]
	    ::try {
		apm_parameter_unregister \
		    -parameter "Boomerang$parameter" \
		    -package_key "acs-subsite" \
		    ""
	    } on error {errMsg} {
		ns_log notice "apm_parameter_unregister of parameter Boomerang$parameter lead to: $errMsg"
	    }
	}
    }


    #
    # Register a "page_plugin" callback for the subsite. In case, this
    # is used with an OpenACS version earlier than 5.10.0d2, this is
    # essentially no-op operation; the site admin has to add the
    # "::boomerang::initialize_widget" manually to the templates.
    #
    ad_proc -public -callback subsite::page_plugin -impl boomerang {
    } {
	Implementation of subsite::page_plugin for boomerang
    } {
	::boomerang::initialize_widget
    }

}
