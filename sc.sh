#!/usr/bin/env bash

# Requires socat,mpv,curl,jq

API_URL='https://api-v2.soundcloud.com'

# NOTE: The soundcloud website, if visiting unauthorized, 
#       you could provide a public client_id and likely public oauth token?
CLIENT_ID='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
ACCESS_TOKEN='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
[[ -f creds ]] && source creds

get_request() {
  local C_MISC='&app_version=1655450917&app_locale=en'
  local C_CLIENT_ID="?client_id=${CLIENT_ID}"
echo 

  curl -X GET -s "${1}${C_CLIENT_ID}${C_MISC}${@:2}" \
              -H "accept: application/json; charset=utf-8" \
              -H "Authorization: OAuth ${ACCESS_TOKEN}"
}

_get_date() {
  date -d "$@" +"%Y-%m-%dT%H:%M:%S.000Z"
}

get_liked_tracks() {
  local offset=${2-2023-06-22T14:37:10.000Z}
  local C_OFFSET="&offset=$offset,user-track-likes,852-00000000000144368691-00000000000886632409"

  local limit=${1-1000}
  
  get_request ${API_URL}/users/"$me_id"/track_likes "&limit=${limit}$C_OFFSET" \
    | jq -r .collection[].track
}

iterate_all_liked_tracks () {
  # these are years:
  for year in {2024..2014}; do
    # get favorited tracks for all above years
    get_liked_tracks 1000 "$(_get_date "$year"-12-29)"
  done
}

_mpv() {
  #mpv -vo null --title=scmpv --input-ipc-server=/tmp/scmpvsock --idle=yes "$@" 
  # mpv --title=scmpv --player-operation-mode=pseudo-gui --input-ipc-server=/tmp/scmpvsock --idle=yes "$@" 
  mpv --title=scmpv --player-operation-mode=pseudo-gui --input-ipc-server=/tmp/scmpvsock --keep-open "$@" 
}

_mpv_command() {
    # JSON preamble.
    local tosend='{ "command": ['
    # adding in the parameters.
    for arg in "$@"; do
        tosend="$tosend \"$arg\","
    done
    # closing it up.
    tosend=${tosend%?}' ] }'
    # send it along
    echo "$tosend" | socat - /tmp/scmpvsock
}

_mpv_command_silent() {
    #ignore output
    # to print output just remove the redirection to /dev/null
  _mpv_command "$@" > /dev/null 2>&1
}

_mpv_get_percent_pos() {
  local percent_pos_float="$(_mpv_command 'get_property' 'percent-pos' | jq -r .data)"
  echo "${percent_pos_float%.*}"
}

#get_request /tracks/$TRACK_ID 
printf 'Getting user-id... '
me_id=$(get_request ${API_URL}/me | jq -r .id)
echo "$me_id"

tracks="$(get_liked_tracks 30)"
track_streams="$(echo "$tracks" | jq -r '.media[] | .[] | select(.format.mime_type == "audio/ogg; codecs=\"opus\"") | .url')"

_mpv &
sleep 0.5

# QUEUE MAIN LOOP
for url in ${track_streams} ; do
  track="$(get_request "$url" | jq -r '.url')"

  ### pure mpv version
  echo appending track...
  _mpv_command 'loadfile' "$track" 'append-play';
  sleep 4
  # while [ "$(_mpv_get_percent_pos)" -le "98" ] || [ "$(_mpv_command 'get_property' 'eof-reached' | jq -r .data)" = "false" ] ; do sleep 3 ; done
  while [ "$(_mpv_command 'get_property' 'eof-reached' | jq -r .data)" = "false" ] ; do true && sleep 2 ; done
  
  ###

  ###### MPC VERSION, WIP
  ## can perhaps replace the whole _mpv_command logic with "mpc" tool, but
  ## that's a dependency... See below:
  # echo inserting track...
  # mpc insert "$track"
  # sleep 4
  ## SOME LOGIC NEEDED HERE TO NOT SPAM TRACKS INTO THE QUEUE... (links for tracks expire)
  ######
done

