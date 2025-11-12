<?php
namespace App\Http\Controllers;

use App\Models\User;

class UserManagementController extends Controller {
    public function __construct(){ $this->middleware('auth'); }
    public function index(){
        $users = User::query()->select(['id','name','email','created_at'])->orderBy('id')->paginate(20);
        return view('settings.users.index', compact('users'));
    }
}
