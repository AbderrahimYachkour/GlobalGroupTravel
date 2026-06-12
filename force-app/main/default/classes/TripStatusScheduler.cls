public with sharing class TripStatusScheduler implements Schedulable {

    @TestVisible
    private static final Integer BATCH_SIZE = 200;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TripStatusBatch(), BATCH_SIZE);
    }
}
