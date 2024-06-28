# HMB

HMB (hold my beer) is an app designed for a single handyman to run their business.

HMB supports the following:
* customer database
* supplier databse
* job management

A Job is to track work we are doing for a customer.
How you use a job is fairly flexible but generally I recommend creating
a job each time a customer books a service. 

A job is associated with a single customer and site (simply an address associated
with a customer). 
Within a job you create tasks, I job should have at least one task but can
and usually has many tasks associated with it.

As an example you might create a job called:

'Shed and Gates' 

Then within the Job you might have the following tasks
* order shed
* build sheet
* order gate latch
* install gate latch

Once you have a task you can add a checklist to track items that you need
to take or purchase to complete the task.

Items in you checklist that are marked as need to be purchased can be
seen in the global shopping list - so next time you go to the hardware store
you can access a single shopping list, mark items as purchased and track how much 
you paid for each item.

# Time Entry
HMB can track the time you spend on a job.
Time is tracked against a task. Find the Job card, open it to see the list of tasks.
You can start a task timer by click the '>' icon on the Task card.
When you stop working on a task you can click the '[]' icon to stop the timer.
The time is then added to the task.

# Shopping List
HMB has a global shopping list. This is a list of items that you need to purchase
to complete a job.
You can add items to the shopping list by clicking the '+' icon on the Job card.
You can then add items to the shopping list by clicking the '+' icon on the
Shopping List card.

# Hardware Store
HMB has a hardware store. This is a list of items that you can purchase.
You can add items to the hardware store by clicking the '+' icon on the Job card.
You can then add items to the hardware store by clicking the '+' icon on the
Hardware Store card.

# Hardware Inventory
HMB has a hardware inventory. This is a list of items that you have purchased.
You can add items to the hardware inventory by clicking the '+' icon on the Job card.
You can then add items to the hardware inventory by clicking the '+' icon on the
Hardware Inventory card.


## Getting Started

To get started fork this project on GitHub and download it to your local
machine.
Place your phone into development mode and run the build script to install
HMB onto your phone.

dart tool/build.dart


# Limitations

HMB runs on a local sql3lite database. This means that your jobs are only
access on a single device. If you loose that device the you loose all of your data!

To ensure that you don't loose your data you need to run a backup of you HMB
database on a regular database. 
I would recommend doing this daily. Once you have configured your backup it's
quick and easy to do a daily backup.



# Devevelopment
To contribute to HMB start by forking this git hub repo.

As we use the oidc package for oauth (used for the xero integration) you 
need to enable MultiDex by running:

```
flutter run
```
from the package root directory (from a terminal) and press y when asked.


# Gradle:

The project has an explicit path set for java in the android/gradle.properties file.
You will like need to update this path to point to your local java installation.

Note; android needs java 11.


# Upgrading the database.

Each time the app is launched it will check if the database needs to
be upgraded and automatically upgrade the databse.

The upgrade scripts are shipped as assets in the
 assets/sql/upgrade_scripts

In development to upgrade the database create a .sql file with the name
'vNN.sql'

Where NN is the new version number.
The version number must be an integer and should be one higher than the
previous version file in the directory.

Once you have added a new version file you must register it by
running the script:

tool/build.dart --assets

In development to upgrade the database create a .sql file with the name
'vNN.sql'

Where NN is the new version number.
The version number must be an integer and should be one higher than the
previous version file in the directory.

Once you have added a new version file you must register it by
running the script:

tool/build.dart --assets

This script updates the asset/sql/upgrade_list.json file which is 
used at run time to identify the set of upgrade assets.

During development we try to keep the number of updates grouped 
into a single version.
This is not a hard rule.
Essentially during a chunk of dev just agregate db updates into 
a single vNN.sql file until you are ready to push code.
This may required you to keep deleting your database (the start up code reports its location).
You can just do a 'rm <path to db>' and the app will recreate the db.

If another developer is actively working on the db version upgrades will need
to be co-ordinated and this may require more frequent version number releases.


# Web target
When running handyman in a browser, sqlite needs to have web support added to the package:

Instructions are here:
https://github.com/tekartik/sqflite/tree/master/packages_web/sqflite_common_ffi_web#setup-binaries

As a convenience I've included the files it injects (the wasm binary)
in the repo.

If we upgrade sqlflite we need to upgrade the injected files as per the above link.

Note: currenlty we are not backing up the db before doing schema upgrades
as we don't know how to do this on the web.

If you want to use the Xero integration, when in debugg you need to launch 
the app with the args:
`--web-port 22433`

see xero_auth.dart for details.


# Linux development
I do most of my development on a Ubuntu box with some work on a Windows laptop.
To get the linux environment working you need to run:

```
tool/linux_setup.dart
```

# Xero
HMB supports xero for invoicing.
This means that you can track your time in HMB (via creating time entries 
against a task) and then have HMB automatically generate an invoice in xero.

For this to work you need to:

Have an Xero account (the base one will do).

Log into the xero developer portal at:
https://developer.xero.com/app/manage/

Within the developer portal:
Add an App 
Configure a connection for the app;  storing the client id and client secret into the 
system table - not currently not encrypted!

Add the following redirect URL to the xero configuration:

http://localhost:12335



# Build/install

You can run a build and intall HMB to your phone by running:

dart tool/build.dart 

# Project Icons

We use the dependency flutter_launcher_icons to generate the various icon sizes.
To regenerate the icons run the following command:

```
flutter pub get
flutter pub run flutter_launcher_icons:main
```
