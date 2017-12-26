# A sample Django application with Vault

This project has been deveoped as a POC to show how we can use HashiCorp Vault with Django. The main objective is that there will be no secret in the codebase and application's secret will be read from Vault. Also, we need to ensure that the database secrets will be generated dynamically and will be valid only for a short period of time. **consul-template** will fetch new secret from Vault time-to-time and will write new secrets to `settings.py` dynamically.

## Vault

Vault is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. Vault provides a unified interface to any secret, while providing tight access control and recording a detailed audit log.

### Key Features

- **Secure Secret Storage**: Arbitrary key/value secrets can be stored as encrypted in Vault.

- **Dynamic Secrets**: Vault can generate secrets on-demand for some systems, such as AWS or SQL databases.

- **Data Encryption**: Vault can encrypt and decrypt data without storing it.

- **Leasing and Renewal**: All secrets in Vault have a lease associated with them. At the end of the lease, Vault will automatically revoke that secret. Clients are able to renew leases via built-in renew APIs.

- **Revocation**: Vault has built-in support for secret revocation. Vault can revoke not only single secrets, but a tree of secrets. Revocation assists in key rolling as well as locking down systems in the case of an intrusion.

### Use Cases

- **General Secret Storage**: Vault would be a fantastic way to store sensitive environment variables, database credentials, API keys, etc.

- **Employee Credential Storage**: Vault is a good mechanism for storing credentials that employees share to access web services.

- **API Key Generation for Scripts**: The "dynamic secrets" feature of Vault is ideal for scripts: an database username &amp; password can be generated for a short period of time, then revoked.

- **Data Encryption**: Vault can be used to encrypt/decrypt data that is stored elsewhere.

## Prerequisite
- [x] Vault = v0.9.0
- [x] PostgreSQL = v10.1
- [x] consul-template = v0.19.4

## Run vault as a dev mode

```
$ vault server -dev
$ export VAULT_ADDR='http://127.0.0.1:8200'
```

Get the root token and then:

```
$ vault auth {root_token}
```

## Create a new root token

Let's create a new token with root policy

```
$ vault token-create -policy="root" -display-name="maateen"
```

Login using new token

```
$ vault auth {new_token}
```

## Setup PostgreSQL

Let's run PostgreSQL in docker container

```
$ docker rm -f postgres; docker run -d -p 5432:5432 --name postgres -e POSTGRES_PASSWORD=123456789 postgres
```

Let's login to the PostgreSQL

```
$ docker exec -it {CONTAINER ID} psql -U postgres
```

Create a database named "testdb".

```
# CREATE DATABASE testdb;
```

## Secret Backend (PostgreSQL)

The database backend supports using many different databases as secret backends, including but not limited to: cassandra, mssql, mysql, postgres. The first step is mounting it.

```
$ vault mount database
```

After mounting this backend, wee need to configure it using the endpoints within the `database/config/` path to connect to a database. This backend can configure multiple database connections, therefore a name for the connection must be provided; we'll call this one simply "testdb".

> `allowed_roles` parameter refers to comma separated string or array of the role names allowed to get creds from this database connection. If empty no roles are allowed. If "*" all roles are allowed. The role can be configured as readonly, readwrite, admin and can be named as any.

```
$ vault write database/config/testdb plugin_name=postgresql-database-plugin allowed_roles="admin" connection_url="postgresql://postgres:123456789@localhost:5432/postgres?sslmode=disable"
```

The next step is to configure a role. A role is a logical name that maps to a policy used to generate those credentials. A role needs to be configured with the database name we created above, and the default/max TTLs.

- The "db_name" parameter is required and configures the name of the database connection to use.

- The "creation_statements" parameter customizes the string used to create the credentials. This can be a sequence of SQL queries, or other statement formats for a particular database type. Some substitution will be done to the statement strings for certain keys. The names of the variables must be surrounded by **{{** and **}}** to be replaced.

- "default_ttl (duration (sec))" refers to default ttl for role.

- "max_ttl (duration (sec))" maximum time a credential is valid for.

Lets create a role named 'admin':

```
$ vault write database/roles/admin db_name=testdb creation_statements="CREATE ROLE \"{{name}}\" WITH SUPERUSER LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" revocation_sql="SELECT revoke_access('{{name}}'); DROP user \"{{name}}\";" default_ttl="300" max_ttl="600"
```

To generate a new set of credentials, we simply read from that role:

```
$ vault read database/creds/admin
```

## consul-template

```
$ cd {appplication_root_path}
$ nano config.hcl
$ consul-template -config=config.hcl
```

## Authentication with AppRole

An AppRole represents a set of Vault policies and login constraints that must be met to receive a token with those policies. The scope can be as narrow or broad as desired -- an AppRole can be created for a particular machine, or even a particular user on that machine, or a service spread across machines. The credentials required for successful login depend upon the constraints set on the AppRole associated with the credentials.

Enable AppRole authentication:

```
$ vault auth-enable approle
```

Create a role:

> **token_ttl** refers to the lifetime of a token where **token_max_ttl** refers to the maximum lifetime. token_max_ttl should be greater than token_ttl.

```
$ vault write auth/approle/role/testrole secret_id_ttl=10m token_num_uses=10 token_ttl=20m token_max_ttl=30m secret_id_num_uses=40
```

Fetch the RoleID of the AppRole:

```
$ vault read auth/approle/role/testrole/role-id
```

Get a SecretID issued against the AppRole:

```
$ vault write -f auth/approle/role/testrole/secret-id
```

Login to get a Vault Token:

```
$ vault write auth/approle/login role_id={role-id} secret_id={secret_id}
```

Now authenticate with the newly generated token:

```
vault auth {token}
```

## Disclaimer

When we will apply this concept, an issue may be happened. When sceret credentials will be updated everytime and Django settings will need to be reloaded/refreshed. We may fix this issue in two ways:

- We may implement High Availability (HA) architecture. Because when the web app will be reloaded/restarted into an instance, another instance can serve the request.

- We may write a [monkey patch](https://github.com/jdelic/12factor-vault/blob/master/vault12factor/__init__.py#L284) which retries failed database connections after refreshing the database credentials from Vault.

If we implement the concept for Laravel app, then running `php artisan config:cache` command may be enough.