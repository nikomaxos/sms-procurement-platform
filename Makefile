SHELL := /bin/bash

up:
	docker compose up -d --build

stop:
	docker compose stop

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

sh:
	docker compose exec app bash

composer-install:
	docker compose run --rm app composer install --no-interaction --prefer-dist

key:
	docker compose exec app php artisan key:generate --force

migrate:
	docker compose exec app php artisan migrate --force

seed:
	docker compose exec app php artisan db:seed --force

fresh:
	docker compose exec app php artisan migrate:fresh --seed --force

assets:
	docker compose run --rm node "npm ci && npm run build"

init: up composer-install key migrate seed assets
