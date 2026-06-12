@isTest
private class TripStatusBatchTest {

    private static final Date TODAY = Date.today();
    private static final String STATUS_UPCOMING = 'A venir';
    private static final String STATUS_IN_PROGRESS = 'En cours';
    private static final String STATUS_COMPLETED = 'Terminé';
    private static final String STATUS_CANCELLED = 'Annulé';

    @testSetup
    static void setupData() {
        insert new Account(Name = 'GGT Test Account');
    }

    private static Trip__c buildTrip(Id accountId, Date startDate, Date endDate, String status) {
        return new Trip__c(
            Account__c    = accountId,
            Start_Date__c = startDate,
            End_Date__c   = endDate,
            Status__c     = status
        );
    }

    @isTest
    static void tripWithStartInFutureBecomesUpcoming() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20), STATUS_COMPLETED);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c);
    }

    @isTest
    static void tripWithTodayInRangeBecomesInProgress() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(-5), TODAY.addDays(5), STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_IN_PROGRESS, reloaded.Status__c);
    }

    @isTest
    static void tripStartingTodayIsInProgress() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY, TODAY.addDays(5), STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_IN_PROGRESS, reloaded.Status__c, 'Borne basse incluse : today == Start');
    }

    @isTest
    static void tripEndingTodayIsInProgress() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(-5), TODAY, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_IN_PROGRESS, reloaded.Status__c, 'Borne haute incluse : today == End');
    }

    @isTest
    static void tripWithEndInPastBecomesCompleted() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(-20), TODAY.addDays(-10), STATUS_IN_PROGRESS);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_COMPLETED, reloaded.Status__c);
    }

    @isTest
    static void cancelledTripIsNotProcessed() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(-20), TODAY.addDays(-10), STATUS_CANCELLED);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_CANCELLED, reloaded.Status__c, 'Trip annulé exclu du batch (non réactivé)');
    }

    @isTest
    static void tripWithNullStartDateIsNotProcessed() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, null, TODAY.addDays(10), STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c, 'Date null exclue du SOQL');
    }

    @isTest
    static void tripAlreadyAtCorrectStatusIsNotUpdated() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20), STATUS_UPCOMING);
        insert trip;
        Datetime initialModified = [SELECT LastModifiedDate FROM Trip__c WHERE Id = :trip.Id].LastModifiedDate;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c, LastModifiedDate FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c);
        System.assertEquals(initialModified, reloaded.LastModifiedDate, 'Pas de DML si le status est déjà correct');
    }

    @isTest
    static void bulkProcessingUpdatesAllMismatchedTrips() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Trip__c> trips = new List<Trip__c>();
        for (Integer i = 0; i < 70; i++) {
            trips.add(buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20), STATUS_COMPLETED));
        }
        for (Integer i = 0; i < 70; i++) {
            trips.add(buildTrip(acc.Id, TODAY.addDays(-5), TODAY.addDays(5), STATUS_UPCOMING));
        }
        for (Integer i = 0; i < 60; i++) {
            trips.add(buildTrip(acc.Id, TODAY.addDays(-20), TODAY.addDays(-10), STATUS_IN_PROGRESS));
        }
        insert trips;

        Test.startTest();
        Database.executeBatch(new TripStatusBatch(), 200);
        Test.stopTest();

        Map<String, Integer> countByStatus = new Map<String, Integer>{
            STATUS_UPCOMING     => 0,
            STATUS_IN_PROGRESS  => 0,
            STATUS_COMPLETED    => 0
        };
        for (Trip__c t : [SELECT Status__c FROM Trip__c WHERE Id IN :trips]) {
            countByStatus.put(t.Status__c, countByStatus.get(t.Status__c) + 1);
        }
        System.assertEquals(70, countByStatus.get(STATUS_UPCOMING),    '70 trips futurs');
        System.assertEquals(70, countByStatus.get(STATUS_IN_PROGRESS), '70 trips en cours');
        System.assertEquals(60, countByStatus.get(STATUS_COMPLETED),   '60 trips terminés');
    }

    @isTest
    static void schedulerRegistersTheCronJob() {
        Test.startTest();
        String cronExp = '0 0 3 * * ?';
        String jobId = System.schedule('GGT-05 Test Schedule', cronExp, new TripStatusScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron quotidien à 3h enregistré');
    }
}
