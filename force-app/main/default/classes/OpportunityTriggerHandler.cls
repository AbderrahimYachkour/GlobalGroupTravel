/**
 * Handler du trigger Opportunity.
 *
 * Règle GGT-02 : quand une Opportunity passe au stage "Closed Won",
 * un Trip__c est automatiquement créé et rattaché à l'Account de l'opportunité.
 *
 * Bonnes pratiques appliquées :
 *  - Pattern un trigger / un handler.
 *  - Bulkification : aucune SOQL/DML dans une boucle, un seul insert pour tous les voyages.
 *  - Sécurité : with sharing + vérification CRUD sur Trip__c.
 *  - Détection de la transition (et non du simple état) pour éviter les doublons.
 */
public with sharing class OpportunityTriggerHandler {

    @TestVisible
    private static final String CLOSED_WON_STAGE = 'Closed Won';

    @TestVisible
    private static final String TRIP_DEFAULT_STATUS = 'A venir';

    /**
     * Point d'entrée appelé en after update.
     * Crée un Trip__c pour chaque opportunité qui vient juste de passer en Closed Won
     * et qui possède un Account rattaché.
     *
     * @param newOpps Liste Trigger.new
     * @param oldMap  Map Trigger.oldMap pour comparer l'état avant/après
     */
    public static void handleAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        List<Trip__c> tripsToInsert = new List<Trip__c>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            // Création uniquement sur la transition vers Closed Won, et si un Account est lié
            // (Account__c est requis sur Trip__c, on skip silencieusement sinon).
            if (isJustClosedWon(opp, oldOpp) && opp.AccountId != null) {
                tripsToInsert.add(buildTripFromOpportunity(opp));
            }
        }

        if (tripsToInsert.isEmpty()) {
            return;
        }

        // Vérification CRUD : on ne tente l'insert que si l'utilisateur courant a le droit de créer des Trip__c.
        if (!Schema.sObjectType.Trip__c.isCreateable()) {
            return;
        }

        insert tripsToInsert;
    }

    /**
     * Détecte la transition vers Closed Won : nouvel état "Closed Won" ET ancien état différent.
     */
    private static Boolean isJustClosedWon(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.StageName == CLOSED_WON_STAGE
            && oldOpp.StageName != CLOSED_WON_STAGE;
    }

    /**
     * Construit un Trip__c à partir du mapping spécifié par GGT-02.
     * Trip Name est laissé vide : il est auto-généré (AutoNumber "T-{0000}").
     */
    private static Trip__c buildTripFromOpportunity(Opportunity opp) {
        return new Trip__c(
            Status__c                  = TRIP_DEFAULT_STATUS,
            Destination__c             = opp.Destination__c,
            Start_Date__c              = opp.Start_Date__c,
            End_Date__c                = opp.End_Date__c,
            Number_of_Participants__c  = opp.Number_of_Participants__c,
            Total_Cost__c              = opp.Amount,
            Account__c                 = opp.AccountId,
            Opportunity__c             = opp.Id
        );
    }
}
