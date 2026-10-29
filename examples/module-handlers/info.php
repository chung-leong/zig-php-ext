<?php 

use module_x\Pet;
use module_x\Flags;

ini_set("module_handlers.pet", Pet::cat);
ini_set("module_handlers.flags", Flags::option_a | Flags::option_b);

phpinfo();
