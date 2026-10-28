<?php

$uint8 = new Uint8Array([1, 2, 3]);
echo $uint8->includes(2), "\n"; // true
echo $uint8->includes(4), "\n"; // false
echo $uint8->includes(3, 3), "\n"; // false
