<?php

use PhpSchool\CliMenu\CliMenu;
use PhpSchool\CliMenu\Builder\CliMenuBuilder;
use PhpSchool\CliMenu\MenuItem\CheckboxItem;
use PhpSchool\CliMenu\MenuItem\RadioItem;
use PhpZip\ZipFile;

error_reporting(E_ALL ^ E_DEPRECATED);
require_once(__DIR__ . '/vendor/autoload.php');

define('BACKGROUND_COLOR', [ 220, 'yellow' ]);
define('FOREGROUND_COLOR', [ 0, 'black' ]);

class Meta {
    var $ext_name;
    var $ext_version;
    var $zig_config;

    function __construct() {
        $json = file_get_contents(__DIR__ . "/composer.json");
        $composer = json_decode($json);
        $this->ext_name = preg_replace("/.*?\//", "", $composer->name);
        $this->ext_version = $composer->version;
        $this->zig_config = isset($composer->zig->config) ? $composer->zig->config : null;
    }

    function getDefaultConfig() {
        if ($this->zig_config) {
            $config = new stdclass;
            foreach ($this->zig_config as $name => $item) {
                $default_value = $item->default;
                if (isset($item->type)) {
                    // make sure float values are floats when default values are whole
                    switch ($item->type) {
                        case 'f16':
                        case 'f32':
                        case 'f64': 
                            $default_value = (float) $default_value;
                            break;
                    }
                }
                $config->$name = $default_value;
            }
            return $config;
        }
    }
}

class Settings {
    var $versions;
    var $targets;
    var $debug;
    var $optimize;
    var $zig_config;

    function __construct() {
        global $meta;
        $this->zig_config = $meta->getDefaultConfig();
        $this->ini_path = join(DIRECTORY_SEPARATOR, [ __DIR__, 'build.ini' ]);
        if (file_exists($this->ini_path)) {
            $this->load();
        } else {
            $current_version = substr(PHP_VERSION, 0, strrpos(PHP_VERSION, '.'));
            switch (PHP_OS_FAMILY) {
                case 'Windows': $platform = 'windows'; break;
                case 'Darwin': $platform = 'macos'; break;
                case 'Linux': $platform = 'linux-gnu'; break;
            }
            switch (php_uname("m")) {
                case 'x86': $arch = 'x86'; break;
                case 'x86_64': $arch = 'x86_64'; break;
                case 'arm64':
                case 'aarch64': $arch = 'aarch64'; break;
                case 'risc64': $arch = 'risc64'; break;
                default: $arch = 'x86_64';
            }
            $current_target = "$arch-$platform";
            if ($platform === 'windows') {
                if (PHP_ZTS) {
                    $current_target .= '-ts';
                }
            }
            $this->versions = [ $current_version ];
            $this->targets = [ $current_target ];
            $this->debug = PHP_DEBUG;
            $this->optimize = (PHP_DEBUG) ? 'Debug' : 'ReleaseSmall';
        }
    }

    function load() {
        $fields = parse_ini_file($this->ini_path);
        $this->versions = array_map('trim', $fields['versions'] ?? []);
        $this->debug = (bool) $fields['debug'];
        $this->targets = array_map('trim', $fields['targets'] ?? []);
        $this->optimize = trim($fields['optimize'] ?? 'ReleaseSmall');
            
        if ($this->zig_config) {
            foreach ($this->zig_config as $name => $default_value) {
                if (isset($fields[$name])) {
                    $value = $fields[$name];
                    switch (gettype($default_value)) {
                        case 'boolean': $value = !!preg_match("/^(true|on|yes|1)$/i", $value); break;
                        case 'integer': $value = (int) $value; break;
                        case 'double': $value = (float) $value; break;
                    }
                    $this->zig_config->$name = $value;
                }
            }
        }
    }

