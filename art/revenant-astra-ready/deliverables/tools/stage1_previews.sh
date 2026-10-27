#!/usr/bin/env bash
# Stage 1 preview set. Usage: tools/stage1_previews.sh
set -e
cd "$(dirname "$0")/.."
B=Revenant_Stage1.blend; F=previews/frames/stage1; P=previews/stage1; mkdir -p $P
rc=tools/rc.sh
tile(){ # out in1 in2 [in3]
  out=$1; shift; n=$#; args=(); for i in "$@"; do args+=(-i "$i"); done
  ffmpeg -y -loglevel error "${args[@]}" -filter_complex "hstack=inputs=$n" -c:v libx264 -pix_fmt yuv420p -crf 20 "$out"; }
# Idle: 3 loops of the 90-frame cycle at 60 fps, three angles.
for c in front side three; do $rc $B REV_Idle $c $F/idle_$c $F/idle_$c.mp4 60 cycle=90 count=180 res=540 & done; wait
tile $P/Stage1_Idle_ThreeViews.mp4 $F/idle_front.mp4 $F/idle_side.mp4 $F/idle_three.mp4
# AgileMove at its authored 2.45 m/s, travelling over the grid floor (shows foot lock).
for c in side three front; do $rc $B REV_AgileMove_InPlace $c $F/glide_$c $F/glide_$c.mp4 60 cycle=24 count=96 travel=2.45 res=540 & done; wait
tile $P/Stage1_AgileMove_Normal_2.45mps.mp4 $F/glide_front.mp4 $F/glide_side.mp4 $F/glide_three.mp4
# 50% speed: half-frame steps, still 60 fps output.
for c in side three; do $rc $B REV_AgileMove_InPlace $c $F/glide50_$c $F/glide50_$c.mp4 60 cycle=24 count=96 step=0.5 travel=2.45 res=540 & done; wait
tile $P/Stage1_AgileMove_HalfSpeed.mp4 $F/glide50_side.mp4 $F/glide50_three.mp4
# In-game target speed: Bloodwake moves the Revenant at 6 m/s -> REV_AgileRun_InPlace.
for c in side three game; do $rc $B REV_AgileRun_InPlace $c $F/run_$c $F/run_$c.mp4 60 cycle=36 count=108 travel=6.0 res=540 & done; wait
tile $P/Stage1_AgileRun_GameSpeed_6mps.mp4 $F/run_side.mp4 $F/run_three.mp4 $F/run_game.mp4
$rc $B REV_AgileMove_InPlace game $F/glide_game $F/glide_game.mp4 60 cycle=24 count=96 travel=2.45 res=540
# Silhouette read of both gaits.
$rc $B REV_AgileMove_InPlace side $F/sil_glide $F/sil_glide.mp4 60 cycle=24 count=48 sil=1 res=540 &
$rc $B REV_AgileRun_InPlace side $F/sil_run $F/sil_run.mp4 60 cycle=36 count=72 sil=1 res=540 &
$rc $B REV_Idle side $F/sil_idle $F/sil_idle.mp4 60 cycle=90 count=90 sil=1 res=540 &
wait
tile $P/Stage1_Locomotion_Silhouette.mp4 $F/sil_glide.mp4 $F/sil_run.mp4
cp $F/glide_game.mp4 $P/Stage1_AgileMove_GameCamera.mp4
echo STAGE1_PREVIEWS_OK
