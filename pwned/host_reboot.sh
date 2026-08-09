#!/bin/sh
(
  sleep 5
  sync
  echo 1 > /proc/sys/kernel/sysrq
  echo s > /proc/sysrq-trigger
  sleep 1
  echo u > /proc/sysrq-trigger
  sleep 1
  echo b > /proc/sysrq-trigger
) &
exit 0