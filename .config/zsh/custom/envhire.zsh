typeset -a _ENVHIRE_LOADED_FILES
typeset -A _ENVHIRE_FILE_VARS
typeset -A _ENVHIRE_ORIGINAL_VALUES
typeset -A _ENVHIRE_FILE_MTIMES

ENVHIRE_DEBUG=${ENVHIRE_DEBUG:-0}

_envhire_debug() {
  (( ENVHIRE_DEBUG )) && echo "envhire debug: $1" >&2
}



_envhire_get_file_mtime() {
  local file="$1"
  if [[ -f "$file" ]]; then
    case "$OSTYPE" in
      darwin*) stat -f "%m" "$file" 2>/dev/null || echo "0" ;;
      *) stat -c "%Y" "$file" 2>/dev/null || echo "0" ;;
    esac
  else
    echo "0"
  fi
}

_envhire_parse_env_file() {
  local env_file="$1"
  local -A env_vars=()
  local -a var_order=()
  
  # First pass: collect all variable assignments
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local varname="$match[1]"
      local varvalue="$match[2]"
      
      # Remove surrounding quotes if present
      if [[ "$varvalue" =~ ^[\"\'](.*)[\"\']$ ]]; then
        varvalue="$match[1]"
      fi
      
      env_vars[$varname]="$varvalue"
      var_order+=("$varname")
    fi
  done < "$env_file"
  
  # Second pass: resolve variable references recursively
  local -i max_iterations=10
  local -i iteration=0
  local changed=1
  
  while (( changed && iteration < max_iterations )); do
    changed=0
    iteration=$((iteration + 1))
    
    for varname in "${var_order[@]}"; do
      local value="${env_vars[$varname]}"
      local new_value="$value"
      
      # Keep expanding variables in this value until no more found
      local keep_expanding=1
      while (( keep_expanding )); do
        keep_expanding=0
        
        # Check for ${VAR} format first
        if [[ "$new_value" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; then
          local ref_var="$match[1]"
          local ref_value=""
          
          # Check if referenced variable exists in our env_vars or current environment
          if [[ -n "${env_vars[$ref_var]}" ]]; then
            ref_value="${env_vars[$ref_var]}"
          elif [[ -n "${(P)ref_var}" ]]; then
            ref_value="${(P)ref_var}"
          fi
          
          # Replace the variable reference with its value
          new_value="${new_value/\$\{$ref_var\}/$ref_value}"
          keep_expanding=1
          
        # Check for $VAR format
        elif [[ "$new_value" =~ \$([A-Za-z_][A-Za-z0-9_]*) ]]; then
          local ref_var="$match[1]"
          local ref_value=""
          
          # Check if referenced variable exists in our env_vars or current environment  
          if [[ -n "${env_vars[$ref_var]}" ]]; then
            ref_value="${env_vars[$ref_var]}"
          elif [[ -n "${(P)ref_var}" ]]; then
            ref_value="${(P)ref_var}"
          fi
          
          # Replace the variable reference with its value
          new_value="${new_value/\$$ref_var/$ref_value}"
          keep_expanding=1
        fi
      done
      
      # Update if value changed
      if [[ "$new_value" != "$value" ]]; then
        env_vars[$varname]="$new_value"
        changed=1
      fi
    done
  done
  
  # Output resolved variables in original order
  for varname in "${var_order[@]}"; do
    printf '%s=%s\n' "$varname" "${env_vars[$varname]}"
  done
}

_envhire_source_env_file() {
  local env_file="$1"
  
  [[ ! -f "$env_file" ]] && return 1
  
  local current_mtime=$(_envhire_get_file_mtime "$env_file")
  local cached_mtime="${_ENVHIRE_FILE_MTIMES[$env_file]}"
  
  if [[ -n "$cached_mtime" && "$current_mtime" == "$cached_mtime" ]] && 
     (( ${_ENVHIRE_LOADED_FILES[(Ie)$env_file]} )); then
    _envhire_debug "Skipping unchanged file: $env_file"
    return 0
  fi
  
  _envhire_debug "Loading $env_file (mtime: $current_mtime)"
  
  local -a env_assignments
  env_assignments=($(_envhire_parse_env_file "$env_file"))
  
  local -a modified_vars=()
  
  for assignment in "${env_assignments[@]}"; do
    local varname="${assignment%%=*}"
    local varvalue="${assignment#*=}"
    
    # Variable expansion using eval (safer than complex regex)
    local expanded_value
    if [[ "$varvalue" == *'$'* ]]; then
      # Only use eval if there are dollar signs in the value
      expanded_value=$(eval "echo \"$varvalue\"" 2>/dev/null) || expanded_value="$varvalue"
    else
      expanded_value="$varvalue"
    fi
    
    if [[ -z "${_ENVHIRE_ORIGINAL_VALUES[$varname]}" ]]; then
      _ENVHIRE_ORIGINAL_VALUES[$varname]="${(P)varname}"
      _envhire_debug "Storing original value for $varname: ${_ENVHIRE_ORIGINAL_VALUES[$varname]}"
    fi
    
    export "$varname"="$expanded_value"
    modified_vars+=("$varname")
    _envhire_debug "Set $varname = $expanded_value (from: $varvalue)"
  done
  
  _ENVHIRE_FILE_VARS[$env_file]="${modified_vars[*]}"
  _ENVHIRE_FILE_MTIMES[$env_file]="$current_mtime"
  
  _envhire_debug "File $env_file set variables: ${modified_vars[*]}"
  return 0
}

_envhire_unload_env_file() {
  local env_file="$1"
  _envhire_debug "Unloading $env_file"
  
  local vars_str="${_ENVHIRE_FILE_VARS[$env_file]}"
  [[ -z "$vars_str" ]] && return
  
  local -a vars=($=vars_str)
  
  for var in "${vars[@]}"; do
    local original_value="${_ENVHIRE_ORIGINAL_VALUES[$var]}"
    
    if [[ -n "$original_value" ]]; then
      export "$var"="$original_value"
      _envhire_debug "Restored $var to $original_value"
      unset "_ENVHIRE_ORIGINAL_VALUES[$var]"
    else
      unset "$var"
      _envhire_debug "Unset $var"
    fi
  done
  
  unset "_ENVHIRE_FILE_VARS[$env_file]"
  unset "_ENVHIRE_FILE_MTIMES[$env_file]"
  _ENVHIRE_LOADED_FILES=("${_ENVHIRE_LOADED_FILES[@]:#$env_file}")
}

_envhire_find_parent_env_files() {
  local current_dir="$PWD"
  local -a env_files=()
  
  while [[ "$current_dir" != "/" ]]; do
    local env_file="$current_dir/.env"
    [[ -f "$env_file" ]] && env_files=("$env_file" "${env_files[@]}")
    current_dir="${current_dir:h}"
  done
  
  printf '%s\n' "${env_files[@]}"
}

_envhire_update_env() {
  local -a current_env_files
  current_env_files=($(_envhire_find_parent_env_files))
  
  (( ${#current_env_files[@]} )) && _envhire_debug "Found env files: ${current_env_files[*]}"
  
  local -a files_to_remove=()
  for loaded_file in "${_ENVHIRE_LOADED_FILES[@]}"; do
    (( ! ${current_env_files[(Ie)$loaded_file]} )) && files_to_remove+=("$loaded_file")
  done
    
  for file in "${files_to_remove[@]}"; do
    _envhire_unload_env_file "$file"
  done
  
  for env_file in "${current_env_files[@]}"; do
    if (( ! ${_ENVHIRE_LOADED_FILES[(Ie)$env_file]} )) || [[ -z "${_ENVHIRE_FILE_MTIMES[$env_file]}" ]]; then
      if _envhire_source_env_file "$env_file"; then
        (( ! ${_ENVHIRE_LOADED_FILES[(Ie)$env_file]} )) && {
          _ENVHIRE_LOADED_FILES+=("$env_file")
          _envhire_debug "Added $env_file to loaded files"
        }
      fi
    fi
  done
  
  (( ${#_ENVHIRE_LOADED_FILES[@]} )) && _envhire_debug "Currently loaded: ${_ENVHIRE_LOADED_FILES[*]}"
}

envhire_status() {
  echo -n "envhire - "
  if (( ${#_ENVHIRE_LOADED_FILES[@]} )); then
    echo ".env files:"
    for file in "${_ENVHIRE_LOADED_FILES[@]}"; do
      echo "  - $file"
      local vars="${_ENVHIRE_FILE_VARS[$file]}"
      local mtime="${_ENVHIRE_FILE_MTIMES[$file]}"
      if [[ -n "$mtime" ]]; then
        case "$OSTYPE" in
          darwin*) echo "    Modified: $(date -r "$mtime" 2>/dev/null || echo "unknown")" ;;
          *) echo "    Modified: $(date -d "@$mtime" 2>/dev/null || echo "unknown")" ;;
        esac
      fi
    done
  else
    echo "no files loaded"
  fi
}

envhire_reload() {
  echo "envhire - reloading..."
  
  local -a files_to_unload=("${_ENVHIRE_LOADED_FILES[@]}")
  for file in "${files_to_unload[@]}"; do
    _envhire_unload_env_file "$file"
  done
  
  _ENVHIRE_LOADED_FILES=()
  _ENVHIRE_FILE_VARS=()
  _ENVHIRE_FILE_MTIMES=()
  
  _envhire_update_env
  envhire_status
}

envhire_debug() {
  if (( $# == 0 )); then
    echo "envhire debug: $([[ $ENVHIRE_DEBUG -eq 1 ]] && echo "on" || echo "off")"
    return
  fi
  
  case "$1" in
    0|off|false) ENVHIRE_DEBUG=0 ;;
    1|on|true) ENVHIRE_DEBUG=1 ;;
    *) echo "envhire debug: use on/off" >&2; return 1 ;;
  esac
  
  echo "envhire debug: $([[ $ENVHIRE_DEBUG -eq 1 ]] && echo "on" || echo "off")"
}



autoload -Uz add-zsh-hook
add-zsh-hook chpwd _envhire_update_env

_envhire_update_env