    function save() {
        $lines = [];
        $versions = [ '8.1', '8.2', '8.3', '8.4', '8.5', '8.6' ];
        foreach ($versions as $version) {
            $prefix = in_array($version, $this->versions) ? '' : '; ';
            $lines[] = $prefix . "versions[] = $version";
        }
        $lines[] = "";
        $states = [ 'on' => true, 'off' => false ];
        foreach ($states as $label => $state) {
            $prefix = ($state == $this->debug) ? '' : '; ';
            $lines[] = $prefix . "debug = $label";
        }
        $lines[] = "";
        $targets = [ 'x86_64-linux-gnu', 'aarch64-linux-gnu', 'x86_64-macos', 'aarch64-macos', 'x86_64-windows', 'x86_64-windows-ts' ];
        foreach ($targets as $target) {
            $prefix = in_array($target, $this->targets) ? '' : '; ';
            $lines[] = $prefix . "targets[] = $target";
        }
        $lines[] = "";
        $modes = [ 'Debug', 'ReleaseSafe', 'ReleaseSmall', 'ReleaseFast' ];
        foreach ($modes as $mode) {
            $prefix = ($mode == $this->optimize) ? '' : '; ';
            $lines[] = $prefix . "optimize = $mode";
        }
        $lines[] = "";
        if ($this->zig_config) {
            // save extra zig configuration
            $lines[] = "[zig]";
            foreach ($this->zig_config as $name => $value) {
                if (is_array($value)) {
                    foreach($value as $item) {
                        $lines[] = "{$name}[] = $item";
                    }
                } else {
                    if (gettype($value) === 'boolean') {
                        $value = ($value) ? 'true' : 'false';
                    }
                    $lines[] = "$name = $value";
                }
                $lines[] = "";
            }
        }
        $contents = join(PHP_EOL, $lines);
        $old_contents = @file_get_contents($this->ini_path);
        if ($contents != $old_contents or !file_exists($this->ini_path)) {
            file_put_contents($this->ini_path, $contents);
        }
    }
}

// load metadata and user settings
$meta = new Meta;
$settings = new Settings;

function updateMenuItem($title) {
    global $menu;
    $prefix = substr($title, 0, strpos($title, ": "));
    foreach ($menu->getItems() as $item) {
        if (str_starts_with($item->getText(), $prefix)) {
            $item->setText($title);
            break;
        }
    }
}

