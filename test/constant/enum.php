<?php

echo enum_exists("ConstEnum") ? "exists" : "missing", "\n";
echo "hello = ", ConstEnum::hello->value, "\n";
echo "world = ", ConstEnum::world->value, "\n";
echo "alpha = ", ConstType::alpha->value, "\n";
echo "beta = ", ConstType::beta->value, "\n";
echo "gamma = ", ConstType::gamma->value, "\n";
echo "a = "; 
print_r(ConstType::a);
echo "b = ";
print_r(ConstType::b);
