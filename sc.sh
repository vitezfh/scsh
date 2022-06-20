#!/usr/bin/env bash

# Requires socat,mpv,curl,jq

API_URL='https://api-v2.soundcloud.com'

# NOTE: The soundcloud website, if visited unauthorized, 
#       provides a public client_id and likely oauth token
CLIENT_ID='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
ACCESS_TOKEN='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
source creds


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
  
  get_request ${API_URL}/users/$me_id/track_likes "&limit=${limit}$C_OFFSET" \
    | jq -r .collection[].track
}

iterate_all_liked_tracks () {
  for i in {24..14}; do
    get_liked_tracks 1000 "$(_get_date 20$i-12-29)"
  done
}

_mpv() {
  #mpv -vo null --title=scmpv --input-ipc-server=/tmp/scmpvsock --idle=yes "$@" 
  mpv --title=scmpv --player-operation-mode=pseudo-gui --input-ipc-server=/tmp/scmpvsock --idle=yes "$@" 
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
    # send it along and ignore output.
    # to print output just remove the redirection to /dev/null
    echo $tosend | socat - /tmp/scmpvsock > /dev/null 2>&1
}


#get_request /tracks/$TRACK_ID 
printf 'Getting user-id... '
me_id=$(get_request ${API_URL}/me | jq -r .id)
echo $me_id

tracks="$(get_liked_tracks 10)"
track_streams="$(echo $tracks | jq -r '.media[] | .[] | select(.format.mime_type == "audio/ogg; codecs=\"opus\"") | .url')"

# WIP
# sleep 0.5
# for url in ${track_streams} ; do
#   track="$(get_request $url | jq -r '.url')"
#   echo
#   mpc insert "$track"
#   sleep 1
# done
# exit 

_mpv &
sleep 0.5
for url in ${track_streams} ; do
  track="$(get_request $url | jq -r '.url')"
  _mpv_command 'loadfile' "$track" 'append-play';
  sleep 1
  # $(_mpv_command 'get_property' 'percent-pos';)
  while ! $(_mpv_command 'get_property' 'idle-active' | jq -r .data) true ; do sleep 1 ; done > /dev/null 2>&1
done
