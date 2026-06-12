@isTest
private class TripCancelBatchTest {

    private static final Date TODAY = Date.today();
    private static final Date TARGET_DATE = TODAY.addDays(7);
    private static final String STATUS_UPCOMING = 'A venir';
    private static final String STATUS_CANCELLED = 'Annulé';

    @testSetup
    static void setupData() {
        insert new Account(Name = 'GGT Test Account');
    }

    private static Trip__c buildTrip(Id accountId, Date startDate, Integer participants, String status) {
        return new Trip__c(
            Account__c                = accountId,
            Start_Date__c             = startDate,
            End_Date__c               = startDate.addDays(5),
            Status__c                 = status,
            Number_of_Participants__c = participants
        );
    }

    @isTest
    static void tripAtSevenDaysWithFewParticipantsIsCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TARGET_DATE, 9, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_CANCELLED, reloaded.Status__c, '9 < 10 doit être annulé à J+7');
    }

    @isTest
    static void tripAtSevenDaysWithTenParticipantsIsNotCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TARGET_DATE, 10, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c, 'Seuil strict <10, 10 ne doit pas être annulé');
    }

    @isTest
    static void tripAtSevenDaysWithZeroParticipantsIsCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TARGET_DATE, 0, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_CANCELLED, reloaded.Status__c);
    }

    @isTest
    static void tripAtSevenDaysWithNullParticipantsIsNotCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TARGET_DATE, null, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c, 'Participants null = exclusion explicite (spec)');
    }

    @isTest
    static void tripAtSixDaysIsNotCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(6), 5, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c, 'J+6 hors fenêtre cible');
    }

    @isTest
    static void tripAtEightDaysIsNotCancelled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(8), 5, STATUS_UPCOMING);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_UPCOMING, reloaded.Status__c, 'J+8 hors fenêtre cible');
    }

    @isTest
    static void alreadyCancelledTripIsNotReprocessed() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TARGET_DATE, 5, STATUS_CANCELLED);
        insert trip;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Trip__c reloaded = [SELECT Status__c FROM Trip__c WHERE Id = :trip.Id];
        System.assertEquals(STATUS_CANCELLED, reloaded.Status__c);
    }

    @isTest
    static void bulkCancellationOnSingleChunk() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Trip__c> trips = new List<Trip__c>();
        for (Integer i = 0; i < 200; i++) {
            trips.add(buildTrip(acc.Id, TARGET_DATE, 5, STATUS_UPCOMING));
        }
        insert trips;

        Test.startTest();
        Database.executeBatch(new TripCancelBatch(), 200);
        Test.stopTest();

        Integer cancelledCount = [
            SELECT COUNT()
            FROM Trip__c
            WHERE Status__c = :STATUS_CANCELLED AND Id IN :trips
        ];
        System.assertEquals(200, cancelledCount, '200 trips annulés en un seul chunk (limite de test Apex : 1 chunk max)');
    }

    @isTest
    static void schedulerRegistersTheCronJob() {
        Test.startTest();
        String cronExp = '0 0 2 * * ?';
        String jobId = System.schedule('GGT-04 Test Schedule', cronExp, new TripCancelScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron quotidien à 2h enregistré');
    }
}
