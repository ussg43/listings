MIGRATIONS_PATH = ./cmd/migrations/migrate
DB_MIGRATION_ADDR ?= $(DB_CONNECTION)

.PHONY: migration migrate-up migrate-down migrate-force

migration:
	@migrate create -seq -ext sql -dir $(MIGRATIONS_PATH) $(filter-out $@,$(MAKECMDGOALS))

migrate-up:
	@test -n "$(DB_MIGRATION_ADDR)" || (echo "DB_CONNECTION or DB_MIGRATION_ADDR is required" && exit 1)
	@migrate -path=$(MIGRATIONS_PATH) -database="$(DB_MIGRATION_ADDR)" up

migrate-down:
	@test -n "$(DB_MIGRATION_ADDR)" || (echo "DB_CONNECTION or DB_MIGRATION_ADDR is required" && exit 1)
	@migrate -path=$(MIGRATIONS_PATH) -database="$(DB_MIGRATION_ADDR)" down $(filter-out $@,$(MAKECMDGOALS))

migrate-force:
	@test -n "$(DB_MIGRATION_ADDR)" || (echo "DB_CONNECTION or DB_MIGRATION_ADDR is required" && exit 1)
	@migrate -path=$(MIGRATIONS_PATH) -database="$(DB_MIGRATION_ADDR)" force 1

%:
	@:
