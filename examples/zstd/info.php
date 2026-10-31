<?php

header('Content-Encoding: zstd');
ob_start(function($data) {
    return zstd\compress($data);
});
phpinfo();
ob_end_flush();
