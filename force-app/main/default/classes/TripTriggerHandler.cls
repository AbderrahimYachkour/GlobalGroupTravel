public with sharing class TripTriggerHandler {

    @TestVisible
    private static final String DATE_ERROR_MESSAGE = 'La date de fin doit être postérieure à la date de début.';

    public static void validateDates(List<Trip__c> newTrips) {
        for (Trip__c trip : newTrips) {
            if (trip.Start_Date__c != null
                && trip.End_Date__c != null
                && trip.End_Date__c <= trip.Start_Date__c) {
                trip.addError(DATE_ERROR_MESSAGE);
            }
        }
    }
}
