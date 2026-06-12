public with sharing class OpportunityTriggerHandler {

    @TestVisible
    private static final String CLOSED_WON_STAGE = 'Closed Won';

    @TestVisible
    private static final String TRIP_DEFAULT_STATUS = 'A venir';

    public static void handleAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        List<Trip__c> tripsToInsert = new List<Trip__c>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (isJustClosedWon(opp, oldOpp) && opp.AccountId != null) {
                tripsToInsert.add(buildTripFromOpportunity(opp));
            }
        }

        if (tripsToInsert.isEmpty()) {
            return;
        }

        if (!Schema.sObjectType.Trip__c.isCreateable()) {
            return;
        }

        insert tripsToInsert;
    }

    private static Boolean isJustClosedWon(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.StageName == CLOSED_WON_STAGE
            && oldOpp.StageName != CLOSED_WON_STAGE;
    }

    private static Trip__c buildTripFromOpportunity(Opportunity opp) {
        return new Trip__c(
            Status__c                  = TRIP_DEFAULT_STATUS,
            Destination__c             = opp.Destination__c,
            Start_Date__c              = opp.Start_Date__c,
            End_Date__c                = opp.End_Date__c,
            Number_of_Participants__c  = opp.Number_of_Participants__c,
            Total_Cost__c              = opp.Amount,
            Account__c                 = opp.AccountId,
            Opportunity__c             = opp.Id
        );
    }
}
