#!/usr/bin/env bash
# Stage 2 + attack previews: every action from front / side / 3-4 at 60 fps (2x slow copy for short hits).
set -e
cd "$(dirname "$0")/.."
B=Revenant_Stage2.blend; F=previews/frames/stage2; P=previews/stage2; mkdir -p $P
tile(){ out=$1; shift; n=$#; args=(); for i in "$@"; do args+=(-i "$i"); done
  ffmpeg -y -loglevel error "${args[@]}" -filter_complex "hstack=inputs=$n" -c:v libx264 -pix_fmt yuv420p -crf 20 "$out"; }
for spec in REV_HitLight_Front:12 REV_HitLight_Left:12 REV_HitLight_Right:12 REV_Death:72 REV_TeleportAttack:42 REV_BloodBurst:120 REV_ClawAttack_1:30 REV_ClawAttack_2:32 REV_ClawAttack_3:42; do
  a=${spec%%:*}; n=${spec##*:}
  for c in front side three; do tools/rc.sh $B $a $c $F/${a}_$c $F/${a}_$c.mp4 60 count=$n res=540 & done; wait
  tile $P/${a}_ThreeViews.mp4 $F/${a}_front.mp4 $F/${a}_side.mp4 $F/${a}_three.mp4
done
# Light hits are 0.2 s: also provide a 4x slow review.
for a in REV_HitLight_Front REV_HitLight_Left REV_HitLight_Right; do
  tools/rc.sh $B $a three $F/${a}_slow $P/${a}_Slow4x.mp4 60 count=48 step=0.25 res=540 &
done; wait
echo STAGE2_PREVIEWS_OK
