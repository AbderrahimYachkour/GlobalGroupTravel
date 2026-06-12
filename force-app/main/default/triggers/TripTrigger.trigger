trigger TripTrigger on Trip__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        TripTriggerHandler.validateDates(Trigger.new);
    }
}
