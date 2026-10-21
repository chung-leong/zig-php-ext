<?php

echo enum_exists("ConstEnum") ? "exists" : "missing", "\n";
echo "hello = ", ConstEnum::hello, "\n";
echo "world = ", ConstEnum::world, "\n";
echo "alpha = ", ConstType::alpha, "\n";
echo "beta = ", ConstType::beta, "\n";
echo "gamma = ", ConstType::gamma, "\n";
