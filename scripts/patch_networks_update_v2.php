<?php

$file = __DIR__ . '/../app/Http/Controllers/NetworksController.php';

$code = file_get_contents($file);
if ($code === false) {
    fwrite(STDERR, "Cannot read $file\n");
    exit(1);
}

// Ensure Str is imported
if (strpos($code, 'use Illuminate\\Support\\Str;') === false) {
    $code = preg_replace(
        '/^namespace App\\\\Http\\\\Controllers;\\s*$/m',
        "namespace App\\Http\\Controllers;\n\nuse Illuminate\\Support\\Str;",
        $code,
        1,
        $nsCount
    );

    if (empty($nsCount)) {
        fwrite(STDERR, "Could not inject use Illuminate\\Support\\Str; into NetworksController.php\n");
        exit(1);
    }
}

$pattern = '/public function update\\s*\\(\\s*Request\\s+\\$request\\s*,\\s*Network\\s+\\$network\\s*\\)\\s*(?::[^{]+)?\\s*\\{.*?^\\s*\\}/ms';

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

        // IMPORTANT: Do NOT touch MCC/MNC assignments here.
        // They are managed via dedicated flows (imports, separate screens, etc).
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
    fwrite(STDERR, "Did not find existing update() method to replace\n");
    exit(1);
}

file_put_contents($file, $new);
echo "Patched NetworksController::update()\n";
