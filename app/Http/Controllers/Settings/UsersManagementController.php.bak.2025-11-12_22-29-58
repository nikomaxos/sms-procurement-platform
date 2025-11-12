<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UsersManagementController extends Controller
{
    public function __construct() {
        $this->middleware('auth');
        $this->middleware(function ($request, $next) {
            $u = $request->user();
            if (!($u && $u->role === 'admin')) {
                // Redirect to Settings (silent deny; no 403 page)
                return redirect()->route('dashboard')->with('status', 'not-authorized');
            }
            return $next($request);
        });
    }

    public function index() {
        $users = User::orderByDesc('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }

    public function create() {
        return view('settings.users.create');
    }

    public function store(Request $request) {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'email' => ['required','email','max:255','unique:users,email'],
            'role' => ['required', Rule::in(['admin','standard'])],
            'password' => ['required','confirmed', Password::defaults()],
        ]);
        $user = new User();
        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->role = $data['role'];
        $user->password = Hash::make($data['password']);
        $user->save();
        return redirect()->route('settings.users.index')->with('status', 'user-created');
    }

    public function edit(User $user) {
        return view('settings.users.edit', compact('user'));
    }

    public function update(Request $request, User $user) {
        $data = $request->validate([
            'name' => ['required','string','max:255'],
            'email' => ['required','email','max:255', Rule::unique('users','email')->ignore($user->id)],
            'role' => ['required', Rule::in(['admin','standard'])],
            'password' => ['nullable','confirmed', Password::defaults()],
        ]);
        $user->name = $data['name'];
        $user->email = $data['email'];
        $user->role = $data['role'];
        if (!empty($data['password'])) {
            $user->password = Hash::make($data['password']);
        }
        $user->save();
        return redirect()->route('settings.users.index')->with('status', 'user-updated');
    }

    public function destroy(Request $request, User $user) {
        if ($request->user()->id === $user->id) {
            return back()->withErrors(['delete' => "You can't delete your own account while logged in."]);
        }
        $user->delete();
        return redirect()->route('settings.users.index')->with('status', 'user-deleted');
    }
}
