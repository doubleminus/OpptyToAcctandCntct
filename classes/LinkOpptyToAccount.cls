/*
 * This class will attempt to link all newly inserted Opportunities to Accounts based on a
 * comparison between Opportunity and Account names. If more than one matching Account is found,
 * then Contacts are queried and compared to determine the best match. If no matching Account
 * is found, then a new one is created as well as a Contact and OpportunityContactRole.
 *
 * Author: nwisman, 2012.
 */

public with sharing class LinkOpptyToAccount {
    private static final Id[] ACCT_RT_LIST = Label.AccountRTs.split(';');
    private Opportunity[] opptyList = new List<Opportunity>();
    private Contact[] contactList = new List<Contact>(), updateContactList = new List<Contact>();
    private Map<String,Account> acctNameMap = new Map<String,Account>();
    private Map<String,Opportunity> nameOpptyMap = new Map<String,Opportunity>();
    private Set<Account> duplicateAcctSet = new Set<Account>();
    private Set<String> opptyEmailSet = new Set<String>(), opptyPhoneSet = new Set<String>(),
                        opptyAddressSet = new Set<String>(), opptyNameSet = new Set<String>(),
                        opptyStreetSet = new Set<String>(), opptyCitySet = new Set<String>(),
                        opptyStateSet = new Set<String>(), opptyZipSet = new Set<String>(),
                        repeatNameSet = new Set<String>();

    /* CONSTRUCTOR */
    public LinkOpptyToAccount(Opportunity[] oppList) {
        if (!oppList.isEmpty()) {
            opptyList = oppList;

            // First populate sets of field values from our Opportunities, with which to compare
            // to Contact info, to help us find existing Accounts to associate them to
            populateOpptySets(opptyList);

            if (!opptyNameSet.isEmpty()) {
                queryAccounts();
            }
        }
    }

    /* INSTANCE METHODS */
    private void populateOpptySets(Opportunity[] oList) {
        for (Opportunity o: oList) {
            // Make sure Opportunity doesn't already have an Account associated
            if (o.AccountId == null) {
                opptyNameSet.add(o.FullName__c);
                opptyNameSet.add(o.FullName__c + ' - Resident');
            }

            if (o.Phone_Number__c != null) opptyPhoneSet.add(o.Phone_Number__c);
            if (o.Email__c != null) opptyEmailSet.add(o.Email__c);
            if (o.Street_Address__c != null) opptyStreetSet.add(o.Street_Address__c);
            if (o.City__c != null) opptyCitySet.add(o.City__c);
            if (o.State__c != null) opptyStateSet.add(o.State__c);
            if (o.Zip_Code__c != null) opptyZipSet.add(o.Zip_Code__c);

            nameOpptyMap.put(o.FullName__c, o);
        }
    }

    /* Query Account object to find out if there are any existing Accounts to assign our Opportunities to */
    private void queryAccounts() {
        if (!opptyNameSet.isEmpty() && opptyNameSet != null && !opptyNameSet.isEmpty()) {
	        // Build a map from Account Names to the Account records to compare with Opportunity names next
            for (Account a: [SELECT Id,
                                    Name,
                                    Phone,
                                    BillingStreet,
                                    BillingCity,
                                    BillingPostalCode,
                                    BillingCountry,
                                    (SELECT Contact.Id,
                                            Contact.Name,
                                            Contact.Email,
                                            Contact.AccountId,
                                            Contact.Phone,
                                            Contact.MailingStreet,
                                            Contact.MailingCity,
                                            Contact.MailingState,
                                            Contact.MailingPostalCode
                                    FROM Account.Contacts
                                    WHERE Contact.Name != null
                                    AND ((Contact.Name in :opptyNameSet
                                       OR Contact.Email in :opptyEmailSet
                                       OR Contact.Phone in :opptyPhoneSet)
                                       OR (Contact.MailingStreet in :opptyStreetSet
                                       AND Contact.MailingCity in :opptyCitySet
                                       AND Contact.MailingState in :opptyStateSet
                                       AND Contact.MailingPostalCode in :opptyZipSet))),
                                    RecordTypeId
                            FROM Account
                            WHERE RecordTypeId in :ACCT_RT_LIST
                            AND Name in :opptyNameSet Limit 49999]) {
                if (a.Name != null && a.Name.split('-') != null && a.Name.split('-').size() > 0) {
                	// We have an info set and the Account is already in our Name map
                    if ((!opptyEmailSet.isEmpty() || !opptyPhoneSet.isEmpty() || !opptyAddressSet.isEmpty()) &&
                         acctNameMap.get(a.Name.split('-')[0].trim()) != null) {
                        if (a.Contacts != null && !a.Contacts.isEmpty()) { // If we have Contacts for comparison...
	                        // There is already an Account with the same name in our map, so check our related Contacts
	                        repeatNameSet.add(a.Name.split('-')[0].trim());
	                        duplicateAcctSet.add(a); // Add our dupe account
                    	}
                    }
                    acctNameMap.put(a.Name.split('-')[0].trim(), a);
                }
            }

            if (!acctNameMap.isEmpty()) {
                assignOpptysToExistingAccts(acctNameMap);
            }
            else {
                checkExistingContacts(opptyList);
            }
        }
    }

    private void assignOpptysToExistingAccts(Map<String,Account> accountNameMap) {
        Opportunity[] opptyNoAccountList = new List<Opportunity>();

        if (!accountNameMap.isEmpty()) {
            // Now assign Opportunities to our existing Accounts
            for (Opportunity o: opptyList) {
                if (o.FullName__c.trim() != null && o.FullName__c.trim().length() > 0 && accountNameMap.containsKey(o.FullName__c.trim())) {
                    // If there is more than one Account that matches an Opportunity...
                    if (repeatNameSet.contains(o.FullName__c.trim())) {
                        for (Account a: duplicateAcctSet) {
                            for (Contact c: a.Contacts) {
                                compareContactInfo(c, o);
                            }
                        }
                    }
                    else {
                    	Account tempAcc = accountNameMap.get(o.FullName__c.trim());
                        o.AccountId = tempAcc.Id;

                        // There is an existing Account, but no existing Contact, so lets create one
                        if (accountNameMap.get(o.FullName__c.trim()).Contacts == null || accountNameMap.get(o.FullName__c.trim()).Contacts.isEmpty()) {
                            Contact c = createContact(o, accountNameMap.get(o.FullName__c.trim()).Id);
                            if (c != null) contactList.add(c);
                        }
                    }
                }
                else {
                    // Track our Opportunities which did not have an Account to associate to
                    opptyNoAccountList.add(o);
                }
            }

            // Now insert any Contacts we may have needed to create for Accounts missing them
            if (!contactList.isEmpty()) {
                insertContacts();
            }

            if (!opptyNoAccountList.isEmpty()) {
                checkExistingContacts(opptyNoAccountList);
            }
        }
    }

    private void compareContactInfo(Contact c, Opportunity o) {
    	if (c != null && o != null) {
            // Name AND Address AND Email AND Phone match
            if (c.Name == o.FullName__c && c.MailingStreet == o.Street_Address__c && c.MailingCity == o.City__c &&
                   c.MailingState == o.State__c && c.MailingPostalCode == o.Zip_Code__c &&
                        c.Email == o.Email__c && c.Phone == o.Phone_Number__c) {
                o.AccountId = c.AccountId;
            }
            // Name AND Address match but Email or Phone do not
            else if (c.Name == o.FullName__c && c.MailingStreet == o.Street_Address__c && c.MailingCity == o.City__c &&
                   c.MailingState == o.State__c && c.MailingPostalCode == o.Zip_Code__c &&
                        (c.Email != o.Email__c || c.Phone != o.Phone_Number__c)) {
                o.AccountId = c.AccountId;
                updateInfo(c, o);
            }
            // Name AND (Email OR Phone) but Address doesn't match
            else if (c.Name == o.FullName__c && (c.Email == o.Email__c || c.Phone == o.Phone_Number__c) &&
                        (c.MailingStreet != o.Street_Address__c || c.MailingCity != o.City__c ||
                            c.MailingState != o.State__c || c.MailingPostalCode != o.Zip_Code__c)) {
                o.AccountId = c.AccountId;
                updateInfo(c, o);
	        }

            if (!updateContactList.isEmpty()) {
                updateContacts();
            }
        }
    }

    /* Method to update a Contact's Mailing Address, Email, or Phone if it differs from an otherwise matching Opportunity */
    private void updateInfo(Contact con, Opportunity opp) {
        if (con != null && opp != null) {
            if (con.MailingStreet != opp.Street_Address__c || con.MailingCity != opp.City__c || con.MailingState != opp.State__c ||
        	        con.MailingPostalCode != opp.Zip_Code__c) {
	            con.MailingStreet = opp.Street_Address__c;
	            con.MailingCity = opp.City__c;
	            con.MailingState = opp.State__c;
	            con.MailingPostalCode = opp.Zip_Code__c;
        	}

        	if (con.Email != opp.Email__c || con.Phone != opp.Phone_Number__c) {
        	    con.Email = opp.Email__c;
        	    con.Phone = opp.Phone_Number__c;
            }
            updateContactList.add(con);
        }
    }

    private void updateContacts() {
        if (!updateContactList.isEmpty()) {
            try {
                update updateContactList;
            } catch(DMLException de3) {
                  // Handle Insert exception
                  System.debug('$$$ DMLException updating existing Contacts de3: ' + de3);
            }
        }
    }

    private void checkExistingContacts(Opportunity[] opptList) {
        Opportunity[] opptyNoAcctList = new List<Opportunity>();
        Contact[] cntctList = new List<Contact>();

        if (opptList != null && !opptList.isEmpty()) {
            // Query existing Contacts to see if any match up with our new Opportunity
            cntctList = [SELECT Id,
                                Name,
                                Email,
                                Phone,
                                MailingStreet,
                                MailingCity,
                                MailingState,
                                MailingPostalCode,
                                AccountId
                         FROM Contact
                         WHERE Name != null
                         AND AccountId != null
                         AND (Name in :opptyNameSet
                           OR Email in :opptyEmailSet
                           OR Phone in :opptyPhoneSet
                           OR     (MailingStreet in :opptyStreetSet
                               AND MailingCity in :opptyCitySet
                               AND MailingState in :opptyStateSet
                               AND MailingPostalCode in :opptyZipSet))];
            if (!cntctList.isEmpty()) {
                for (Contact c: cntctList) {
                	// Check if there is a POSSIBLE matching Contact with an Account. If so, Associate our new Opportunity to this same Account.
                    if (nameOpptyMap != null && !nameOpptyMap.isEmpty() && nameOpptyMap.containsKey(c.Name) && opptyNameSet.contains(c.Name) &&
                        c.AccountId != null && (opptyEmailSet.contains(c.Email) || opptyPhoneSet.contains(c.Phone) ||
                        (opptyStreetSet.contains(c.MailingStreet) && opptyCitySet.contains(c.MailingCity) && opptyStateSet.contains(c.MailingState) &&
                        opptyZipSet.contains(c.MailingPostalCode)))) {
                        // nameOpptyMap.get(c.Name).AccountId = c.AccountId;
                        compareContactInfo(c, nameOpptyMap.get(c.Name));
                    }
                }
            }

            // Now populate a list of Opptys for which we still have no Account to link to
            for (Opportunity o: nameOpptyMap.values()) {
                if (o.AccountId == null) {
                    opptyNoAcctList.add(o);
                }
            }
        }

        // Create Accounts and Contacts for remaining Opportunities
        if (!opptList.isEmpty()) {
            assignOpptysToNewAccts(opptyNoAcctList);
        }
    }

    /* Creates new Accounts and Contacts for Opptys if none exist */
    private void assignOpptysToNewAccts(Opportunity[] oppList) {
        Map<String,Account> newAcctNameMap = new Map<String,Account>();
        Opportunity[] opptyListNew = new List<Opportunity>();

        // Insert new Accounts created for Opportunities without existing Accounts
        if (!oppList.isEmpty()) {
            for (Opportunity o: oppList) {
                // Create our new Accounts here
                Account a = new Account(Name=o.FullName__c + ' - ' + 'Resident', RecordTypeId=ACCT_RT_LIST[0]);

                a.BillingStreet = (o.Street_Address__c != null && o.Street_Address__c.length() > 0) ? o.Street_Address__c : null;
                a.BillingCity = (o.City__c != null && o.City__c.length() > 0) ? o.City__c : null;
                a.BillingState = (o.State__c != null && o.State__c.length() > 0) ? o.State__c : null;
                a.BillingPostalCode = (o.Zip_Code__c != null && o.Zip_Code__c.length() > 0) ? o.Zip_Code__c : null;
                a.Phone = (o.Phone_Number__c != null && o.Phone_Number__c.length() > 0) ? o.Phone_Number__c : null;

                newAcctNameMap.put(o.FullName__c.trim(), a);
                opptyListNew.add(o);

                // Create our new Contacts here, using Opportunity Name
                if (o.FullName__c != null && o.FullName__c.split(' ') != null && o.FullName__c.split(' ').size() >= 1) {
                    Contact c = createContact(o, null);
                    if (c != null) contactList.add(c);
                }
            }
        }

        if (!newAcctNameMap.isEmpty() && !opptyListNew.isEmpty()) {
            try {
                insert newAcctNameMap.values();
            } catch(DMLException de1) {
                  // Handle Insert exception
                  System.debug('$$$ DMLException inserting new Accounts de1: ' + de1);
              }

            // Assign Opportunities to Accounts, now that we have AccountIds
            for (Opportunity o: opptyListNew) {
                if (newAcctNameMap.keySet().contains(o.FullName__c.trim())) {
                    o.AccountId = newAcctNameMap.get(o.FullName__c.trim()).Id;
                }
            }

            // And assign Contacts to Accounts as well
            if (!contactList.isEmpty()) {
                for (Contact c: contactList) {
                    if (newAcctNameMap.keySet().contains(c.FirstName.trim() + ' ' + c.LastName.trim())) {
                        c.AccountId = newAcctNameMap.get(c.FirstName.trim() + ' ' + c.LastName.trim()).Id;
                    }
                }
                insertContacts();
            }
        }
    }

    private void insertContacts() {
        if (!contactList.isEmpty()) {
            try {
                Database.SaveResult[] saveResList = Database.insert(contactList);

            } catch(DMLException de2) {
                  // Handle Insert exception
                  System.debug('$$$ DMLException inserting new Contacts de2: ' + de2);
            }
        }
    }

    private Contact createContact(Opportunity o, Id acctId) {
        Contact c;

        if (o != null) {
            // Create our new Contacts here
            if (o.FullName__c.split(' ').size() == 1) {
                c = new Contact(LastName=o.FullName__c.split(' ')[0], Patron__c=true, AccountId=acctId, Related_Opportunity__c=o.Id);
                updateContactFields(c, o);
            }
            else if (o.FullName__c.split(' ').size() == 2) {
                c = new Contact(FirstName=o.FullName__c.split(' ')[0], LastName=o.FullName__c.split(' ')[1], Patron__c=true, AccountId=acctId, 
                                    Related_Opportunity__c=o.Id);
                updateContactFields(c, o);
            }
            else if (o.FullName__c.split(' ').size() == 3) {
                c = new Contact(FirstName=o.FullName__c.split(' ')[0], LastName=o.FullName__c.split(' ')[2], Patron__c=true, AccountId=acctId,
                                    Related_Opportunity__c=o.Id);
                updateContactFields(c, o);
            }
            else if (o.FullName__c.split(' ').size() > 3) {
                c = new Contact(FirstName=o.FullName__c.split(' ')[0], LastName=o.FullName__c.split(' ')[o.FullName__c.split(' ').size()-1],
                                    Patron__c=true, AccountId=acctId, Related_Opportunity__c=o.Id);
                updateContactFields(c, o);
            }
        }
        return c;
    }

    private void updateContactFields(Contact c, Opportunity opp) {
        if (c != null) {
            c.MailingStreet = (opp.Street_Address__c != null && opp.Street_Address__c.length() > 0) ? opp.Street_Address__c : null;
            c.MailingCity = (opp.City__c != null && opp.City__c.length() > 0) ? opp.City__c : null;
            c.MailingState = (opp.State__c != null && opp.State__c.length() > 0) ? opp.State__c : null;
            c.MailingPostalCode = (opp.Zip_Code__c != null && opp.Zip_Code__c.length() > 0) ? opp.Zip_Code__c : null;
            c.Email = (opp.Email__c != null && opp.Email__c.length() > 0) ? opp.Email__c : null;
            c.Phone = (opp.Phone_Number__c != null && opp.Phone_Number__c.length() > 0) ? opp.Phone_Number__c : null;
            c.Related_Opportunity__c = opp.FullName__c;
        }
    }
}