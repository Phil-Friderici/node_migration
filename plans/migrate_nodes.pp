# Removes and installs new puppet agent, swtiches agent to new master.
# Parameters:
# targets (default=undef) comma-separated list of targets to run against.
# master (default=undef) FQDN of Puppet master to migrate to.
# noop (default=false) run the plan in noop.
# pp_role (default=undef) tag the target's role with a trusted fact "pp_role".
# set_noop (default=true) leave the target agent configured in noop mode after installing puppet.
# remove_puppet_before_install (default=true) remove puppet and ssl certs before installing.
# strict_role_checking (default=false) fails the plan if the node's current role (in classes.txt) does not match pp_role parameter.
# (NOTE: current version of PE [2019.5.0] does not support puppet strings documentation in metadata)
plan node_migration::migrate_nodes(
  TargetSpec $targets,
  String[1]  $master,
  String[1]  $pp_role,
  Boolean    $noop = false,
  Boolean    $set_noop = true,
  Boolean    $remove_puppet_before_install = true,
  Boolean    $strict_role_checking = false,
) {

  $target_nodes      = get_targets($targets)
  $pp_role_set       = $pp_role.strip
  $extension_request = "pp_role=${pp_role_set}"

  # Check current roles and warn if not matched to pp_role
  $role_statuses               = run_task( 'node_migration::get_role', $target_nodes, _catch_errors => true )
  $failed_to_match_target_role = $role_statuses.filter |$result| { "${result.value['_output']}".strip != "role::${pp_role_set}" }
  if $failed_to_match_target_role.length > 0 {
    $nodes_that_failed_to_match_target_role = get_targets($failed_to_match_target_role.map |$n| {$n.target})
    $role_data = $failed_to_match_target_role.map |$node| { "${node.target} => \"${node.value['_output'].strip}\"" }
    out::message("WARNING: A total of ${failed_to_match_target_role.length} target nodes do not match the role \"${pp_role_set}\": \n${role_data}")
    if $strict_role_checking {
      fail_plan('Plan Failed: (strict_role_checking=true) For one or more nodes; pp_role does not match the current role found in classes.txt, this may mean that an invalid role has been specified!', 'profile/migrate_nodes', {'details' => $role_data})
    }
  }

  unless $noop {
    # Remove puppet
    if $remove_puppet_before_install {
      $remove_puppet_results = run_task('node_migration::remove_puppet', $target_nodes, _catch_errors => true, _run_as => root)
      unless $remove_puppet_results.ok {
        fail_plan('Plan Failed: failed to remove puppet on one or more nodes', 'profile/migrate_nodes', {'failedtargets' => $remove_puppet_results.error_set.names})
      }
    }

    # Install puppet
    $bootstrap_results = run_task( 'bootstrap',
      $target_nodes, master => $master, set_noop => $set_noop, extension_request => [$extension_request], _catch_errors => true, _run_as => root
    )
    unless $bootstrap_results.ok {
      fail_plan('Plan Failed: failed to bootstrap one or more nodes', 'profile/migrate_nodes', {'failedtargets' => $bootstrap_results.error_set.names})
    }

    # Check noop status after bootstrapping
    $noop_statuses      = run_task( 'puppet_conf', $target_nodes, section => agent, setting => noop, action => get, _catch_errors => true, _run_as => root )
    $failed_to_set_noop = $noop_statuses.filter |$result| { $result.value['status'] != String($set_noop) }
    if $failed_to_set_noop.length > 0 {
      $nodes_that_failed_to_set_noop = get_targets($failed_to_set_noop.map |$n| {$n.target})
      out::message("A total of ${failed_to_set_noop.length} target nodes do not have noop set to: ${set_noop} - bootstrap should have set this - re-attempting set noop on: ${nodes_that_failed_to_set_noop}")
      $retry_noop_statuses = run_task('puppet_conf', $nodes_that_failed_to_set_noop, section => agent, setting => noop, action => set, value => "${set_noop}", _catch_errors => true, _run_as => root )
      unless $retry_noop_statuses.ok { fail_plan('Plan Failed: failed to noop one or more nodes', 'profile/migrate_nodes', { 'failedtargets' => $retry_noop_statuses.error_set}) } else {
        out::message("Successfully reset noop on: ${nodes_that_failed_to_set_noop}")
      }
    }
    return("Migrated ${target_nodes.length} nodes: ${target_nodes}")
  } else {
    return("(noop) Would have migrated ${target_nodes.length} nodes: ${target_nodes}")
  }
}


