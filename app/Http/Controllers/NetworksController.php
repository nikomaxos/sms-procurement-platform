<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use App\Models\Network;
use App\Models\NetworkMnc;
use App\Models\NetworkMeta;
use App\Models\Country;

class NetworksController extends Controller
{
    /**
     * List networks (actual query is in the Blade view).
     */
    public function index(Request $request)
    {
        return view('networks.index');
    }

    /**
     * Show create form.
     */
    public function create()
    {
        $countries = Country::orderBy('name')->get();

        return view('networks.create', [
            'countries' => $countries,
        ]);
    }

    /**
     * Store new network.
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'country_id' => ['nullable', 'integer', 'exists:countries,id'],
        ]);

        $network = new Network();
        $network->name       = $data['name'];
        $network->lower_name = Str::lower($data['name']);
        $network->country_id = $data['country_id'] ?? null;
        $network->save();

        if (class_exists(NetworkMeta::class) && method_exists($network, 'meta')) {
            if (!$network->meta) {
                $network->meta()->create([
                    'non_operational' => false,
                    'notes'           => null,
                ]);
            }
        }

        return redirect()
            ->route('networks.edit', $network)
            ->with('status', "Network '{$network->name}' created successfully.");
    }

    /**
     * Edit form.
     */
    public function edit(Network $network)
    {
        $network->load([
            'mncs',
            'meta',
            'country.mccs',
        ]);

        $countries = Country::orderBy('name')->get();

        return view('networks.edit', [
            'network'   => $network,
            'countries' => $countries,
        ]);
    }

    /**
     * Update existing network.
     */
    public function update(Request $request, Network $network)
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'country_id' => ['nullable', 'integer', 'exists:countries,id'],
            'notes'      => ['nullable', 'string'],
            'mncs'       => ['nullable', 'array'],
            'mncs.*.mcc' => ['nullable', 'string'],
            'mncs.*.mnc' => ['nullable', 'string', 'regex:/^[0-9]{2,3}$/'],
        ]);

        $network->name       = $data['name'];
        $network->lower_name = Str::lower($data['name']);
        $network->country_id = $data['country_id'] ?? null;
        $network->save();

        // Meta
        if (method_exists($network, 'meta')) {
            $meta = $network->meta;
            if (!$meta && class_exists(NetworkMeta::class)) {
                $meta = new NetworkMeta();
                $meta->network_id = $network->id;
            }

            if ($meta) {
                $meta->non_operational = $request->boolean('non_operational');
                $meta->notes            = $data['notes'] ?? null;
                $meta->save();
            }
        }

        // MNCs
        $mncsInput = $data['mncs'] ?? [];
        $clean = [];

        foreach ($mncsInput as $row) {
            $mcc = isset($row['mcc']) ? trim((string) $row['mcc']) : '';
            $mnc = isset($row['mnc']) ? trim((string) $row['mnc']) : '';

            if ($mcc === '' && $mnc === '') {
                continue;
            }
            if ($mnc === '') {
                continue;
            }

            $clean[] = [
                'mcc' => (int) $mcc,
                'mnc' => (int) $mnc,
            ];
        }

        if (method_exists($network, 'mncs')) {
            $network->mncs()->delete();

            foreach ($clean as $pair) {
                NetworkMnc::create([
                    'network_id' => $network->id,
                    'mcc'        => $pair['mcc'],
                    'mnc'        => $pair['mnc'],
                ]);
            }
        }

        return redirect()
            ->route('networks.edit', $network)
            ->with('status', "Network '{$network->name}' updated successfully.");
    }

    /**
     * Delete network (with mncs + meta).
     */
    public function destroy(Network $network)
    {
        $network->load(['mncs', 'meta']);

        if (method_exists($network, 'mncs')) {
            $network->mncs()->delete();
        }

        if (method_exists($network, 'meta') && $network->meta) {
            $network->meta()->delete();
        }

        $name = $network->name;
        $network->delete();

        return redirect()
            ->route('networks.index')
            ->with('status', "Network '{$name}' deleted successfully.");
    }
}
