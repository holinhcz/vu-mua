#!/bin/bash
cd /tmp/claude-0/g
L="ft_mangcut:7,15,0;ft_mangcut:9,15,1;ft_mangcut:11,15,2;ft_mangcut:13,15,3;ft_cam:7,18,0;ft_cam:9,18,1;ft_cam:11,18,2;ft_cam:13,18,3"
for pg in ${2:-live v1}; do
  SEA=0 LAND=1 node shot_flags.js b3_${pg}_dbg.html b3/g_${pg}_d.png 1280 800 2 America/New_York 2.4 "$L" 10,16 -20 '{}'
  [ "$1" = n ] && SEA=0 LAND=1 node shot_flags.js b3_${pg}_dbg.html b3/g_${pg}_n.png 1280 800 2 Asia/Bangkok 2.4 "$L" 10,16 -20 '{}'
done