$action = $argv[1] ?? '';
switch ($action) {
    case '': 
        $build = true; 
        break;
    case 'menu': 
        $build = false;
        if (is_callable('posix_isatty') and !posix_isatty(STDIN)) {
            echo "Unable to show menu: stdin is not a TTY\n";
            exit(1);
        }
        // add standard entries to menu
        $builder = new CliMenuBuilder;
        $builder->setTitle("Build Script for php-$meta->ext_name (v{$meta->ext_version})");
        $title = "PHP version: " . implode(", ", $settings->versions);
        $builder->addSubMenu($title, function ($b) use($settings) {
            $b->setTitle("Select the version(s) of PHP for which you wish to create the extension");
            $versions = [ 
                '8.1' => "8.1.x", 
                '8.2' => "8.2.x",
                '8.3' => "8.3.x",
                '8.4' => "8.4.x", 
                '8.5' => "8.5.x",
                '8.6' => "8.6.x",
            ];
            $cb = function($menu) use($versions, $settings) {
                $item = $menu->getSelectedItem();
                $id = array_search($item->getText(), $versions);
                $op = ($item->getChecked()) ? 'array_merge' : 'array_diff';
                $settings->versions = $op($settings->versions, [ $id ]);
                sort($settings->versions);
                $title = "PHP version: " . implode(", ", $settings->versions);
                updateMenuItem($title);
            };
            foreach ($versions as $id => $label) {
                $item = new CheckboxItem($label, $cb, false, false);
                if (in_array($id, $settings->versions)) {
                    $item->setChecked();
                }
                $b->addMenuItem($item);
            }
            $b->addLineBreak('-');
        });
        $title = "PHP debug mode: " . (($settings->debug) ? 'enabled' : 'disabled');
        $builder->addSubMenu($title, function ($b) use($settings) {
            $b->setTitle("Select the debug mode of the PHP executable");
            $cb = function($menu) use($settings) {
                $item = $menu->getSelectedItem();
                $settings->debug = $item->getText() == 'Enabled';
                $title = "PHP debug mode: " . (($settings->debug) ? 'enabled' : 'disabled');
                updateMenuItem($title);
            };
            foreach ([ false, true ] as $enabled) {
                $label = $enabled ? 'Enabled' : 'Disabled';
                $item = new RadioItem($label, $cb, false, false);
                if ($settings->debug == $enabled) {
                    $item->setChecked();
                }
                $b->addMenuItem($item);
            }
            $b->addLineBreak('-');
        });
        $title = "Operation system: " . implode(", ", $settings->targets);
        $builder->addSubMenu($title, function ($b) use($settings) {
            $b->setTitle("Select the operation system(s) you wish to support");
            $targets = [
                'x86_64-linux-gnu' => "Linux x86 64-bit",
                'aarch64-linux-gnu' => "Linux ARM 64-bit",
                'x86_64-macos' => "MacOS x86 64-bit",
                'aarch64-macos' => "MacOS ARM 64-bit",
                'x86_64-windows' => "Windows x86 64-bit",
                'x86_64-windows-ts' => "Windows x86 64-bit (thread-safe)",
            ];
            $cb = function($menu) use($targets, $settings) {
                $item = $menu->getSelectedItem();
                $id = array_search($item->getText(), $targets);
                $op = ($item->getChecked()) ? 'array_merge' : 'array_diff';
                $settings->targets = $op($settings->targets, [ $id ]);
                sort($settings->targets);
                $title = "Operation system: " . implode(", ", $settings->targets);
                updateMenuItem($title);
            };
            foreach ($targets as $id => $label) {
                $item = new CheckboxItem($label, $cb, false, false);
                if (in_array($id, $settings->targets)) {
                    $item->setChecked();
                }
                $b->addMenuItem($item);
            }
            $b->addLineBreak('-');
        });
        $title = "Optimization level: " . $settings->optimize;
        $builder->addSubMenu($title, function ($b) use($settings) {
            $b->setTitle("Select the optimization level used to compile the extension");
            $levels = [ 'Debug', 'ReleaseSafe', 'ReleaseSmall', 'ReleaseFast' ];
            $cb = function($menu) use($settings) {
                $item = $menu->getSelectedItem();
                $settings->optimize = $item->getText();
                $title = "Optimization level: " . $settings->optimize;
                updateMenuItem($title);
            };
            foreach ($levels as $level) {
                $item = new RadioItem($level, $cb, false, false);
                if ($settings->optimize == $level) {
                    $item->setChecked();
                }
                $b->addMenuItem($item);
            }
            $b->addLineBreak('-');
        });
        $builder->addLineBreak('-');

        if ($settings->zig_config) {
            // add custom configuration entries to menu
            foreach ($settings->zig_config as $name => $current_value) {
                $type = gettype($current_value);
                $entry = $meta->zig_config->$name;
                if (isset($entry->choices)) {
                    if (is_array($current_value)) {
                        $title = "$entry->title: " . implode(", ", $current_value);
                        $builder->addSubMenu($title, function ($b) use($settings, $name, $entry, $current_value) {
                            $b->setTitle($entry->title);
                            foreach ($entry->choices as $item_name => $label) {
                                $cb = function($menu) use($settings, $name, $item_name, $entry) {
                                    $item = $menu->getSelectedItem();
                                    $op = ($item->getChecked()) ? 'array_merge' : 'array_diff';
                                    $new_value = $op($settings->zig_config->$name, [ $item_name ]);
                                    sort($new_value);
                                    $settings->zig_config->$name = $new_value;
                                    $title = "$entry->title: " . implode(", ", $new_value);
                                    updateMenuItem($title);
                                };
                                $item = new CheckboxItem($label, $cb, false, false);
                                if (in_array($item_name, $current_value)) {
                                    $item->setChecked();
                                }
                                $b->addMenuItem($item);
                            }
                            $b->addLineBreak('-');
                        });
                    } else {
                        $title = "$entry->title: $current_value";
                        $builder->addSubMenu($title, function ($b) use($settings, $name, $entry, $current_value) {
                            $b->setTitle($entry->title);
                            foreach ($entry->choices as $item_name => $label) {
                                $cb = function($menu) use($settings, $name, $item_name, $entry) {
                                    $item = $menu->getSelectedItem();
                                    $new_value = $item_name;
                                    $settings->zig_config->$name = $new_value;
                                    $title = "$entry->title: $new_value";
                                    updateMenuItem($title);
                                };
                                $item = new RadioItem($label, $cb, false, false);
                                if ($item_name === $current_value) {
                                    $item->setChecked();
                                }
                                $b->addMenuItem($item);
                            }
                            $b->addLineBreak('-');
                        });
                    }
                } else {
                    if ($type === 'boolean') {                
                        $title = "$entry->title: " . (($current_value) ? "true" : "false");
                        $builder->addItem($title, function ($menu) use($settings, $name, $entry, $type) {
                            $new_value = !$settings->zig_config->$name;
                            $settings->zig_config->$name = $new_value;
                            $item = $menu->getSelectedItem();
                            $item->setText("$entry->title: " . (($new_value) ? "true" : "false"));
                            $menu->redraw();
                        });
                    } else {
                        $title = "$entry->title: $current_value";
                        $builder->addItem($title, function ($menu) use($settings, $name, $entry, $type) {
                            $current_value = $settings->zig_config->$name;
                            $result = $menu->askText()
                                ->setPromptText($entry->prompt)
                                ->setPlaceholderText($current_value)
                                ->ask();
                            $new_value = $result->fetch();
                            switch (gettype($current_value)) {
                                case 'integer': $new_value = (int) $new_value; break;
                                case 'double': $new_value = (float) $new_value; break;
                            }
                            $settings->zig_config->$name = $new_value;
                            $item = $menu->getSelectedItem();
                            $item->setText("$entry->title: $new_value");
                            $menu->redraw();
                        });
                    }
                }
            }
            $builder->addLineBreak('-');
        }

        // add action items and set display properties
        $builder->addItem("Build", function($menu) use(&$build, $settings) {
            if ($settings->debug && $settings->optimize != 'Debug') {
                $flash = $menu->flash("Unable to build debug version optimized for release");
                $flash->display();
                return;
            }
            $build = true;
            $menu->close();
        });
        $builder->setMarginAuto();
        $builder->setBackgroundColour(...BACKGROUND_COLOR);
        $builder->setForegroundColour(...FOREGROUND_COLOR);
        $menu = $builder->build();   

        $menu->open();
        $settings->save();
        break;
    default:
        echo "Unknown action: $action\n";
        exit(1);
}
if (!$build) exit(0);

