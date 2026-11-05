<?php

EnumWithMethod::cat->hello();
EnumWithMethod::bear->hello();
EnumWithMethod::hello();
EnumWithMethod::hello();
EnumWithMethod::hello();
print_r(EnumWithMethod::cases());
print_r(EnumWithMethod::from(1));