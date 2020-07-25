##
## Note:
## Hasura commands require the flag --admin-secret defined in the .env file
## or via the flag in the command itself.
##

# Main commands
# ----------------------------------------------------------------
install:
	$(MAKE) install_node_modules
	$(MAKE) up
	$(MAKE) hasura-restore
	$(MAKE) serve

serve:
	$(MAKE) up
	cd client && yarn serve


# Node modules
# ----------------------------------------------------------------
install_node_modules:
	cd hasura && yarn
	cd client && yarn
	cd auth-server && yarn

# Docker compose
# ----------------------------------------------------------------
up:
	docker-compose up -d
	sleep 3 # wait for the volumens and the container to be created

stop:
	docker-compose down

# remove docker volume for postgress => Warning, The DB data will be deleted.
remove-volume:
	docker volume rm nuxt-apollo-hasura_hasura_db_data


# Hasura
# ----------------------------------------------------------------
status:
	cd hasura && npx hasura migrate status

# Experimental Preview
# Squash multiple migrations into a single one
hasura-squash:
	cd hasura && npx hasura migrate squash --from <verion_number>

hasura-dump:
	# Hasura metadata and migrations come from the hasura-console files generation
	docker exec postgres-container pg_dump --column-inserts --data-only -U postgres postgres > db/dev_inserts.dump.sql
	docker exec postgres-container pg_dumpall --clean -U postgres > db/dev.dumpall.sql
	#	curl -d '{"type" : "export_metadata","args": {}}' -H "x-hasura-admin-secret: adminpassword" -H "X-Hasura-Role: admin" http://localhost:4000/v1/query > ./hasura/schema.json

hasura-restore:
	# The order is very important!
	$(MAKE) hasura-apply-metadata
	$(MAKE) hasura-apply-migrations
	cat inserts.dump.sql | docker exec -i postgres-container psql -U postgres -d postgres < db/inserts.dump.sql

hasura-apply-metadata:
	cd hasura && npx hasura migrate apply  --admin-secret adminpassword # --endpoint http://another-graphql-instance.herokuapp.com

hasura-apply-migrations:
	cd hasura && npx hasura metadata apply --admin-secret adminpassword
