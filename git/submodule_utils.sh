# git_config_submodules and __git_sclone: clones a repository with submodules
# Precondition: if the submodules have submodules,
#               they must also be direct submodules of the repository # TODO: check it is the case
#               and everybody must point to the same commit of the submodules # TODO: check it is the case
# 1. clone a repository
# 2. init and update direct submodules
# 3. for each submodules,
#        checkout the branch associated to the commit (there should be one!)
#        init its submodules
#        make their working directory point to the one already present
__git_config_submod_wd() {
  main_repo_path=$1
  sm_path=$2

  # checkout branch of commit
  branch_name="$(git rev-parse HEAD | xargs git name-rev --name-only --no-undefined)"
  if (($? != 0)); then
    commit=$(git rev-parse HEAD)
    echo "Warning: commit ${commit} of submodule ${sm_path} isn't associated to a branch"
  elif [[ ${branch_name} =~ (.*)~ ]]; then
    branch_name_base=${BASH_REMATCH[1]}
    echo "Warning: submodule ${sm_path} is not up-to-date with ${branch_name_base} (it is at position ${branch_name}). Leaving ${sm_path} in a \"detached head\" state"
  elif [[ ${branch_name} =~ .*/(.*) ]]; then # if the branch is not master, `git name-rev` returns a remote branch name...
    local_branch_name=${BASH_REMATCH[1]}
    git checkout ${local_branch_name} # ... just checkout the local branch name
  else
    git checkout ${branch_name}
  fi

  # init
  git submodule init

  # each subsub repo is also a sub repo, so
  # for each subsub repo, make the working dir be a pointer to the corresponding sub repo
  subsubmod_conf_paths=$(git config --file .gitmodules --name-only --get-regexp path)
  for subsubmod_conf_path in ${subsubmod_conf_paths}; do
    if [[ ${subsubmod_conf_path} =~ submodule\.(.*)\.path ]]; then
      submod_path=${BASH_REMATCH[1]}

      # If subsubmodule is shared with main project, create a git link
      if [ -d $main_repo_path/.git/modules/$submod_path ]; then
        echo gitdir: $main_repo_path/.git/modules/$submod_path > $submod_path/.git
      # Otherwise, subsubmodule must be ckecked out by the submodule. If the subsubmodule is an
      # "external" (i.e. required) submodule, update is not allowed to fail. Otherwise, just ignore the
      # missing submodule.
      else
        trap : SIGINT # catch signal SIGINT (used by Ctrl-C) and do nothing
        git submodule update $submod_path
        status=$?
        trap - SIGINT # reset
        if (($status != 0)); then
          echo
          echo "Warning: could not fetch submodule extension $submod_path"
        fi
      fi

    else
      echo "Error trying to parse .gitmodules of submodule ${sm_path} (main repository: ${main_repo_path})"; exit 1
    fi
  done
}
export -f __git_config_submod_wd

git_config_submodules() {
  toplevel=$(git rev-parse --show-toplevel)
  sm_paths=$(grep path .gitmodules | sed 's/.*= //')
  for sm_path in ${sm_paths}; do
    echo
    echo "Configuring submodule ${sm_path}..."
    (cd ${sm_path} && __git_config_submod_wd ${toplevel} ${sm_path})
  done
  status=$?
  echo
  if (($status != 0)); then
    echo "Configuring submodules failed"; exit 1
  else
    echo "Successfully configured submodules"
  fi
}
export -f git_config_submodules
git_init_submodules() {
  sm_names=$(cd external/ && ls)
  for sm_name in ${sm_names}; do
    sm_path="external/${sm_name}"
    echo "Initializing submodule ${sm_path}..."
    trap : SIGINT # catch signal SIGINT (used by Ctrl-C) and do nothing
    git submodule update --init ${sm_path}
    status=$?
    trap - SIGINT # reset
    if (($status != 0)); then
      echo
      echo "Warning: could not fetch submodule ${sm_path}"
    fi
  done
}
export -f git_init_submodules

__git_sclone() {
  # clone without submodules
  clone_text="$(LANG=en_US git clone $@ 2>&1)"
  status=$?
  echo ${clone_text}
  if (($status != 0)); then
    echo "Command \"git clone $@\" failed"; exit 1
  else
    echo "Successfully cloned the main repository"
  fi

  # get the name of the folder cloned
  if [[ ${clone_text} =~ .*Cloning\ into\ \'(.*)\'.* ]]; then
    repository_name=${BASH_REMATCH[1]}
  else
    echo "In __git_sclone: unable to parse output of \"git clone $@\""; exit 1
  fi

  # update submodules and create git "symlinks" from subsubmodules to main repository submodules
  (cd ${repository_name}
    status=$?
    if (($status != 0)); then
      echo "Unable to access folder \"${repository_name}\""; exit 1
    fi

    git_init_submodules
    status=$?
    if (($status != 0)); then
      echo "Cloning of submodules failed"; exit 1
    else
      echo "Successfully cloned submodules"
    fi

    git_config_submodules
  )
}
export -f __git_sclone

__git_scheckout() {
  git checkout "$@" && git submodule update --init;
}
export -f __git_scheckout

# see https://stackoverflow.com/a/56236629/1583122
__git_spush() {
  git submodule foreach 'git push' && git push "$@";
}
export -f __git_spush


# aliases and more verbose status
git config --global status.submoduleSummary true
git config --global diff.submodule log

git config --global alias.sclone '! __git_sclone'
git config --global alias.scheckout '! __git_scheckout'
git config --global alias.spush '! __git_spush'
