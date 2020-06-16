# fhirbase-plv8

[![Build Status](https://travis-ci.org/fhirbase/fhirbase-plv8.svg)](https://travis-ci.org/fhirbase/fhirbase-plv8)

## Features

This is new version of fhirbase, with support of DSTU-2 and planned support many advanced features:

*  Extended query syntax
*  Terminologies
*  Profile validation
*  References validation
*  ValueSet validation

## Motivation

While crafting Health IT systems we understand an importance of a
properly chosen domain model. FHIR is an open source new generation
lightweight standard for health data interoperability, which (we hope)
could be used as a foundation for Health IT systems. FHIR is based
on a concept of __resource__.

> FHIR® is a next generation standards framework created by HL7.  FHIR
> combines the best features of HL7 Version 2, Version 3 and CDA®
> product lines while leveraging the latest web standards and applying
> a tight focus on implementability.

We also learned that data is a heart of any information system, and
should be reliably managed. PostgreSQL is a battle proven open source
database which supports structured documents (jsonb) while
preserving ACID guaranties and richness of SQL query language.

> PostgreSQL is a powerful, open source object-relational database
> system.  It has more than 15 years of active development and a
> proven architecture that has earned it a strong reputation for
> reliability, data integrity, and correctness.

Here is the list of PostgreSQL features that we use:

* [plv8](http://pgxn.org/dist/plv8/doc/plv8.html)
* [jsonb](http://www.postgresql.org/docs/9.4/static/functions-json.html)
* [gin & gist](http://www.postgresql.org/docs/9.1/static/textsearch-indexes.html)
* [inheritance](http://www.postgresql.org/docs/9.4/static/tutorial-inheritance.html)


## Installation

To install fhirbase you need postgresql-9.4 and plv8 extension.

```sh
sudo apt-get install postgresql-contrib-9.4 postgresql-9.4-plv8  -qq -y
psql -c "CREATE USER \"user\" WITH PASSWORD 'password'"
psql -c 'CREATE DATABASE fhirbase;' -U user
psql -c '\dt' -U postgres
export DATABASE_URL=postgres://user:password@localhost:5432/fhirbase

wget https://github.com/fhirbase/fhirbase-plv8/releases/download/v<version of the fhirbase>/fhirbase-<version of the fhirbase>.sql.zip
unzip fhirbase-<version of the fhirbase>.sql.zip

cat fhirbase-<version of the fhirbase>.sql | psql fhirbase
```

## Upgrade

```sh
export DATABASE_URL=postgres://user:password@localhost:5432/fhirbase

wget https://github.com/fhirbase/fhirbase-plv8/releases/download/v<version of the fhirbase>/fhirbase-<version of the fhirbase>-patch.sql.zip
unzip fhirbase-<version of the fhirbase>-patch.sql.zip

cat fhirbase-<version of the fhirbase>-patch.sql | psql fhirbase
```

## Kainos development and update process

You will need to make changes to the fhirbase code from time to time. Here is how you should perform update process.

The original "Development Installation" chapter mentions that you should have node v6.2.0, however, it was tested that the installation process is successful on newer node versions (e.g. v12.18.0).

1. Clone the repository and initialise its submodules:
    ```shell script
    git clone https://github.com/fhirbase/fhirbase-plv8
    cd fhirbase-plv8
    git submodule init && git submodule update
    ```
2. Install dependencies:
    ```shell script
    cd plpl && npm install && cd .. && npm install
    npm install -g mocha && npm install -g coffee-script
    ```
3. Implement required changes in the fhirbase coffee scripts and commit them.
4. Run the script `./build-commit.sh`. The script compiles the Coffee scripts and generates a bunch of SQL files from them in the `build/current-commit-hash` directory. The one that is the most interesting for us is the `code.sql`.
5. The `code.sql` script contains some unnecessary comments and expressions creating modules using an your local absolute path where the repository is cloned, e.g. `_modules["/Users/bartlomiejs/work/fhirbase-plv8/src/core"]`. To clear the SQL file adjust and run the following command:
    ```shell script
    cat code.sql \
        | sed "s/\/Users\/bartlomiejs\/work//g" \
        | sed "/\/\/# sourceMappingURL.*/d" \
        | sed "/\/\/# sourceURL.*/d" \
        >> clean-code.sql
    ```
6. Copy the block of code that recreates `plv8_init` function
    ```sql
    CREATE OR REPLACE FUNCTION plv8_init() RETURNS text AS $JAVASCRIPT$
    --
    -- Code goes here
    --
    $JAVASCRIPT$ LANGUAGE plv8 IMMUTABLE STRICT;
    ```
    and place it as the new migration file (e.g. `V15_0_0__recreate_plv8init_with_fhir_extract_as_string_array_method_added.sql`) in the `fhir-service/db/schema/public` directory.
7. Check the diff between the new migration file and the previous one updating `plv8_init` function and validate if all changes you applied in the coffee scripts have the corresponding code in the new migration.
8. If everything is correct copy the migration file to the tenant migrations directory `fhir-service/db/schema/tenant`. Make sure you update the version number (`V15_0_0` part) so that it is the latest tenant migration version.
9. If you have added a new coffee script function or updated the name of already existing one you should add a migration that creates a Postgresql function in both public and tenant schemas.
   - Migration added to `fhir-service/db/schema/public` directory. Please, note that we are creating two functions that refer to the same coffee script function. The latter definition (with the `_withplv8` suffix) is a workaround for autovacuum issue and it will be used in the tenant migration. 
        ```sql
        DROP FUNCTION IF EXISTS fhir_extract_as_string_array(resource json, metas json) CASCADE;
        CREATE OR REPLACE FUNCTION
        fhir_extract_as_string_array(resource json, metas json)
        RETURNS text[] AS $JAVASCRIPT$
          var mod = require("/fhirbase-plv8/src/fhir/search_string.coffee")
          return mod.fhir_extract_as_string_array(plv8, resource, metas)
        $JAVASCRIPT$ LANGUAGE plv8 IMMUTABLE;
        
        
        DROP FUNCTION IF EXISTS public.fhir_extract_as_string_array_withplv8(resource json, metas json) CASCADE;
        CREATE OR REPLACE FUNCTION
        public.fhir_extract_as_string_array_withplv8(resource json, metas json)
        RETURNS text[] AS $JAVASCRIPT$
          var mod = require("/fhirbase-plv8/src/fhir/search_string.coffee")
          return mod.fhir_extract_as_string_array(plv8, resource, metas)
        $JAVASCRIPT$ LANGUAGE plv8 IMMUTABLE;
        ```
   - Migration added to `fhir-service/db/schema/tenant` directory:
        ```sql
        DROP FUNCTION IF EXISTS fhir_extract_as_string_array(resource json, metas json) CASCADE;
        CREATE OR REPLACE FUNCTION
        fhir_extract_as_string_array(resource json, metas json)
        RETURNS text[]
         LANGUAGE sql
         IMMUTABLE
        AS $function$
          SELECT set_config('plv8.start_proc', 'public.plv8_init', false);
          SELECT public.fhir_extract_as_string_array_withplv8(resource, metas)
        $function$;
        ```  
    
**Note:** If you have changed a function that is used for creating indexes, you must regenerate those indexes.

## Troubleshooting

1. To compile the coffee scripts smoothly, you'll require XCode to be installed on your local machine. However, even if the XCode is installed you can encounter the problems with the `node-gyp` library:
   - `gyp: No Xcode or CLT version detected!` or
   - `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`
   
   To fix this issue follow the steps:
   - [Remove already existing XCode installation](https://medium.com/flawless-app-stories/gyp-no-xcode-or-clt-version-detected-macos-catalina-anansewaa-38b536389e8d)
   - Follow [one of the solutions](https://github.com/nodejs/node-gyp/blob/master/macOS_Catalina.md#solutions) provided by `node-gyp` maintainers. You can try with the second solution (reinstalling Xcode Command Line Tools) but in my case even if the "acid test" has passed `node-gyp` still didn't work, so be ready for the first solution, i.e. installing the full XCode and waiting a long time until it is downloaded.

## Development Installation

Development installation requires node v6.2.0 or newer
and npm 3.0.0 or newer, which could be installed by [nvm][]:

[nvm]: https://github.com/creationix/nvm

```sh
# install node < 0.12 by nvm for example
sudo apt-get install postgresql-contrib-9.4 postgresql-9.4-plv8  -qq -y

git clone https://github.com/fhirbase/fhirbase-plv8
cd fhirbase-plv8
git submodule init && git submodule update

npm install && cd plpl && npm install
npm install -g mocha && npm install -g coffee-script

psql -c "CREATE USER fb WITH PASSWORD 'fb'"
psql -c 'ALTER ROLE fb WITH SUPERUSER'
psql -c 'CREATE DATABASE fhirbase;' -U postgres
psql -c '\dt' -U postgres

export DATABASE_URL=postgres://fb:fb@localhost:5432/fhirbase

# build migrations
coffee  utils/generate_schema.coffee -n  | psql fhirbase
cat utils/patch_3.sql | psql fhirbase

# change something
# reload schema

plpl/bin/plpl reload
npm run test

# goto: change something
```

## Run test suite in docker container

```sh
git clone https://github.com/fhirbase/fhirbase-plv8 fhirbase
cd fhirbase
docker build .
```

## PostgreSQL Config For Plv8

If you have permissions to edit PostgreSQL config, add directive for auto setting plv8 parameter for every connection. It will make your debugging and development much easier:

```
echo "plv8.start_proc='plv8_init'" >> /etc/postgresql/9.4/main/postgresql.conf
```

## Usage

To make fhirbase-plv8 work, just after opening connection to postgresql, you have to issue the following command (read more [here](http://pgxn.org/dist/plv8/doc/plv8.html#Start-up.procedure)):


```sql
SET plv8.start_proc = 'plv8_init';
```

## Examples

```sql

SET plv8.start_proc = 'plv8_init';

-- work with storage

SELECT fhir_create_storage('{"resourceType": "Patient"}');
SELECT fhir_drop_storage('{"resourceType": "Patient"}');
SELECT fhir_truncate_storage('{"resourceType": "Patient"}');
-- delete all resources of specified type

-- the above commands should look like this:
$ psql fhirbase
psql (9.4.6)
Type "help" for help.

fhirbase=# SET plv8.start_proc = 'plv8_init';
SET
fhirbase=# SELECT fhir_create_storage('{"resourceType": "Patient"}');
                  fhir_create_storage                  
-------------------------------------------------------
 {"status":"ok","message":"Table patient was created"}
(1 row)

fhirbase=# 


-- CRUD

SELECT fhir_create_resource('{"resource": {"resourceType": "Patient", "name": [{"given": ["Smith"]}]}}');

-- create will fail if id provided, to create with predefined id pass [allowId] option or use fhir_update_resource
SELECT fhir_create_resource('{"allowId": true, "resource": {"resourceType": "Patient", "id": "smith"}}');

-- conditional create
SELECT fhir_create_resource('{"ifNoneExist": "identifier=007", "resource": {"resourceType": "Patient", "id": "smith", "name": [{"given": ["Smith"]}]}}');

SELECT fhir_read_resource('{"resourceType": "Patient", "id": "smith"}');

SELECT fhir_vread_resource('{"resourceType": "Patient", "id": "????", "versionId": "????"}');

SELECT fhir_resource_history('{"resourceType": "Patient", "id": "smith"}');

SELECT fhir_resource_type_history('{"resourceType": "Patient", "queryString": "_count=2&_since=2015-11"}');

SELECT fhir_update_resource('{"resource": {"resourceType": "Patient", "id": "smith", "name": [{"given": ["John"], "family": ["Smith"]}]}}');

-- conditional update
SELECT fhir_update_resource('{"ifNoneExist": "identifier=007", "resource": {"resourceType": "Patient", "id": "smith", "name": [{"given": ["Smith"]}]}}');

-- update with contention guard
SELECT fhir_update_resource('{"ifMatch": "..versionid..", "resource": {"resourceType": "Patient", "id": "smith", "name": [{"given": ["Smith"]}]}}');

SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith"}');

SELECT fhir_index_parameter('{"resourceType": "Patient", "name": "name"}');
SELECT fhir_unindex_parameter('{"resourceType": "Patient", "name": "name"}');

SELECT fhir_search_sql('{"resourceType": "Patient", "queryString": "name=smith"}');
-- see generated SQL

SELECT fhir_explain_search('{"resourceType": "Patient", "queryString": "name=smith"}');
-- see execution plan

-- mark resource as deleted (i.e. keep history)
SELECT fhir_delete_resource('{"resourceType": "Patient", "id": "smith"}');

-- completely delete resource and it history
SELECT fhir_terminate_resource('{"resourceType": "Patient", "id": "smith"}');

-- expand valueset
SELECT fhir_valueset_expand('{"id": "issue-types", "filter": "err"}');

---

SELECT fhir_conformance('{"default": "values"}');
-- return simple Conformance resource, based on created stores

---

-- use different methods to calculate total elements to improve performance: no _totalMethod or _totalMethod=exact uses standard approach
SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith"}');
SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith&_totalMethod=exact"}');

-- _totalMethod=extimated - faster but 'total' is estimated.
SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith&_totalMethod=estimated"}');

-- _totalMethod=no - fastest but no 'total' is returned.
SELECT fhir_search('{"resourceType": "Patient", "queryString": "name=smith&_totalMethod=no"}');

```

## Contributing

See the [CONTRIBUTING.md][].

[CONTRIBUTING.md]:https://github.com/fhirbase/fhirbase-plv8/blob/master/CONTRIBUTING.md

## License

Copyright © 2016 health samurai.

fhirbase is released under the terms of the MIT License.
 
