#!/bin/bash
cd /tmp/claude-0/g
V=${1:-v1}
L="ft_me:7,15,0;ft_me:9,15,1;ft_me:11,15,2;ft_me:13,15,3;ft_man:8,18,1;ft_mit:11,18,2;ft_me:13,18,1"
for pg in live $V; do
  SEA=0 LAND=1 node shot_flags.js me_${pg}_dbg.html me/g_${pg}_d.png 1280 800 2 America/New_York 2.4 "$L" 10,16 -20 '{}'
  SEA=0 LAND=1 node shot_flags.js me_${pg}_dbg.html me/g_${pg}_n.png 1280 800 2 Asia/Bangkok 2.4 "$L" 10,16 -20 '{}'
done
