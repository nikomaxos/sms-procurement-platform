<?php

$file = __DIR__ . '/../app/Http/Controllers/NetworksController.php';

$code = file_get_contents($file);
if ($code === false) {
    fwrite(STDERR, "Cannot read $file\n");
    exit(1);
}

// Ensure Str is imported
if (strpos($code, 'use Illuminate\\Support\\Str;') === false) {
    $code = str_replace(
        "use Illuminate\\Http\\Request;\n",
        "use Illuminate\\Http\\Request;\nuse Illuminate\\Support\\Str;\n",
        $code,
        $count
    );

    if (empty($count)) {
        // Fallback: inject Str after namespace if the Request use-line pattern didn't match
        $code = preg_replace(
            '/^namespace App\\\\Http\\\\Controllers;\\s*$/m',
            "namespace App\\Http\\Controllers;\n\nuse Illuminate\\Support\\Str;",
            $code,
            1
        );
    }
}

$pattern = '/public function update\\s*\\(\\s*Request \\$request\\s*,\\s*Network \\$network\\s*\\)\\s*(?::[^{]+)?\\s*\\{.*?^\\}/ms';

$replacement = <<<'PHPFUNC'
public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'country_id' => ['nullable', 'integer', 'exists:countries,id'],
        ]);

        $network->name       = $data['name'];
        $network->lower_name = Str::lower($data['name']);
        $network->country_id = $data['country_id'] ?? null;
        $network->save();

        return redirect()
            ->route('networks.edit', $network)
            ->with('success', 'Network updated successfully.');
    }
PHPFUNC;

$new = preg_replace($pattern, $replacement, $code, 1, $count);
if ($new === null) {
    fwrite(STDERR, "preg_replace failed\n");
    exit(1);
}
if ($count === 0) {
    fwrite(STDERR, "No update() method replaced\n");
    exit(1);
}

file_put_contents($file, $new);
echo "Patched NetworksController::update()\n";
