<?php

echo "option_a = ", CONST_FLAG_OPTION_A, "\n";
echo "option_b = ", CONST_FLAG_OPTION_B, "\n";
echo "option_c = ", CONST_FLAG_OPTION_C, "\n";
echo "option_a = ", CONST_MORE_OPTION_A, "\n";
echo "option_b = ", CONST_MORE_OPTION_B, "\n";
echo "_ => ", defined("CONST_FLAG__") ? "defined" : "undefined", "\n"; 
