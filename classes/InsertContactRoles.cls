public with sharing class InsertContactRoles {
    Contact[] ctList = new List<Contact>();

    /* CONSTRUCTOR */
    public InsertContactRoles(Opportunity[] newOpptys) {
        Map<String,Id> oFullNameMap = new Map<String,Id>();
        OpportunityContactRole[] ocrList = new List<OpportunityContactRole>();

        if (newOpptys != null && !newOpptys.isEmpty()) {
            for (Opportunity o: newOpptys) {
                if (o.FullName__c != null) {
                    oFullNameMap.put(o.FullName__c, o.Id);
                 }
             }

             if (!oFullNameMap.isEmpty()) {
                 for (Contact c: [select Id,
                                         Name,
                                         FirstName,
                                         LastName,
                                         CreatedDate
                                  from Contact
                                  where Name in :oFullNameMap.keySet()
                                  and CreatedDate <= :System.today()+2]) {
                     if (c.Name != null && oFullNameMap.containsKey(c.Name)) {
                         ocrList.add(new OpportunityContactRole(ContactId=c.Id, OpportunityId=oFullNameMap.get(c.Name), Role='Decision Maker',
                                                                    isPrimary=true));
                     }
                 }

                 if (!ocrList.isEmpty()) {
                     try {
                         insert ocrList;
                     } catch(DMLException de) {
                           System.debug('$$$ InsertContactRoles insert DML exception: ' + de);
                     }
                 }
             }
        }
    }
}