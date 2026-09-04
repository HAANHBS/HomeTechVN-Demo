# HomeTechVN — First-run data policy

HomeTechVN production/business data starts empty.

Allowed foundation/system data after first-run reset:

- roles;
- permissions;
- role-permission mappings;
- non-secret application settings;
- the 12 locked system `reminder_rules` created by the T9 migration.

These reminder rules are configuration, not customer/business transactions.

Not allowed as retained first-run data:

- Auth users;
- customer/customer-device records;
- products or inventory transactions;
- sales/orders/payments;
- repair records;
- warranties/claims;
- service schedules;
- software licenses;
- reminders;
- notifications;
- T17 demo fixtures.

T17 may create temporary local fixtures only for automated verification. A
successful T17 acceptance must reset the local database back to the normal seed
baseline and prove that the Auth/business tables contain zero rows.

The first real operational data is created by normal application use after
installation.