$results = [];
$links = [];
if ($settings->debug && $settings->optimize != 'Debug') {
    echo "Unable to build debug version at optimization level \"$settings->optimize\"\n";
    exit(1);
}
foreach ($settings->versions as $version) {
    foreach ($settings->targets as $target) {
        if (str_ends_with($target, '-ts')) {
            $target = substr($target, 0, -3);
            $ts = '/ts';
        } else {
            $ts = '';
        }
        [ $arch, $platform ] = explode('-', $target);
        $debug = ($settings->debug) ? 'with debug enabled ' : '';
        echo "Building extension at optimization level \"$settings->optimize\" for PHP $version $debug($platform/$arch$ts)\n";
        $devel_path = join(DIRECTORY_SEPARATOR, [ __DIR__, 'php-devel', $version ]);
        if (!file_exists($devel_path)) {
            if (count($links) === 0) {
                $dir_url = "https://downloads.php.net/~windows/releases/";
                $dir_contents = file_get_contents($dir_url);
                if (preg_match_all('/href="(php-devel\-pack\-(8\.\d)\.\d+-nts\-.*?\-x64\.zip)"/', $dir_contents, $matches, PREG_SET_ORDER)) {
                    foreach ($matches as $m) {
                        $links[$m[2]] = $dir_url . $m[1];
                    }
                } else {
                    echo "Unable to scan PHP download directory\n";
                    exit(1);
                }
            }
            if (!isset($links[$version])) {
                $dir_url = "https://downloads.php.net/~windows/qa/";
                $dir_contents = file_get_contents($dir_url);
                $qa_links = [];
                // https://downloads.php.net/~windows/qa/php-8.6.0beta2-nts-Win32-vs18-x64.zip                
                if (preg_match_all('/href="(php-devel\-pack\-(8\.\d)\.\d+(\w+)-nts\-.*?\-x64\.zip)"/', $dir_contents, $matches, PREG_SET_ORDER)) {
                    foreach ($matches as $m) {
                        $qa_links[$m[2]] = $dir_url . $m[1];
                    }
                }
                $links = array_merge($qa_links, $links);
            }
            $link = $links[$version];
            if (!in_array('https', stream_get_wrappers())) {
                $link = str_replace('https:', 'http:', $link);
            }
            echo "Downloading $link\n";
            $zip_contents = file_get_contents($link);
            if ($zip_contents === false) {
                echo "Unable to download PHP development package: $link\n";
                exit(1);
            }
            if (!in_array("var", stream_get_wrappers())) {
                stream_wrapper_register("var", "VariableStream");
            }
            $zip_path = "var://zip_contents";
            $zip_file = new ZipFile();
            $zip_file->openFile($zip_path);
            foreach($zip_file as $name => $contents) {
                if (str_ends_with($name, '/')) continue;
                $parts = explode('/', $name);
                $parts[0] = $devel_path;
                $dest_path = join(DIRECTORY_SEPARATOR, $parts);
                $dest_dir = dirname($dest_path);
                if (!file_exists($dest_dir)) {
                    mkdir($dest_dir, 0777, true);
                }
                if ($version <= '8.4') {
                    $src_path = join('/', array_slice($parts, 1)); 
                    switch ($src_path) {
                        case 'include/win32/ioutil.h':
                        case 'include/win32/codepage.h':
                            // correct syntax considered legal only by Microsoft Visual C
                            $contents = str_replace('__forceinline', 'zend_always_inline', $contents);
                            break;
                    }
                }
                file_put_contents($dest_path, $contents);
            }
        }
        $include_path = join(DIRECTORY_SEPARATOR, [ $devel_path, 'include' ]);
        $so_rel_parts = [ 'extensions', $version ];
        if ($arch != 'x86_64')  {
            $so_rel_parts[] = $arch;
        }
        if ($ts) {
            $so_rel_parts[] = 'TS';
        }
        $so_rel_dir = join(DIRECTORY_SEPARATOR, $so_rel_parts);
        $so_dir = join(DIRECTORY_SEPARATOR, [ $so_rel_dir ]);
        switch ($platform) {
            case 'windows': $so_ext = 'dll'; break;
            case 'macos': $so_ext = 'dylib'; break;
            default: $so_ext = 'so'; break;
        }
        $so_name = "php_{$meta->ext_name}.$so_ext";
        $so_path = join(DIRECTORY_SEPARATOR, [ $so_dir, $so_name ]);
        $cmd = [ 
            'zig',
            'build', 
            "-Dtarget=$target",
            "-Doptimize=$settings->optimize",
            "-Dphp-include=$include_path",
            "-Dphp-extension=$so_dir",
        ];
        if ($settings->debug) {
            $cmd[] = "-Dphp-debug";
        }
        if ($ts) {
            $cmd[] = "-Dphp-ts";
        }
        if ($settings->zig_config) {
            // add custom configuration
            foreach ($settings->zig_config as $name => $value) {
                if (is_array($value)) {
                    foreach ($value as $item) {
                        $cmd[] = "-D{$name}_{$item}";
                    }
                } else {
                    if (gettype($value) === 'boolean') {
                        $cmd[] = "-D{$name}";
                    } else {
                        $cmd[] = "-D{$name}={$value}";
                    }
                }
            }
        }
        if (!@unlink($so_path)) {
            // can't delete a DLL when it's still loaded in Windows
            // renaming is possible on the other hand
            @rename($so_path, $so_path . ".prev");
        }
        // workaround for XCode 26.4 incompatibility
        $env = null;
        if (PHP_OS_FAMILY == 'Darwin') {
            $env = getenv();
            $env['DEVELOPER_DIR'] = '/dev/null';
        }
        $zig = proc_open($cmd, [ STDIN, STDOUT, STDERR ], $pipes, null, $env, [
            'bypass_shell' => true,
        ]);
        if (proc_close($zig) == 0) {
            $results[] = join(DIRECTORY_SEPARATOR, [ $so_rel_dir, $so_name ]);
        }
    }
}
$count = count($results);
$libraries = ($count === 1) ? 'library' : 'libraries';
echo "Created $count dynamic-linked $libraries:\n\n";
foreach ($results as $path) {
    echo "$path\n";
}

