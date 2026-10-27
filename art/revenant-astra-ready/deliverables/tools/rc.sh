#!/usr/bin/env bash
# rc.sh BLEND ACTION CAM FRAMEDIR MP4|- FPS [key=value ...]  - render (retrying driver crashes) and encode
set -u
blend=$1; action=$2; cam=$3; dir=$4; mp4=$5; fps=$6; shift 6
count=48; for a in "$@"; do case $a in count=*) count=${a#count=};; frames=*) f=${a#frames=}; count=$(echo $f | tr "," "\n" | wc -l);; esac; done
here="$(cd "$(dirname "$0")" && pwd)"
for i in $(seq 1 12); do
  n=$(ls "$dir"/*.png 2>/dev/null | wc -l)
  [ "$n" -ge "$count" ] && break
  blender -b "$blend" --python "$here/render_clip.py" -- "$action" "$cam" "$dir" "$@" > /dev/null 2>&1
done
n=$(ls "$dir"/*.png 2>/dev/null | wc -l)
[ "$n" -ge "$count" ] || { echo "RENDER FAILED $action $cam ($n/$count)"; exit 1; }
if [ "$mp4" != "-" ]; then
  mkdir -p "$(dirname "$mp4")"
  ffmpeg -y -loglevel error -framerate "$fps" -i "$dir/%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 20 "$mp4"
fi
echo "OK $action $cam $n"
