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
     * Display the networks index page.
     *
     * The heavy query/filters live in resources/views/networks/index.blade.php
     * so we just render the view here.
     */
    public function index(Request $request)
    {
        return view('networks.index');
    }

    /**
     * Show the form for creating a new network.
     */
    public function create()
    {
        $countries = Country::orderBy('name')->get();

        return view('networks.create', [
            'countries' => $countries,
        ]);
    }

    /**
     * Store a newly created network in storage.
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

        // Initialize meta row if relation/model exists [Inference]
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
     * Show the form for editing the specified network.
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
     * Update the specified network in storage.
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

            // Skip empty rows
            if ($mcc === '' && $mnc === '') {
                continue;
            }

            // Require a valid MNC (validation already did format check)
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
     * Remove the specified network from storage.
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
