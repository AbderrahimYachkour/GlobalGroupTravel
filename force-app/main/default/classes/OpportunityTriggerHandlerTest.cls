@isTest
private class OpportunityTriggerHandlerTest {

    private static final String STAGE_PROSPECTING = 'Prospecting';
    private static final String STAGE_CLOSED_WON  = 'Closed Won';
    private static final String STAGE_CLOSED_LOST = 'Closed Lost';

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'GGT Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name                      = 'GGT Test Opp',
            StageName                 = STAGE_PROSPECTING,
            CloseDate                 = Date.today().addDays(30),
            AccountId                 = acc.Id,
            Amount                    = 15000,
            Destination__c            = 'Bali',
            Start_Date__c             = Date.today().addDays(30),
            End_Date__c               = Date.today().addDays(40),
            Number_of_Participants__c = 25
        );
        insert opp;
    }

    @isTest
    static void transitionToClosedWonCreatesTripWithCorrectMapping() {
        Opportunity opp = [
            SELECT Id, AccountId, Amount, Destination__c,
                   Start_Date__c, End_Date__c, Number_of_Participants__c
            FROM Opportunity
            LIMIT 1
        ];

        Test.startTest();
        opp.StageName = STAGE_CLOSED_WON;
        update opp;
        Test.stopTest();

        List<Trip__c> trips = [
            SELECT Id, Status__c, Destination__c, Start_Date__c, End_Date__c,
                   Number_of_Participants__c, Total_Cost__c, Account__c, Opportunity__c
            FROM Trip__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, trips.size(), 'Un Trip__c doit être créé sur la transition vers Closed Won');
        Trip__c t = trips[0];
        System.assertEquals('A venir',                       t.Status__c,                 'Status par défaut');
        System.assertEquals(opp.Destination__c,              t.Destination__c,            'Destination mappée');
        System.assertEquals(opp.Start_Date__c,               t.Start_Date__c,             'Start_Date mappée');
        System.assertEquals(opp.End_Date__c,                 t.End_Date__c,               'End_Date mappée');
        System.assertEquals(opp.Number_of_Participants__c,   t.Number_of_Participants__c, 'Participants mappés');
        System.assertEquals(opp.Amount,                      t.Total_Cost__c,             'Amount -> Total_Cost__c');
        System.assertEquals(opp.AccountId,                   t.Account__c,                'Account__c renseigné');
        System.assertEquals(opp.Id,                          t.Opportunity__c,            'Opportunity__c renseigné');
    }

    @isTest
    static void updateWithoutStageChangeDoesNotCreateTrip() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.Destination__c = 'Maldives';
        update opp;
        Test.stopTest();

        Integer tripCount = [SELECT COUNT() FROM Trip__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, tripCount, 'Aucun Trip__c sans transition de stage');
    }

    @isTest
    static void alreadyClosedWonDoesNotCreateDuplicate() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        opp.StageName = STAGE_CLOSED_WON;
        update opp;

        Test.startTest();
        opp.Destination__c = 'Maldives';
        update opp;
        Test.stopTest();

        Integer tripCount = [SELECT COUNT() FROM Trip__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, tripCount, 'Pas de doublon sur un update post-Closed Won');
    }

    @isTest
    static void bulkTransitionCreates200Trips() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name                      = 'Bulk Opp ' + i,
                StageName                 = STAGE_PROSPECTING,
                CloseDate                 = Date.today().addDays(30),
                AccountId                 = acc.Id,
                Amount                    = 10000,
                Destination__c            = 'Dest ' + i,
                Start_Date__c             = Date.today().addDays(30),
                End_Date__c               = Date.today().addDays(40),
                Number_of_Participants__c = 20
            ));
        }
        insert opps;

        for (Opportunity o : opps) {
            o.StageName = STAGE_CLOSED_WON;
        }

        Test.startTest();
        update opps;
        Test.stopTest();

        Integer tripCount = [SELECT COUNT() FROM Trip__c WHERE Opportunity__c IN :opps];
        System.assertEquals(200, tripCount, 'Bulk : 200 Trip__c créés en une seule DML');
    }

    @isTest
    static void closedLostDoesNotCreateTrip() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.StageName = STAGE_CLOSED_LOST;
        update opp;
        Test.stopTest();

        Integer tripCount = [SELECT COUNT() FROM Trip__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, tripCount, 'Closed Lost ne doit pas créer de Trip__c');
    }

    @isTest
    static void opportunityWithoutAccountIsSkipped() {
        Opportunity opp = new Opportunity(
            Name                      = 'No Account Opp',
            StageName                 = STAGE_PROSPECTING,
            CloseDate                 = Date.today().addDays(30),
            Amount                    = 5000,
            Destination__c            = 'Rome',
            Start_Date__c             = Date.today().addDays(30),
            End_Date__c               = Date.today().addDays(35),
            Number_of_Participants__c = 10
        );
        insert opp;

        Test.startTest();
        opp.StageName = STAGE_CLOSED_WON;
        update opp;
        Test.stopTest();

        Integer tripCount = [SELECT COUNT() FROM Trip__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, tripCount, 'Sans Account, aucun Trip__c ne doit être créé (skip silencieux)');
    }
}
