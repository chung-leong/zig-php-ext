<?php

$uint8 = new Uint8Array([2, 5, 9, 2]);
echo $uint8->lastIndexOf(2), "\n"; // 3
echo $uint8->lastIndexOf(7), "\n"; // -1
echo $uint8->lastIndexOf(2, 3), "\n"; // 3
echo $uint8->lastIndexOf(2, 2), "\n"; // 0
echo $uint8->lastIndexOf(2, -2), "\n"; // 0
echo $uint8->lastIndexOf(2, -1), "\n"; // 3
