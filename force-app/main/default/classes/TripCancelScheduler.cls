public with sharing class TripCancelScheduler implements Schedulable {

    @TestVisible
    private static final Integer BATCH_SIZE = 200;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TripCancelBatch(), BATCH_SIZE);
    }
}
