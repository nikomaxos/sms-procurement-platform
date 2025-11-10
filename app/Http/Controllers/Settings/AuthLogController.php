<?php
namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\AuthLog;

class AuthLogController extends Controller
{
    public function index()
    {
        $logs = AuthLog::with('user')->latest()->paginate(50);
        return view('settings.logs.index', compact('logs'));
    }
}
