public with sharing class TripStatusBatch implements Database.Batchable<SObject> {

    @TestVisible
    private static final String STATUS_UPCOMING = 'A venir';

    @TestVisible
    private static final String STATUS_IN_PROGRESS = 'En cours';

    @TestVisible
    private static final String STATUS_COMPLETED = 'Terminé';

    @TestVisible
    private static final String STATUS_CANCELLED = 'Annulé';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Status__c, Start_Date__c, End_Date__c
            FROM Trip__c
            WHERE Status__c != :STATUS_CANCELLED
              AND Start_Date__c != null
              AND End_Date__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Trip__c> scope) {
        Date today = Date.today();
        List<Trip__c> tripsToUpdate = new List<Trip__c>();

        for (Trip__c trip : scope) {
            String expectedStatus = computeStatus(today, trip.Start_Date__c, trip.End_Date__c);
            if (trip.Status__c != expectedStatus) {
                trip.Status__c = expectedStatus;
                tripsToUpdate.add(trip);
            }
        }

        if (tripsToUpdate.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Trip__c.isUpdateable()) {
            return;
        }
        update tripsToUpdate;
    }

    public void finish(Database.BatchableContext bc) {
    }

    @TestVisible
    private static String computeStatus(Date today, Date startDate, Date endDate) {
        if (today < startDate) {
            return STATUS_UPCOMING;
        }
        if (today > endDate) {
            return STATUS_COMPLETED;
        }
        return STATUS_IN_PROGRESS;
    }
}
