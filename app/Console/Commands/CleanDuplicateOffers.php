<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\SupplierOffer;
use App\Models\SupplierOfferHistory;

class CleanDuplicateOffers extends Command
{
    protected $signature = 'app:clean-duplicate-offers';
    protected $description = 'Clean up old duplicate supplier offers by moving them to history';

    public function handle()
    {
        $offers = SupplierOffer::all();
        $grouped = $offers->groupBy(function ($o) {
            return $o->supplier_id . '_' .
                $o->supplier_connection_id . '_' .
                $o->country_id . '_' .
                $o->network_id . '_' .
                $o->network_mnc_id . '_' .
                $o->product_type_id . '_' .
                $o->route_type_id;
        });

        $count = 0;
        foreach ($grouped as $group) {
            if ($group->count() > 1) {
                // Keep the latest one based on updated_at or id
                $latest = $group->sortByDesc('id')->first();

                foreach ($group as $offer) {
                    if ($offer->id !== $latest->id) {
                        // Move to history
                        SupplierOfferHistory::create([
                            'supplier_offer_id' => $latest->id,
                            'supplier_id' => $offer->supplier_id,
                            'supplier_connection_id' => $offer->supplier_connection_id,
                            'country_id' => $offer->country_id,
                            'network_id' => $offer->network_id,
                            'network_mnc_id' => $offer->network_mnc_id,
                            'price' => $offer->price,
                            'mcc' => $offer->mcc,
                            'mnc' => $offer->mnc,
                            'mcc_mnc' => $offer->mcc_mnc,
                            'product_type' => $offer->product_type,
                            'known_hops' => $offer->knownHopsDropdownItem ? $offer->knownHopsDropdownItem->label : null,
                            'sender_id_supported' => $offer->senderIdSupportedDropdownItem ? $offer->senderIdSupportedDropdownItem->label : null,
                            'charge_type' => $offer->charge_type,
                            'is_exclusive' => $offer->is_exclusive,
                            'route_type' => $offer->route_type_id,
                            'effective_date' => $offer->effective_date,
                            'created_at' => $offer->created_at,
                            'updated_at' => $offer->updated_at,
                        ]);
                        $offer->delete();
                        $count++;
                    }
                }
            }
        }
        $this->info("Moved $count duplicate offers to history.");
    }
}
