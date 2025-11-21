<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use App\Services\CarrierImportService;

class CarriersImportController extends Controller
{
    
    public function __construct()
    {
        $this->middleware(['auth', 'admin']);
    }

/**
     * POST /carriers/import
     */
    public function run(Request $request, CarrierImportService $svc)
    {
        $data = $request->validate([
            'source'         => 'required|in:auto,itu,local',
            'fresh'          => 'nullable|boolean',
            'fresh_confirm'  => 'required_if:fresh,1|nullable',
        ], [
            'fresh_confirm.required_if' => 'You must confirm the clearing step when "fresh" is selected.',
        ]);

        $source = $data['source'] ?? 'auto';
        $fresh  = (bool)($data['fresh'] ?? false);

        // 60s lock to avoid double-trigger / concurrent imports
        $lock = Cache::lock('carriers:import:lock', 60);
        if (!$lock->get()) {
            return back()->with('error', 'An import is already running or was triggered in the last 60 seconds.');
        }

        try {
            $res = $svc->import($source, $fresh);
        } catch (\Throwable $e) {
            $lock->release();
            return back()->with('error', 'Import failed: '.$e->getMessage());
        } finally {
            // In case service threw after partial work, ensure lock is released
            optional($lock)->release();
        }

        // Normalize summary payload for the view
        $summary = [
            'ok' => (bool)($res['ok'] ?? false),
            'msg' => (string)($res['msg'] ?? ''),
            'createdCountries' => (int)($res['createdCountries'] ?? 0),
            'createdNetworks'  => (int)($res['createdNetworks'] ?? 0),
            'createdMncs'      => (int)($res['createdMncs'] ?? 0),
            'source' => $source,
            'fresh'  => $fresh,
        ];

        if (!$summary['ok']) {
            return back()->with('error', $summary['msg'] ?: 'Import completed with issues.')->with('summary', $summary);
        }

        return back()->with('status', 'Import completed successfully.')->with('summary', $summary);
    }
}
