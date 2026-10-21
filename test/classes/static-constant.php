<?php

echo "number = ", WithStatic::NUMBER, "\n";
echo "text = ", WithStatic::TEXT, "\n";
echo "array = ";
print_r(WithStatic::ARRAY);

use WithStatic\Enum;
use WithStatic\Flag;

echo "Enum = ", WithStatic::Enum, "\n";
echo "cat = ", WithStatic::Enum::cat, "\n";
echo "dog = ", WithStatic::Enum::dog, "\n";
echo "dog = ", Enum::dog, "\n";
echo "Flag = ", WithStatic::Flag, "\n";
echo "pork = ", Flag::pork, "\n";
