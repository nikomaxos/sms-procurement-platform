<?php
$K = 'app/Http/Kernel.php';
$c = file_get_contents($K);
if ($c === false) { fwrite(STDERR, "Cannot read $K\n"); exit(1); }

if (!preg_match('/use\s+App\\\\Http\\\\Middleware\\\\AdminOnly;/', $c)) {
    $c = preg_replace('/^namespace\s+App\\\\Http\\\\;/m', "namespace App\\Http;\n\nuse App\\Http\\Middleware\\AdminOnly;", $c, 1);
}

// Laravel 10/11+: $middlewareAliases ; older: $routeMiddleware
if (preg_match('/\$middlewareAliases\s*=\s*\[/', $c)) {
    if (!preg_match('/[\'"]admin[\'"]\s*=>\s*AdminOnly::class/', $c)) {
        $c = preg_replace('/(\$middlewareAliases\s*=\s*\[[^\]]*)/s', "$1\n        'admin' => AdminOnly::class,", $c, 1);
    }
} elseif (preg_match('/\$routeMiddleware\s*=\s*\[/', $c)) {
    if (!preg_match('/[\'"]admin[\'"]\s*=>\s*AdminOnly::class/', $c)) {
        $c = preg_replace('/(\$routeMiddleware\s*=\s*\[[^\]]*)/s', "$1\n        'admin' => AdminOnly::class,", $c, 1);
    }
} else {
    // No array found; create $middlewareAliases
    $c = preg_replace('/class\s+Kernel\s+extends\s+HttpKernel\s*\{/', "class Kernel extends HttpKernel {\n    protected \$middlewareAliases = [\n        'admin' => AdminOnly::class,\n    ];", $c, 1);
}

file_put_contents($K, $c);
