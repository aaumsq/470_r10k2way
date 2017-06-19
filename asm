#!/bin/bash
if [[ $# -ne 1 ]]; then
	echo "name not given"
else
	./vs-asm "test_progs/$1.s" > program.mem
fi
