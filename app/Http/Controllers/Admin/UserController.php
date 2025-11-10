<?php
namespace App\Http\Controllers\Admin;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function __construct(){
        $this->middleware(['auth','can:admin']);
    }

    public function index(){
        $users = User::orderBy('id','asc')->paginate(20);
        return view('admin.users.index', compact('users'));
    }

    public function create(){ return view('admin.users.create'); }

    public function store(Request $request){
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6|confirmed',
            'is_admin' => 'sometimes|boolean',
        ]);
        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'is_admin' => (bool)($data['is_admin'] ?? false),
        ]);
        return redirect()->route('admin.users.index')->with('status','User created');
    }

    public function edit(User $user){ return view('admin.users.edit', compact('user')); }

    public function update(Request $request, User $user){
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required','email', Rule::unique('users','email')->ignore($user->id)],
            'password' => 'nullable|string|min:6|confirmed',
            'is_admin' => 'sometimes|boolean',
        ]);
        $user->name = $data['name'];
        $user->email = $data['email'];
        if (!empty($data['password'])) { $user->password = Hash::make($data['password']); }
        $user->is_admin = (bool)($data['is_admin'] ?? false);
        $user->save();
        return redirect()->route('admin.users.index')->with('status','User updated');
    }

    public function destroy(User $user){
        if (auth()->id() === $user->id) { return back()->with('status','Cannot delete yourself'); }
        $user->delete();
        return redirect()->route('admin.users.index')->with('status','User deleted');
    }
}
