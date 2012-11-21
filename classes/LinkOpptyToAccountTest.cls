/*
 * Tests LinkOpptyToAccount.cls and InsertContactRoles.cls. Coverage is roughly 94%.
 * The SeeAllData=true annotation is necessary in order to test/access the
 * Opportunity_Link_Active__c custom setting on/off switch for this functionality.
 *
 * Author: nwisman, 2012.
 */

@isTest(SeeAllData=true)
private class LinkOpptyToAccountTest {
    public static Account testAccount;
    public static Id individualAcctRT;

    static {
        individualAcctRT = [select Id from RecordType where isActive=true and sObjectType='Account' and Name='Individual' Limit 1].Id;
        delete [select Id from Account where RecordTypeId = :individualAcctRT];
        delete [select Id from Opportunity where Name like 'A Raisin In The Sun %'];
    }

    /* Test that turning off our custom setting deactivates linking of Opportunity to Account and Contact */
    static testMethod void testCustomSetting() {
        Opportunity_Link_Active__c setting = [select Active__c, Name from Opportunity_Link_Active__c where Name = 'Link Opportunities to Accounts'];
        setting.Active__c = false;
        update setting;

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', 
                                        Street_Address__c='444 Diff Address', City__c='Los Angeles', State__c='MD', 
                                        Zip_Code__c='88832', Phone_Number__c='(999) 345-3210', FirstName__c='Mkjewnr', LastName__c='Kksjfnsdf');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it is not linked to any Account
        o = [select Id, Name, AccountId, Street_Address__c, City__c, State__c, Zip_Code__c, Phone_Number__c from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, null);
        System.assertEquals(0, [select count() from Account where Name like 'Tkjdsnrd 342fs%']);
        System.assertEquals(0, [select count() from Contact where Name like 'Tkjdsnrd 342fs%']);

        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);

        // Create and insert another Opportunity
        Opportunity o2 = new Opportunity(Name='John Test3e343fds2', CloseDate=System.today(), StageName='Closed Won', 
                                        Street_Address__c='444 Diff Address', City__c='Los Angeles', State__c='MD', 
                                        Zip_Code__c='88832', Phone_Number__c='(999) 345-3210');
        insert o2;
        System.assertNotEquals(null, o2.Id);

        // Check that it is not linked to our Account
        o2 = [select Id, Name, AccountId, Street_Address__c, City__c, State__c, Zip_Code__c, Phone_Number__c from Opportunity where Id = :o.Id];
        System.assertEquals(o2.AccountId, null);
        System.assertEquals(0, [select count() from Contact where Name like 'John Test3e343fds2%']);
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account and Contact Role is created */
    static testMethod void insertSingleOppty() {
        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);

        System.assertEquals(0, [select count() from Opportunity where AccountId = :testAccount.Id]);
        System.assertEquals(0, [select count() from Contact where AccountId = :testAccount.Id]);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', 
                                        Street_Address__c='444 Diff Address', City__c='Los Angeles', State__c='MD', 
                                        Zip_Code__c='88832', Phone_Number__c='(999) 345-3210', FirstName__c='John', LastName__c='Test3e343fds2');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId, Street_Address__c, City__c, State__c, Zip_Code__c, Phone_Number__c, FullName__c from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount.Id);

        // Check that Account's Billing information is not updated to the Opportunity address (however Contact address should be)
        Account a = [select Name,
                            BillingStreet,
                            BillingCity,
                            BillingState,
                            BillingPostalCode,
                            Phone
                     from Account
                     where Id = :o.AccountId Limit 1];
        System.assertEquals(o.FullName__c + ' - Resident', a.Name);
        System.assertNotEquals(o.Street_Address__c, a.BillingStreet);
        System.assertNotEquals(o.City__c, a.BillingCity);
        System.assertNotEquals(o.State__c, a.BillingState);
        System.assertNotEquals(o.Zip_Code__c, a.BillingPostalCode);
        System.assertEquals(o.Phone_Number__c, a.Phone);

        // Check that we created a new Contact since one didn't exist already
        System.assertEquals(1, [select Count() from Contact where AccountId = :testAccount.Id]);
        Contact c = [select Name,
                            MailingStreet,
                            MailingCity,
                            MailingState,
                            MailingPostalCode,
                            Phone
                     from Contact
                     where AccountId = :testAccount.Id Limit 1];
        System.assertEquals('John Test3e343fds2', c.Name);
        System.assertEquals(o.Street_Address__c, c.MailingStreet);
        System.assertEquals(o.City__c, c.MailingCity);
        System.assertEquals(o.State__c, c.MailingState);
        System.assertEquals(o.Zip_Code__c, c.MailingPostalCode);
        System.assertEquals(o.Phone_Number__c, c.Phone);

        // And check that an OpportunityContactRole was also created
        System.assertEquals(1, [select Count() from OpportunityContactRole where OpportunityId = :o.Id]);
        OpportunityContactRole ocr = [select Id, ContactId, OpportunityId, Role from OpportunityContactRole where OpportunityId = :o.Id Limit 1];
        System.assertEquals('Decision Maker', ocr.Role);
        System.assertEquals(c.Id, ocr.ContactId);
        System.assertEquals(o.Id, ocr.OpportunityId);
    }

    /* Insert a single SUBSCRIBER Record-Type Opportunity and check to see if it is automatically linked to an Account and Contact Role is created */
    static testMethod void insertSingleSubscriberOppty() {
        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);

        System.assertEquals(0, [select count() from Opportunity where AccountId = :testAccount.Id]);
        System.assertEquals(0, [select count() from Contact where AccountId = :testAccount.Id]);

        Id subscriberOpptyRtId = [select Id from RecordType where Name = 'Subscriber' and sObjectType = 'Opportunity' Limit 1].Id;

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', 
                                        Street_Address__c='444 Diff Address', City__c='Los Angeles', State__c='MD', RecordTypeId = subscriberOpptyRtId,
                                        Zip_Code__c='88832', Phone_Number__c='(999) 345-3210', FirstName__c='John', LastName__c='Test3e343fds2');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId, Street_Address__c, City__c, State__c, Zip_Code__c, Phone_Number__c, FullName__c from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount.Id);

        // Check that Account's Billing information is not updated to the Opportunity address (however Contact address should be)
        Account a = [select Name,
                            BillingStreet,
                            BillingCity,
                            BillingState,
                            BillingPostalCode,
                            Phone
                     from Account
                     where Id = :o.AccountId Limit 1];
        System.assertEquals(o.FullName__c + ' - Resident', a.Name);
        System.assertNotEquals(o.Street_Address__c, a.BillingStreet);
        System.assertNotEquals(o.City__c, a.BillingCity);
        System.assertNotEquals(o.State__c, a.BillingState);
        System.assertNotEquals(o.Zip_Code__c, a.BillingPostalCode);
        System.assertEquals(o.Phone_Number__c, a.Phone);

        // Check that we created a new Contact since one didn't exist already
        System.assertEquals(1, [select Count() from Contact where AccountId = :testAccount.Id]);
        Contact c = [select Name,
                            MailingStreet,
                            MailingCity,
                            MailingState,
                            MailingPostalCode,
                            Phone
                     from Contact
                     where AccountId = :testAccount.Id Limit 1];
        System.assertEquals('John Test3e343fds2', c.Name);
        System.assertEquals(o.Street_Address__c, c.MailingStreet);
        System.assertEquals(o.City__c, c.MailingCity);
        System.assertEquals(o.State__c, c.MailingState);
        System.assertEquals(o.Zip_Code__c, c.MailingPostalCode);
        System.assertEquals(o.Phone_Number__c, c.Phone);

        // And check that an OpportunityContactRole was also created
        System.assertEquals(1, [select Count() from OpportunityContactRole where OpportunityId = :o.Id]);
        OpportunityContactRole ocr = [select Id, ContactId, OpportunityId, Role from OpportunityContactRole where OpportunityId = :o.Id Limit 1];
        System.assertEquals('Decision Maker', ocr.Role);
        System.assertEquals(c.Id, ocr.ContactId);
        System.assertEquals(o.Id, ocr.OpportunityId);
    }

    /* Insert a single Opportunity with multiple space name and check to see if it is automatically linked to an Account */
    static testMethod void insertSingleOpptyMultiSpaceName() {      
        Account testAcc = new Account(Name='Bill jk32 fdsfkj - Resident', RecordTypeId=individualAcctRT);
        insert testAcc;
        System.assertNotEquals(testAcc.Id, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        FirstName__c='Bill jk32', LastName__c='fdsfkj');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAcc.Id);
        // Check that if there was no Contact, we created one
        System.assertEquals(1, [select Count() from Contact where AccountId = :testAcc.Id]);
        System.assertEquals('Bill fdsfkj', [select Name from Contact where AccountId = :testAcc.Id Limit 1].Name);
    }

    /* Insert a single Opportunity with multiple space name and check to see if it is automatically linked to an Account */
    static testMethod void insertSingleOpptyMultiSpaceName2() {
        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);
        System.assertEquals(0, [select count() from Opportunity where AccountId = :testAccount.Id]);

        Account testAcc = new Account(Name='Bill jk32 fdsfkj e4j fsdf ffdfs - Resident', RecordTypeId=individualAcctRT);
        insert testAcc;
        System.assertNotEquals(testAcc.Id, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        FirstName__c='Bill jk32 fdsfkj', LastName__c='e4j fsdf ffdfs');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAcc.Id);
        // Check that if there was no Contact, we created one
        System.assertEquals(1, [select Count() from Contact where AccountId = :testAcc.Id]);
        System.assertEquals('Bill ffdfs', [select Name from Contact where AccountId = :testAcc.Id Limit 1].Name);
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account if there are two matching Accounts, but only
       one has a matching Contact */
    static testMethod void insertSingleOpptyTwoMatches() {
        String oppName = 'yfjiug8 gfjndsd';
        delete [select Id, Name from Account where Name = :oppName];
        Opportunity[] opptyList = new List<Opportunity>();
        Id[] oIdList = new List<Id>();

        // Insert 2 Accounts with same name but different email addresses
        Account testAccount1 = new Account(Name='tester23 jkfsnk34kjn - Resident', RecordTypeId=individualAcctRT);
        insert testAccount1;
        System.assertNotEquals(testAccount1.Id, null);

        Account testAccount2 = new Account(Name='tester23 jkfsnk34kjn - Resident', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Email='jt@yahoomail.com', AccountId=testAccount2.Id);
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert two Opportunities with the same Name and one with completely different Name
        opptyList.add(new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', Email__c='jt@yahoomail.com',
                                      FirstName__c='tester23', LastName__c='jkfsnk34kjn'));
        opptyList.add(new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', Email__c='jt@yahoomail.com',
                                      FirstName__c='tester23', LastName__c='jkfsnk34kjn'));
        opptyList.add(new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', Email__c='diff@gmail.com',
                                      FirstName__c='Akjsndf', LastName__c='kdsjfn'));
        insert opptyList;
        System.assertNotEquals(null, opptyList[0].Id);
        oIdList.add(opptyList[0].Id);
        System.assertNotEquals(null, opptyList[1].Id);
        oIdList.add(opptyList[1].Id);
        System.assertNotEquals(null, opptyList[2].Id);
        oIdList.add(opptyList[2].Id);

        opptyList = [select Id, Name, FullName__c, AccountId from Opportunity where Id in :oIdList];

        // Check that first two Opptys were linked to existing Accounts, and other had new Account & Contact created
        System.assertEquals(opptyList[0].AccountId, testAccount2.Id);
        System.assertEquals(opptyList[1].AccountId, testAccount2.Id);
        System.assertEquals(opptyList[2].AccountId, [select Id from Account where Name = :opptyList[2].FullName__c+' - Resident' Limit 1].Id);
        System.assertEquals(opptyList[2].FullName__c, [select Name from Contact where Name = :opptyList[2].FullName__c Limit 1].Name);
    }

    /* Insert a single Opportunity and check to see if it is linked to first found Account, if no Contacts exist */
    static testMethod void insertOpptyTwoMatchesNoCntcts() {
        // Insert 2 Accounts with same name but different email addresses
        Account testAccount1 = new Account(Name='tester23 jkfsnk34kjn - Resident', RecordTypeId=individualAcctRT);
        insert testAccount1;
        System.assertNotEquals(testAccount1.Id, null);

        Account testAccount2 = new Account(Name='tester23 jkfsnk34kjn - Resident', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', Email__c='jt@yahoomail.com',
                                        FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];

        if (o.AccountId == testAccount1.Id) {
            System.assertEquals(o.AccountId, testAccount1.Id);
        }
        else {
            System.assertEquals(o.AccountId, testAccount2.Id);
        }
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account if there are no matching Accounts, but there IS a
       Contact that matches EMAIL and NAME */
    static testMethod void insertOpptyNoAcctsMatchCntctsEmail() {
        // Insert an Account whose name makes finding it impossible
        Account testAccount2 = new Account(Name='name is very different', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, populating Name and Email
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Email='jt@yahoomail.com', AccountId=testAccount2.Id);
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity with Name and Email that match Contact
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', Email__c='jt@yahoomail.com',
                                        FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount2.Id);
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account if there are no matching Accounts, but there IS a
       Contacts that matches PHONE and NAME */
    static testMethod void insertOpptyNoAcctsMatchPhone() {
        // Insert an Account whose name makes finding it impossible
        Account testAccount2 = new Account(Name='name is very different', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, populating Name and Phone
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Phone='(999) 444-4443', AccountId=testAccount2.Id,
                                          Email='oldEmail@oldEmail.com', MailingStreet='123 Smith Ave.', MailingCity='Traverse', MailingState='FL',
                                          MailingPostalCode='54321');
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity with Name, Phone, and Address that match Contact
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        Phone_Number__c='(999) 444-4443', Email__c='newEmail@newEmail.com', Street_Address__c='123 Smith Ave.',
                                        City__c='Traverse', State__c='FL', Zip_Code__c='54321', FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account and the Contact's email address is now updated
        o = [select Id, Name, AccountId, Email__c from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount2.Id);
        System.assertEquals(o.Email__c, [select Email from Contact where Id = :testContact.Id Limit 1].Email);
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account if there are no matching Accounts, but there IS a
       Contact that matches PHONE and NAME and ADDRESS */
    static testMethod void insertOpptyEverythingMatchesContact() {
        // Insert an Account whose name makes finding it impossible
        Account testAccount2 = new Account(Name='name is very different', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, populating Name and Phone
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Phone='(999) 444-4443', AccountId=testAccount2.Id,
                                          Email='newEmail@newEmail.com', MailingStreet='123 Smith Ave.', MailingCity='Traverse', MailingState='FL',
                                          MailingPostalCode='54321');
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity with Name, Phone, and Address that match Contact
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        Phone_Number__c='(999) 444-4443', Email__c='newEmail@newEmail.com', Street_Address__c='123 Smith Ave.',
                                        City__c='Traverse', State__c='FL', Zip_Code__c='54321', FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account and the Contact's email address is now updated
        o = [select Id, Name, AccountId, Email__c from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount2.Id);
        System.assertEquals(o.Email__c, [select Email from Contact where Id = :testContact.Id Limit 1].Email);
    }

    /* Insert a single Opportunity and check to see if it is automatically linked to an Account if there are no matching Accounts by name,
       but there are related Contacts that match the Opportunity's address */
    static testMethod void insertOpptyCntctMatchAddress() {
        // Insert an Account whose name makes finding it impossible, and fill in Shipping Address
        Account testAccount2 = new Account(Name='useless impossible name231', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, populating Name and Address
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', AccountId=testAccount2.Id,
                                          MailingStreet='123 Maple St.', MailingCity='San Francisco', MailingState='CA',
                                          MailingPostalCode='94105');
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity with Name and Address that match Contact
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        Phone_Number__c='(999) 000-2333', Street_Address__c='123 Maple St.', City__c='San Francisco',
                                        State__c='CA', Zip_Code__c='94105', FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccount2.Id);
    }

    /* Insert a single Opportunity and check to see if it is NOT automatically linked to an Account if there are no matching Accounts, but there are
       Contacts without enough attributes to match (mismatched EMAIL) */
    static testMethod void insertOpptyNoAcctsMatchEmailMiss() {
        delete [select Id from Contact where Email = 'ffoof@lknfmsd.com'];

        // Insert an Account whose name makes finding it impossible
        Account testAccount2 = new Account(Name='name is very different', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, which has mis-matching Name and Email
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Email='ffoof@lknfmsd.com', AccountId=testAccount2.Id);
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        Email__c='jt@yahoomail.com', FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertNotEquals(o.AccountId, testAccount2.Id);

        // Ensure we have a new Account
        System.assertEquals(1, [select count() from Account where Name = 'tester23 jkfsnk34kjn - Resident']);
        // Ensure we have a new Contact, linked to our new Account
        System.assertEquals(1, [select count() from Contact where AccountId = :o.AccountId]);
    }

    /* Insert a single Opportunity and check to see if it is NOT automatically linked to an Account if there are no matching Accounts, but there are
       Contacts without enough attributes to match (mismatched PHONE) */
    static testMethod void insertOpptyNoAcctsMatchPhoneMiss() {
        delete [select Id from Contact where Phone = '(233) 555-5534'];

        // Insert an Account whose name makes finding it impossible
        Account testAccount2 = new Account(Name='name is very different', RecordTypeId=individualAcctRT);
        insert testAccount2;
        System.assertNotEquals(testAccount2.Id, null);

        // Link our Contact to this Account, which has matching name and email
        Contact testContact = new Contact(FirstName='tester23', LastName='jkfsnk34kjn', Phone='(233) 555-5534', AccountId=testAccount2.Id);
        insert testContact;
        System.assertNotEquals(testContact.Id, null);
        System.assertNotEquals(testContact.AccountId, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        Phone_Number__c='(999) 444-4443', FirstName__c='tester23', LastName__c='jkfsnk34kjn');
        insert o;
        System.assertNotEquals(null, o.Id);

        // Check that it linked it to our Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertNotEquals(o.AccountId, testAccount2.Id);

        // Ensure we have a new Account
        System.assertEquals(1, [select count() from Account where Name = 'tester23 jkfsnk34kjn - Resident']);
        // Ensure we have a new Contact, linked to our new Account
        System.assertEquals(1, [select count() from Contact where AccountId = :o.AccountId]);
    }

    /* Insert multiple Opportunities and check to see if they are automatically linked to Accounts */
    static testMethod void insertBulkOpptys() {
        Opportunity[] opptyList = new List<Opportunity>();
        Id[] opptyIdList = new List<Id>();
        
        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);

        System.assertEquals(0, [select count() from Opportunity where AccountId = :testAccount.Id]);
        System.assertEquals(0, [select count() from Account where Name like 'Michael K34kjnf']);

        for (Integer i=0; i < 102; i++) {
            opptyList.add(new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                          FirstName__c='John', LastName__c='Test3e343fds2'));
        }

        // Add a random Opportunity to our list to ensure it isn't linked to our Account, but is instead linked to a new Account
        Opportunity randomOppty = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', 
                                                  FirstName__c='Rnaomd', LastName__c='DSFslkdmfsl');
        opptyList.add(randomOppty);
        insert opptyList;

        for (Opportunity o: opptyList) {
            System.assertNotEquals(null, o.Id);
            opptyIdList.add(o.Id);
        }

        for (Opportunity o: [select Id, Name, LastName__c, AccountId from Opportunity where Id in :opptyIdList]) {
            if (o.LastName__c == 'Test3e343fds2') {
                System.assertEquals(o.AccountId, testAccount.Id);
            }
            else {
                System.assertNotEquals(o.AccountId, testAccount.Id);
                System.assertEquals(1, [select count() from Account where Name = 'John Test3e343fds2 - Resident']);
                System.assertEquals(o.AccountId, [select Id, Name from Account where Name = 'Rnaomd DSFslkdmfsl - Resident' Limit 1].Id);
            }
        }
    }

    /* Check that an Account name that does not need to be split by a hyphen also works */
    static testMethod void noSplitAccountName() {
        Account testAccountNoSplit = new Account(Name='Jill Fk3j4kjdk4', RecordTypeId=individualAcctRT);
        insert testAccountNoSplit;
        System.assertNotEquals(testAccountNoSplit.Id, null);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        FirstName__c='Jill', LastName__c='Fk3j4kjdk4');
        insert o;

        // Check that it linked it to correct Account
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertEquals(o.AccountId, testAccountNoSplit.Id);
    }

    /* Check that Opportunities without a matching Account are assigned to a newly created Account and Contact */
    static testMethod void noOpptyLink() {
        delete [select Id from Account where Name = 't89wdfj testj22 - Resident'];

        // Check that an Account for our Opportunity currently does not exist
        System.assertEquals(0, [select count() from Account where Name like 't89wdfj test']);

        // Create and insert Opportunity
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won',
                                        FirstName__c='t89wdfj', LastName__c='testj22');
        insert o;

        // Now verify a new Account has been created and linked to our Opportunity
        o = [select Id, Name, AccountId, Street_Address__c, City__c, State__c, Zip_Code__c, Phone_Number__c from Opportunity where Id = :o.Id];
        System.assertNotEquals(o.AccountId, null);

        // Ensure we have a new Account
        System.assertEquals(1, [select count() from Account where Name = 't89wdfj testj22 - Resident']);
        Account a = [select Name,
                            BillingStreet,
                            BillingCity,
                            BillingState,
                            BillingPostalCode,
                            Phone
                     from Account
                     where Id = :o.AccountId Limit 1];
        System.assertEquals('t89wdfj testj22' + ' - Resident', a.Name);
        System.assertEquals(a.BillingStreet, o.Street_Address__c);
        System.assertEquals(a.BillingCity, o.City__c);
        System.assertEquals(a.BillingState, o.State__c);
        System.assertEquals(a.BillingPostalCode, o.Zip_Code__c);
        System.assertEquals(a.Phone, o.Phone_Number__c);

        // Ensure we have a new Contact, linked to our new Account
        System.assertEquals(1, [select count() from Contact where AccountId = :o.AccountId]);
        Contact c = [select Name,
                            MailingStreet,
                            MailingCity,
                            MailingState,
                            MailingPostalCode
                     from Contact
                     where AccountId = :o.AccountId Limit 1];
        System.assertEquals('t89wdfj testj22', c.Name);
        System.assertEquals(a.BillingStreet, c.MailingStreet);
        System.assertEquals(a.BillingCity, c.MailingCity);
        System.assertEquals(a.BillingState, c.MailingState);
        System.assertEquals(a.BillingPostalCode, c.MailingPostalCode);

        // And check that an OpportunityContactRole was also created
        System.assertEquals(1, [select Count() from OpportunityContactRole where OpportunityId = :o.Id]);
        OpportunityContactRole ocr = [select Id, ContactId, OpportunityId, Role from OpportunityContactRole where OpportunityId = :o.Id Limit 1];
        System.assertEquals('Decision Maker', ocr.Role);
        System.assertEquals(c.Id, ocr.ContactId);
        System.assertEquals(o.Id, ocr.OpportunityId);
    }

    /* Check that Opportunities already linked to an Account aren't linked to different Account */
    static testMethod void acctIdNotReplaced() {
        delete [select Id from Account where Name = 'name kjn3k3jk - Resident'];

        testAccount = new Account(Name='John Test3e343fds2 - Resident', RecordTypeId=individualAcctRT, BillingStreet='123 Maple St.',
                                  BillingCity='San Francisco', BillingState='CA', BillingPostalCode='94105', Phone='(999) 345-3210');
        insert testAccount;
        System.assertNotEquals(testAccount.Id, null);

        // Create and insert a new Opportunity with Account assigned already
        Opportunity o = new Opportunity(Name='A Raisin In The Sun 2012 (STB)', CloseDate=System.today(), StageName='Closed Won', AccountId=testAccount.Id,
                                        FirstName__c='name', LastName__c='kjn3k3jk');
        insert o;

        // Now verify a new Account has been created and linked to our Opportunity
        o = [select Id, Name, AccountId from Opportunity where Id = :o.Id];
        System.assertNotEquals(o.AccountId, null);

        // Ensure we do not have a new Account since the Opportunity already has an Account assigned
        System.assertEquals(0, [select count() from Account where Name = 'name kjn3k3jk - Resident']);
        // Ensure we have a new Contact, linked to our new Account
        System.assertEquals(0, [select count() from Contact where AccountId = :o.AccountId]);

        // Ensure that our Opportunity is still assigned to our first static test Account
        System.assertEquals(o.AccountId, testAccount.Id);
    } /* */
}