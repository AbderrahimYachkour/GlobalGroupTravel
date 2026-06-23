@isTest
private class TripTriggerHandlerTest {

    private static final Date TODAY = Date.today();

    @testSetup
    static void setupData() {
        insert new Account(Name = 'GGT Test Account');
    }

    private static Trip__c buildTrip(Id accountId, Date startDate, Date endDate) {
        return new Trip__c(
            Account__c    = accountId,
            Status__c     = 'A venir',
            Start_Date__c = startDate,
            End_Date__c   = endDate
        );
    }

    @isTest
    static void insertWithEndAfterStartSucceeds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20));

        Test.startTest();
        Database.SaveResult result = Database.insert(trip, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Insert avec End > Start doit réussir');
    }

    @isTest
    static void insertWithEndBeforeStartFails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(20), TODAY.addDays(10));

        Test.startTest();
        Database.SaveResult result = Database.insert(trip, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Insert avec End < Start doit échouer');
        System.assertEquals(1, result.getErrors().size(), 'Une seule erreur attendue');
        System.assert(
            result.getErrors()[0].getMessage().contains('postérieure'),
            'Le message d\'erreur doit mentionner la postériorité de la date de fin'
        );
    }

    @isTest
    static void insertWithEndEqualsStartFails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(10));

        Test.startTest();
        Database.SaveResult result = Database.insert(trip, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'End == Start doit échouer (comparaison stricte)');
    }

    @isTest
    static void updateMakingDatesInvalidFails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20));
        insert trip;

        trip.End_Date__c = TODAY.addDays(5);

        Test.startTest();
        Database.SaveResult result = Database.update(trip, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'Update rendant les dates invalides doit échouer');
    }

    @isTest
    static void updateKeepingDatesValidSucceeds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Trip__c trip = buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20));
        insert trip;

        trip.End_Date__c = TODAY.addDays(25);

        Test.startTest();
        Database.SaveResult result = Database.update(trip, false);
        Test.stopTest();

        System.assert(result.isSuccess(), 'Update gardant des dates valides doit réussir');
    }

    @isTest
    static void bulkMixedInsertOnlyInvalidsAreBlocked() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Trip__c> trips = new List<Trip__c>();
        for (Integer i = 0; i < 100; i++) {
            trips.add(buildTrip(acc.Id, TODAY.addDays(10), TODAY.addDays(20)));
        }
        for (Integer i = 0; i < 100; i++) {
            trips.add(buildTrip(acc.Id, TODAY.addDays(20), TODAY.addDays(10)));
        }

        Test.startTest();
        Database.SaveResult[] results = Database.insert(trips, false);
        Test.stopTest();

        Integer successCount = 0;
        Integer failCount = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }
        System.assertEquals(100, successCount, '100 inserts valides doivent réussir');
        System.assertEquals(100, failCount, '100 inserts invalides doivent échouer');
    }
}
