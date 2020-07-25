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
	docker exec postgres-container pg_dump -U postgres postgres > db/dev.dump.sql
	docker exec postgres-container pg_dumpall --clean -U postgres > db/dev.dumpall.sql
	curl -d '{"type" : "export_metadata","args": {"reload_remote_schemas": true}}' -H "x-hasura-admin-secret: adminpassword" -H "X-Hasura-Role: admin" http://localhost:4000/v1/query > ./db/hasura_schema.json
	# Format file
	cd client && npx prettier --write ../db/hasura_schema.json

# RESTORE
# copy data in the database and then apply the hasura metadata (the file is minified in one line)
# ----------------------------------------------------------------
FILE=db/hasura_schema.json
SCHEMA=`cd client && npx json-minify ../$(FILE)`
hasura-restore:
	# The order is very important!
	#$(MAKE) hasura-apply-metadata
	#$(MAKE) hasura-apply-migrations
#	cat db/dev_inserts.dump.sql | docker exec -i postgres-container psql -U postgres -d postgres < db/dev_inserts.dump.sql
#	cat db/dev.dumpall.sql | docker exec -i postgres-container psql -U postgres -d postgres < db/dev.dumpall.sql
	cat db/dev.dump.sql | docker exec -i postgres-container psql -U postgres -d postgres < db/dev.dump.sql
	#curl --header "x-hasura-admin-secret: adminpassword" --data '{"type":"replace_metadata", "args":'$(cat ./hasura/schema.json)'}' http://localhost:4000/v1/query
	curl -d '{"type":"replace_metadata", "args":'$(SCHEMA)'}' -H "x-hasura-admin-secret: adminpassword" -H "X-Hasura-Role: admin" http://localhost:4000/v1/query


hasura-restore-full:
	cat db/dev.dumpall.sql | docker exec -i postgres-container psql -U postgres -d postgres < db/dev.dumpall.sql

hasura-apply-metadata:
	cd hasura && npx hasura migrate apply  --admin-secret adminpassword # --endpoint http://another-graphql-instance.herokuapp.com

hasura-apply-migrations:
	cd hasura && npx hasura metadata apply --admin-secret adminpassword
