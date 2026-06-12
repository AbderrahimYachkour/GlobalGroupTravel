public with sharing class TripCancelBatch implements Database.Batchable<SObject> {

    @TestVisible
    private static final Integer MIN_PARTICIPANTS = 10;

    @TestVisible
    private static final Integer DAYS_BEFORE_START = 7;

    @TestVisible
    private static final String STATUS_UPCOMING = 'A venir';

    @TestVisible
    private static final String STATUS_CANCELLED = 'Annulé';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date targetDate = Date.today().addDays(DAYS_BEFORE_START);
        return Database.getQueryLocator([
            SELECT Id, Status__c
            FROM Trip__c
            WHERE Start_Date__c = :targetDate
              AND Status__c = :STATUS_UPCOMING
              AND Number_of_Participants__c != null
              AND Number_of_Participants__c < :MIN_PARTICIPANTS
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Trip__c> scope) {
        if (!Schema.sObjectType.Trip__c.isUpdateable()) {
            return;
        }
        for (Trip__c trip : scope) {
            trip.Status__c = STATUS_CANCELLED;
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
    }
}