class VariableStream {
    var $position;
    var $varname;
    var $context;

    function stream_open($path, $mode, $options, &$opened_path)
    {
        $url = parse_url($path);
        $this->varname = $url["host"];
        $this->position = 0;

        return true;
    }

    function stream_read($count)
    {
        $ret = substr($GLOBALS[$this->varname], $this->position, $count);
        $this->position += strlen($ret);
        return $ret;
    }

    function stream_write($data)
    {
        $left = substr($GLOBALS[$this->varname], 0, $this->position);
        $right = substr($GLOBALS[$this->varname], $this->position + strlen($data));
        $GLOBALS[$this->varname] = $left . $data . $right;
        $this->position += strlen($data);
        return strlen($data);
    }

    function stream_tell()
    {
        return $this->position;
    }

    function stream_eof()
    {
        return $this->position >= strlen($GLOBALS[$this->varname]);
    }

    function stream_seek($offset, $whence)
    {
        switch ($whence) {
            case SEEK_SET:
                if ($offset < strlen($GLOBALS[$this->varname]) && $offset >= 0) {
                     $this->position = $offset;
                     return true;
                } else {
                     return false;
                }
                break;

            case SEEK_CUR:
                if ($offset >= 0) {
                     $this->position += $offset;
                     return true;
                } else {
                     return false;
                }
                break;

            case SEEK_END:
                if (strlen($GLOBALS[$this->varname]) + $offset >= 0) {
                     $this->position = strlen($GLOBALS[$this->varname]) + $offset;
                     return true;
                } else {
                     return false;
                }
                break;

            default:
                return false;
        }
    }

    function stream_stat()
    {
        return [ 'size' => strlen($GLOBALS[$this->varname]) ];
    }

    function stream_metadata($path, $option, $var) 
    {
        if($option == STREAM_META_TOUCH) {
            $url = parse_url($path);
            $varname = $url["host"];
            if(!isset($GLOBALS[$varname])) {
                $GLOBALS[$varname] = '';
            }
            return true;
        }
        return false;
    }

    function url_stat($path, $flags)
    {
        $url = parse_url($path);
        $varname = $url["host"];
        if (!isset($GLOBALS[$varname])) return false;
        return [ 'size' => strlen($GLOBALS[$varname]) ];
    }
}
