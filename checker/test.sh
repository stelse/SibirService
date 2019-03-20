#!/bin/bash

for ((i=0; i<100; i++))
do
# random uuid
FLAG_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
FLAG=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
FLAG=$FLAG-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 4 | head -n 1)
FLAG=$FLAG-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 4 | head -n 1)
FLAG=$FLAG-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 4 | head -n 1)
FLAG=$FLAG-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 12 | head -n 1)

./checker.pl "127.0.0.1" "put" $FLAG_ID $FLAG

./checker.pl "127.0.0.1" "check" $FLAG_ID $FLAG
done
