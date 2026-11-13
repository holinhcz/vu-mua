#!/bin/bash
cd /tmp/claude-0/g
V=${1:-v1}
L="ft_saurieng:7,15,0;ft_saurieng:9,15,1;ft_saurieng:11,15,2;ft_saurieng:13,15,3;ft_man:8,18,1;ft_mit:11,18,2;ft_saurieng:13,18,1"
for pg in live $V; do
  SEA=0 LAND=1 node shot_flags.js saurieng_${pg}_dbg.html saurieng/g_${pg}_d.png 1280 800 2 America/New_York 2.4 "$L" 10,16 -20 '{}'
  SEA=0 LAND=1 node shot_flags.js saurieng_${pg}_dbg.html saurieng/g_${pg}_n.png 1280 800 2 Asia/Bangkok 2.4 "$L" 10,16 -20 '{}'
done
