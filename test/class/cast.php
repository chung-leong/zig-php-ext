<?php

$object = new WithCastObject(M_PI);
echo "to bool => ", var_export((bool) $object, true), "\n";
echo "to int => ", var_export((int) $object, true), "\n";
echo "to float => ", var_export((float) $object, true), "\n";
echo "to string => ", var_export((string) $object, true), "\n";
