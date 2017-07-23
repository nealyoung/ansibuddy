#!/usr/bin/env bash

# Constants
inventory_dir_name="inventories"
playbook_dir_name="playbooks"
ansible_project_base="$(dirname $0)"
inventory_base_dir=$ansible_project_base/$inventory_dir_name
playbook_base_dir=$ansible_project_base/$playbook_dir_name

# Defaults
default_playbook_file_name="site.yml"

# Script-specific commands like "check", "help", and "list-hosts"
ansible_append_flags=()

# @TODO: Bianca Tamayo (Jul 22, 2017) - Just check if it's used with any "..." or more than two slashes
if [[ $PWD != *"ansibuddy" ]]; then
    echo "FATAL: Current directory may not be project root (where ap.sh is)"
fi

# Functions
usage() {
    echo "$1"
    local help_text="
    USAGE
        $0 <HOSTGROUP> <COMMAND> [...OPTIONS] [...ARGS]

    DESCRIPTION
        A wrapper script around ansible-playbook

    HOSTGROUP
        The HOSTGROUP is the group in the inventory file to target

    COMMAND
        check       Runs syntax-check on determined playbook
        list-hosts  Lists hosts affected by a playbook
        help        Print this help
    "

    echo "$help_text"
}

find_inventory() {
    echo "INFO: Looking for group: $hostgroup"

    # Parse hostgroup name
    IFS='.' read -ra tokens <<< "$hostgroup"

    # Try to find a group in the inventory that fits it
    # /inventories/{service}/{environment}/hosts then save the group
    # e.g. bianca-blog.dev.docker

    # Needs to be at least two, since we don't just deploy to "bianca-blog"
    if [[ "${#tokens[@]}" -gt 1 ]]; then
        # Parse by <service>.<env>
        service_name="${tokens[0]}"
        env_name="${tokens[1]}"

        # Remove first two els
        grp=("${tokens[@]:2}")
    fi

    hostsfile_find_path="$inventory_base_dir/$service_name/$env_name"

    echo "INFO: Finding group [$grp] in $hostsfile_find_path/hosts"

    if [[ ! -d "$hostsfile_find_path" ]]; then
        echo "DEBUG: $hostsfile_find_path does not exist."
        parsed_hostgroup="$hostgroup"
    fi

    if [[ -d "$hostsfile_find_path" && ! -f "$hostsfile_find_path/hosts" ]]; then
        echo "DEBUG: hosts file in $hostsfile_find_path does not exist."
        parsed_hostgroup="$hostgroup"
    fi

    hostsfile_final_path="$hostsfile_find_path"
    # @TODO: Bianca Tamayo (Jul 22, 2017) - Handle cases like this: bianca-blog.dev.docker.webserver
    # bianca-blog.dev.docker&webserver
    # bianca-blog.dev&stage.docker&webserver



    # @TODO: Bianca Tamayo (Jul 22, 2017) - Create generator functions
    # @TODO: Bianca Tamayo (Jul 22, 2017) - Fallback to ansible find path


}

# Find playbook
# If the passed_playbook_file_name looks like a path, find it in that path first relative to ./playbooks/ then relative to basedir, unless it's absolute

find_playbook_in_paths() {
    local test_path

    for test_path in "${check_file_paths[@]}"; do
        if [[ -f "$test_path" ]]; then
            playbook_final_path="$test_path"
            echo "DEBUG: Playbook found in: $playbook_final_path"
            break;
        else
            echo "DEBUG: Playbook not found in: $test_path"
        fi
    done
}

# Check if path is absolute
parse_playbook_path() {

    if [[ "$passed_playbook_file_name" = /* ]]; then
        playbook_final_path=$passed_playbook_file_name
    
    elif [[ "$passed_playbook_file_name" = ./* ]]; then
        
        playbook_find_dir=$passed_playbook_file_name

        # Maybe it's a file to an actual playbook
        if [[ -f "$playbook_find_dir" ]]; then
            playbook_final_path=$playbook_find_dir
        fi
    
    else
        # Start looking relative to playbook base dir, then to $pwd

        # Unless it's in the ansble ignore cgf
        # ./playbooks/{service_name}.yml > ./playbooks/{service_name}
        check_file_paths=( "${playbook_base_dir}/${service_name}.yml" )
        check_file_paths+=( "${playbook_base_dir}/${service_name}.yaml" )

        service_playbook_base_path="${playbook_base_dir}/${service_name}"

        # Run block
        find_playbook_in_paths

        # If it found it, good, if not, update the search paths
        if [[ ! -f "$playbook_final_path" && -d "$service_playbook_base_path" ]]; then
            check_file_paths=("${service_playbook_base_path}/${service_name}.yml")
            check_file_paths+=("${service_playbook_base_path}/site.yml")

            # Run block again
            find_playbook_in_paths
        fi

        # If it's still not found
        # Check existence of extensionless playbook files
        if [[ ! -f "$playbook_final_path" ]]; then
            check_file_paths=( "${playbook_base_dir}/${service_name}" )
            check_file_paths+=("${service_playbook_base_path}/${service_name}")

            # Run block again
            find_playbook_in_paths
        fi
    fi

    # If it still can't find it, assign the final to the default and don't even bother checking if it's a file
    if [[ ! -f "$playbook_final_path" ]]; then
        playbook_final_path="$default_playbook_file_name"
    fi
}


parse_args() {
    hostgroup="$1"; shift;

    if [[ -z "$hostgroup" ]]; then
        usage "Error: Missing hostgroup";
        exit 0;
    fi


    if [[ "$#" == 0 ]]; then
        usage "Error: Missing action";
        exit 0;
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            help)
                usage

                exit 0
                ;;
            check) ansible_append_flags+=("--syntax-check")
                shift
                ;;
            list-hosts) ansible_append_flags+=("--list-hosts")
                shift
                ;;
            *)  passed_playbook_file_name="$1"; shift;; # TODO: Bianca Tamayo (Jul 22, 2017) - this will keep looping if there's unhandled args, also it does not maintain order

            --)
                break; shift;;
        esac
    done
}




# ------- MAIN  -------

echo "DEBUG: [INPUT]" "$@"

# Begin parse
parse_args "$@"

echo ""
echo "DEBUG: Passed hostgroup: $hostgroup"
echo "DEBUG: Passed playbook name or path: $passed_playbook_file_name"
echo "DEBUG: Passed Commands:" "${ansible_append_flags[*]}"

# Begin logic
find_inventory

# Find a playbook directory that has the same name as the service name

# If the playbook is specified and named exactly the same as the playbook in the directory, choose that play
# e.g. ./playbooks/bianca-blog.yml > ./playbooks/bianca-blog/bianca-blog.yml > ./playbooks/bianca-blog/site.yml
parse_playbook_path

# ---------------------


# Construct the ansible command
playbook_command="ansible-playbook -i $hostsfile_final_path $playbook_final_path ${ansible_append_flags[*]}"


echo "DEBUG: Additional options:" "$@"

echo "DEBUG: Parsed env_name, service_name: $service_name, $env_name"
echo "DEBUG: Parsed groupname in host:" "${grp[@]}"
echo ""
echo "DEBUG: Looking for inventory in: $hostsfile_find_path"
echo "DEBUG: Playbook file: $playbook_file"

echo ""
echo "DEBUG: [FINAL]: $playbook_command"



# Test: no hostgroup, invalid filenames, invalid group names, options switched around, no extra args

# TODO: Bianca Tamayo (Jul 22, 2017) - Add prompt and suppress prompt



# End of file