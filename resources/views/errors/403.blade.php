@extends('layouts.app')

@section('content')
  <div class="max-w-xl mx-auto mt-16 bg-white border rounded-lg p-6">
    <h1 class="text-2xl font-semibold text-gray-800 mb-2">403 — Δεν έχετε δικαίωμα πρόσβασης</h1>
    <p class="text-gray-600 mb-6">
      Δεν έχετε πρόσβαση στη διαχείριση χρηστών. Αν χρειάζεστε δικαιώματα διαχειριστή, επικοινωνήστε με τον υπεύθυνο του συστήματος.
    </p>
    <a href="{{ route('dashboard') }}"
       class="inline-block px-4 py-2 rounded bg-blue-600 text-white hover:bg-blue-700">
      Επιστροφή στις Ρυθμίσεις
    </a>
  </div>
@endsection
