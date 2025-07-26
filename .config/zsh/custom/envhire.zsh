# Simple .env file loader with stacked file support

typeset -ga _ENVHIRE_LOADED_FILES=()
typeset -A _ENVHIRE_FILE_VARS=()

_envhire_find_env_files() {
  local dir="$PWD"
  local -a env_files=()
  
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.env" ]] && env_files=("$dir/.env" "${env_files[@]}")
    dir="${dir:h}"
  done
  
  printf '%s\n' "${env_files[@]}"
}

_envhire_load_file() {
  local env_file="$1"
  local -a vars=()
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ '^[[:space:]]*#' ]] && continue
    
    if [[ "$line" =~ '^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$' ]]; then
      local var="$match[1]" value="$match[2]"
      
      [[ "$value" =~ '^["\'"'"'](.*)["'"'"']$' ]] && value="$match[1]"
      
      # Expand variables if they contain $ signs
      if [[ "$value" == *'$'* ]]; then
        value=$(eval "echo \"$value\"" 2>/dev/null) || value="$value"
      fi
      
      vars+=("$var")
      export "$var"="$value"
    fi
  done < "$env_file"
  
  _ENVHIRE_FILE_VARS[$env_file]="${vars[*]}"
}

_envhire_unload_file() {
  local env_file="$1"
  local vars_str="${_ENVHIRE_FILE_VARS[$env_file]}"
  [[ -z "$vars_str" ]] && return
  
  local -a vars=($=vars_str)
  for var in "${vars[@]}"; do
    unset "$var"
  done
  
  unset "_ENVHIRE_FILE_VARS[$env_file]"
  _ENVHIRE_LOADED_FILES=("${_ENVHIRE_LOADED_FILES[@]:#$env_file}")
}

_envhire_update() {
  local -a current_files new_files files_to_remove
  current_files=($(_envhire_find_env_files))
  
  for loaded_file in "${_ENVHIRE_LOADED_FILES[@]}"; do
    (( ! ${current_files[(Ie)$loaded_file]} )) && files_to_remove+=("$loaded_file")
  done
  
  for file in "${files_to_remove[@]}"; do
    _envhire_unload_file "$file"
  done
  
  for env_file in "${current_files[@]}"; do
    if (( ! ${_ENVHIRE_LOADED_FILES[(Ie)$env_file]} )); then
      _envhire_load_file "$env_file"
      _ENVHIRE_LOADED_FILES+=("$env_file")
    fi
  done
}

envhire_status() {
  if (( ${#_ENVHIRE_LOADED_FILES[@]} )); then
    echo "envhire: ${#_ENVHIRE_LOADED_FILES[@]} .env files loaded:"
    for file in "${_ENVHIRE_LOADED_FILES[@]}"; do
      local vars_str="${_ENVHIRE_FILE_VARS[$file]}"
      local -a vars=($=vars_str)
      echo "  $file (${#vars[@]} vars: ${vars[*]})"
    done
  else
    echo "envhire: no .env files loaded"
  fi
}

envhire_reload() {
  echo "envhire: reloading..."
  
  local -a files_to_unload=("${_ENVHIRE_LOADED_FILES[@]}")
  for file in "${files_to_unload[@]}"; do
    _envhire_unload_file "$file"
  done
  
  _ENVHIRE_LOADED_FILES=()
  _ENVHIRE_FILE_VARS=()
  
  _envhire_update
  envhire_status
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _envhire_update

_envhire_update
