# HMB

HMB (hold my beer - I'm a handyman) is an app designed for a single handyman to run their business.

HMB is free to use with community based support that can be obtained by raising an [issue](https://github.com/bsutton/hmb/issues) an or starting a [discussion](https://github.com/bsutton/hmb/discussions).

HMB currently runs on android but is designed to also run on iOS (need someone to assist with the apple store release process).

HMB supports the following:
* customer database
* supplier database
* job management
* timekeeping
* shopping list
* packing list
* job invoicing
* job photos

Planned:
Quotation module

# Benefits
### Feel more organised
As soon as you start using HMB you are going to feel more organised with all your customer, supplier and job data in a single, simple to use app.  

### reduced trips to the hardware store and back to base
HMB reduces trips to the hardware store through its shopping list and return trips to base for that forgotten tool via its packing list.

### bill every hour
HMB makes it easy to track time so now its easy to bill every hour you work.

### work anywhere
HMB works even when you don't have an internet connection - so you always have all your information at hand even when on a remote site.

### Less paperwork 
With HMB's quotation and invoicing system you can send quotes and invoice customers whilst on the go (in development).

# Features

HMB supports the following features:
* customer database including multiple contacts and sites.
* supplier database
* job management (tasks and checklists)
* attach photos to Jobs.
* time tracking
* global shopping list built from job/task based checklists.
* global packing list
* basic job invoicing (partially working)
* quoting (partially working)
* click to dial 
* click to email
* click to text 
* click to navigate

# Overview
HMB is designed to help a single person handyman business run their operations, get organised and bill customers sooner.

HMB is designed around the workflow of a typical handyman:
* received a request for a quote
* perform a site visit recording notes and taking photos
* prepare a quote
* shop for materials
* pack tools
* recording time on site
* invoice a customer for time and materials used or based on a fixed price.

Each of these steps are optional with HMB letting you use it as suits your requirements.

# the heart of HMB
HMB is based around Jobs. 
A Job represents work for a customer at a specific site.

Within a Job you create the set of Tasks that make up the parts of a Job.
Time tracking and costings are done against a task but totaled to the Job.

Each Task can have:
* Notes about the task
* Status of the task
* Estimates based on time or cost
* Time tracking entries - used to generate invoices when using the 'Time and Materials' billing method.
* Annotated photos
* track hours worked on the Task

Items in the checklist that are marked as 'buy' will be added to the [shopping list](https://github.com/bsutton/hmb/wiki/Shopping-List)
and will appear on the Job quote/invoice.

Items in the checklist that are marked as 'Tools - own' will be added to the [packing list](https://github.com/bsutton/hmb/wiki/Packing-List).

# Quoting
When creating tasks you can select the billing method (fixed price or time and materials) and enter an estimate for the task.
You an add checklist items which if marked as 'to be purchased' appear in the quote.

Once you have created all of the task along with their estimates you can create an email a quote from the Job Card.
- this is still a work in progress

## invoicing
Provides a the ability to generate invoices for Jobs.

You still need an accounting package to run your business. You would generally transfer the details from an HMB invoice into your accounting package.

You can either progressively invoice for work done or wait until the task/job is complete.


## limitations
HMB can only run on a single device - for most people this will mean your phone but you can also use a tablet (android only at this point).
The advantage is that HMB works even when you don't have a mobile connection, the disadvantage is that if you lose
or damage your phone you have just lost all your customer and job data and there is no way to share your HMB data with another team member.

So - you need to **backup** HMB on a regular basis - it's easy and only takes a moment - see the section below on [backups](https://github.com/bsutton/hmb/wiki/Backups).









