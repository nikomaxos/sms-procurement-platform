<?php
namespace App\Http\Controllers\Settings;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index() {
        $users = User::orderBy('id','desc')->paginate(20);
        return view('settings.users.index', compact('users'));
    }
    public function create() { return view('settings.users.create'); }
    public function store() {
        $data = request()->validate([
            'name'     => ['required','string','max:255'],
            'email'    => ['required','email','max:255', Rule::unique('users','email')],
            'password' => ['nullable','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        User::create($data); // UserObserver hashes / defaults password
        return redirect()->route('settings.users.index')->with('status','User created');
    }
    public function edit(User $user) { return view('settings.users.edit', compact('user')); }
    public function update(User $user) {
        $data = request()->validate([
            'name'     => ['required','string','max:255'],
            'email'    => ['required','email','max:255', Rule::unique('users','email')->ignore($user->id)],
            'password' => ['nullable','string','min:8'],
            'is_admin' => ['nullable','boolean'],
        ]);
        if(empty($data['password'])) unset($data['password']);
        $data['is_admin'] = (bool)($data['is_admin'] ?? false);
        $user->update($data);
        return redirect()->route('settings.users.index')->with('status','User updated');
    }
    public function destroy(User $user) {
        $user->delete();
        return back()->with('status','User deleted');
    }
}
