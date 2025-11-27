#!/usr/bin/env bash
set -e
cd ~/sms-procurement-platform

BACKUP_DIR="backup_offers_move_create_button_$(date +%F_%H-%M-%S)"
mkdir -p "$BACKUP_DIR/resources/views/offers"
cp resources/views/offers/index.blade.php "$BACKUP_DIR/resources/views/offers/" || true

echo "==> Update header slot (remove top-right Create Offer button)"
perl -0pi -e 's#<x-slot name="header">.*?</x-slot>#<x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">
            Offers
        </h2>
    </x-slot>#s' resources/views/offers/index.blade.php

echo "==> Add Create Offer button inside results card (top-right)"
perl -0pi -e 's#({{-- Results table --}}\s*<div class="bg-white p-4 rounded-lg shadow">)#$1
            <div class="flex justify-end mb-3">
                <a href="{{ route('\''offers.create'\'') }}" class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm bg-white text-gray-800 hover:bg-gray-50">
                    Create Offer
                </a>
            </div>#s' resources/views/offers/index.blade.php

echo "==> Done. Backup at $BACKUP_DIR"
