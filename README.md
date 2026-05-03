# GoCardless LunchMoney Integration

This project syncs EU/UK bank/credit card accounts with LunchMoney, allowing for seamless synchronization of bank transactions into the LunchMoney budgeting app. The integration leverages GoCardless for bank account data and Pushover for notifications.

## Features

- List available banks for a given country.
- Create requisitions to authorize access to bank accounts.
- Sync bank accounts and transactions with LunchMoney.
- Notifications for expired requisitions and account issues via Pushover.

## Installation (Using Docker and Docker Compose)

1. Create a `docker-compose.yml` file with the following contents:

   ```yml
    services:
      gocardless-lunchmoney:
        restart: unless-stopped
        image: ghcr.io/himynameisjonas/gocardless-lunchmoney:latest
        env_file:
          - .env
        volumes:
          - /path/to/sqlite-file.db:/usr/src/app/db/bank_sync.db
   ```

2. Create a `.env` file in the same directory with the following environment variables:

   ```sh
   NORDIGEN_SECRET_ID=your_nordigen_secret_id
   NORDIGEN_SECRET_KEY=your_nordigen_secret_key
   LUNCH_MONEY_ACCESS_TOKEN=your_lunch_money_access_token
   PUSHOVER_TOKEN=your_pushover_token
   PUSHOVER_USER=your_pushover_user
   ```

3. Run the migrations to create the database tables:

   ```sh
   docker compose run gocardless-lunchmoney migrate
   ```

4. Start the service:
   This will start the sync service and run it in the background with a default interval of 8 hours.
   ```sh
   docker-compose up -d
   ```

## Usage (Using Docker and Docker Compose)

### List Available Banks

To list available banks for a given country (default is Sweden):

```sh
docker compose run gocardless-lunchmoney setup --list-banks [COUNTRY_CODE]
```

### Create Requisition

To create a new requisition for a bank:

```sh
docker compose run gocardless-lunchmoney setup --create-requisition INSTITUTION_ID
```

### Recreate Expired or Suspended Requisition

To recreate a requisition that is expired (`EX`), suspended (`SU`), or still
linked (`LN`) but has one or more accounts in `SUSPENDED`/`ERROR` state:

```sh
docker compose run gocardless-lunchmoney setup --recreate-requisition
```

Before issuing the new requisition, this command refreshes account metadata
(IBAN, owner name) from GoCardless. After you complete the bank's
authorization flow and run `setup --sync-accounts`, the new GoCardless
account_ids are auto-attached to the existing local Account rows by IBAN —
preserving the LunchMoney asset mapping and transaction history. If a match
is ambiguous, a Pushover notification tells you which accounts to relink
manually with `--map_account`.

### Avoiding Account Suspension

GoCardless suspends an account after roughly 10 consecutive failed accesses
(see [Account Suspension](https://ob.helpscoutdocs.com/article/151-account-suspension)).
This sync stays well below that limit by default (one transactions call per
account per 8-hour cycle) and will, on a 4xx during a transactions fetch,
re-check the account's metadata and skip further calls until the account
recovers.

### Sync Accounts

To sync accounts from GoCardless:

```sh
docker compose run gocardless-lunchmoney setup --sync-accounts
```

### List Accounts

To list all accounts and their mapping to LunchMoney:

```sh
docker compose run gocardless-lunchmoney setup --list-accounts
```

### Map Account to LunchMoney Asset

To map a GoCardless account to a LunchMoney asset:

```sh
docker compose run gocardless-lunchmoney setup --map_account ACCOUNT_ID --map_asset ASSET_ID
```

### Sync Transactions

To sync transactions:

```sh
docker compose run gocardless-lunchmoney sync
```

## Database Migrations

To run database migrations:

```sh
docker compose run gocardless-lunchmoney migrate
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
