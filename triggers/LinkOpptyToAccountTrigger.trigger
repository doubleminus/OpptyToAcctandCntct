trigger LinkOpptyToAccountTrigger on Opportunity (before insert, after insert) {

    if (trigger.isInsert) {
        if (trigger.isBefore) {
            if (Opportunity_Link_Active__c.getInstance('Link Opportunities to Accounts') != null &&
                    Opportunity_Link_Active__c.getInstance('Link Opportunities to Accounts').Active__c) {
                LinkOpptyToAccount lOTA = new LinkOpptyToAccount(Trigger.New);
            }
        }
        
        if (trigger.isAfter) {
            InsertContactRoles icr = new InsertContactRoles(Trigger.New);
        }
    }
}