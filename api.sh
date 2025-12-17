#!/bin/sh -eux

ls_demo_ip="$(lxc ls -c4 --format csv ls-demo | awk '{print $1}')"

[ -n "$JWT" ] ||
	printf 'Please provide your access-key and secret-key for your Landscape admin account\n'
	
	printf '\tAccess key:'
	read -r _accesskey
	printf '\tSecret key:'
	read -r _secretkey
	
	# https://documentation.ubuntu.com/landscape/how-to-guides/api/make-a-rest-api-request/#sso-make-a-rest-api-request-with-curl
	
	# Fetch the user's special token
	JWT="$(curl -X POST "${ls_demo_ip}"/api/v2/login/access-key \
				 -H "Content-Type: application/json" \
				 -d "{\"access_key\": \"${_accesskey}\", \"secret_key\": \"${_secretkey}\"}" | jq .token)"
	
echo "$JWT" > .jwt

device_list() {
	curl -X GET "${ls_demo_ip}"/api/v2/computers \
		-H "Authorization: Bearer $JWT" |\
		jq '.resuts[] | "\(.title) \(.id)"'
}

# get_scripts requests a list of scripts available for remote execution
# TBD -- the endpoint returns a whole list but we need the *id*, not the *name*
#   It takes an optional argv1 to check for a specific name
get_scripts() {
	_name="$1"

	# If a name was provided, we're checking if the script exists
	[ -z "$_name" ] || {
	curl -X GET "${ls_demo_ip}"/api/?action=GetScripts |\
		jq .title |\
		grep -q recovery-keys || create_script "$_name"
	}

	# Otherwise return all scripts
	curl -X GET "${ls_demo_ip}"/api/?action=GetScripts
}

# legacy -> post to https://<LANDSCAPE-HOSTNAME>/api

# execute_script runs the specified script by ID on some tagged list of devices
execute_script() {
	id="$1"
	tag="$2"

	get_scripts "$id"

	curl -X POST \
		"${ls_demo_ip}"/api/?action=ExecuteScript&script_id${id}&query=tag:${tag}&username=root \
		-H "Authorization: Bearer $JWT"
	
}

# Create a script
# ?action=CreateScript&title=Example&interpreter=python&time_limit=200&code=aGVsbG8=

create_script() {
	_code="$1"

	curl -X POST \
		"${ls_demo_ip}"/api/?action=CreateScriipt&title=recovery-keys&interpreter=python&time_limit=200&code="${_code}"
}

# This script:
#   cat > recovery-keys << EOF
#   #!/bin/env python3
#   from landscape.client import snap_http

#   query_parrams = {}

#   return http.get("/system-recovery-keys", query_params=query_params)
#   EOF
# Is ZnJvbSBsYW5kc2NhcGUuY2xpZW50IGltcG9ydCBzbmFwX2h0dHAKCnF1ZXJ5X3BhcnJhbXMgPSB7fQoKcmV0dXJuIGh0dHAuZ2V0KCIvc3lzdGVtLXJlY292ZXJ5LWtleXMiLCBxdWVyeV9wYXJhbXM9cXVlcnlfcGFyYW1zKQo=

create_script ZnJvbSBsYW5kc2NhcGUuY2xpZW50IGltcG9ydCBzbmFwX2h0dHAKCnF1ZXJ5X3BhcnJhbXMgPSB7fQoKcmV0dXJuIGh0dHAuZ2V0KCIvc3lzdGVtLXJlY292ZXJ5LWtleXMiLCBxdWVyeV9wYXJhbXM9cXVlcnlfcGFyYW1zKQo=

# get_script | ... a pipeline ... | execute_script 

