# HMB

HMB (hold my beer) is an app designed for a single handyman to run their business.

HMB supports the following:
* customer database
* supplier database
* job management
* timekeeping
* shopping list
* global shopping list
* job invoicing


## Features

HMB supports the following features:
* customer database including multiple contacts and sites.
* supplier database 
* job management
* time keeping
* globally shopping list built from job/task based checklists.
* basic job invoicing
* click to dial 
* click to email
* click to text (coming)

# Overview

HMB is based around Jobs. 
A Job represents work for a customer at a specific site.

Within a Job you create the set of Tasks that make up the parts of a Job.
Time tracking is done against a task.
Each Task can have a checklist associated with it. Items in the checklist that
are marked as 'need to be purchased' will be added to the global shopping list.

The global shopping list is a list of all items that need to be purchased.
Once a task is complete you can generate an invoice for the task. 
Invoicing is very basic and you still need an external accounting package.
Currently HMB supports Xero and is able to upload an invoice directly into Xero.

See the HMB wiki for more information.

https://github.com/bsutton/handyman/wiki




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

Add the following redirect URLs to the xero configuration:

For development:

http://localhost:12335

For an android device:

https://hmb.ivanhoehandyman.com.au/xero/callback


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
