# GlobalGroupTravel

Back-end Apex et modèle de données Salesforce pour **GlobalGroupTravel (GGT)**, un fournisseur de voyages de groupe. Automatise la création des voyages depuis les opportunités gagnées, valide l'intégrité des dates, et gère le cycle de vie (annulation et statut) via deux batchs planifiés quotidiens.

> Projet 8 — Option B (cas fictif) du parcours Développeur Salesforce.

---

## Sommaire

- [Architecture](#architecture)
- [Règles métier](#règles-métier)
- [Modèle de données](#modèle-de-données)
- [Installation et déploiement](#installation-et-déploiement)
- [Activation des batchs planifiés](#activation-des-batchs-planifiés)
- [Tests](#tests)
- [Conventions de code](#conventions-de-code)
- [Structure du dépôt](#structure-du-dépôt)

---

## Architecture

| Couche | Composants |
|---|---|
| Métadonnée | 4 champs custom sur `Opportunity`, objet custom `Trip__c` + 8 champs |
| Triggers | `OpportunityTrigger`, `TripTrigger` (un trigger par objet, délégation à un handler) |
| Handlers | `OpportunityTriggerHandler`, `TripTriggerHandler` |
| Batchs | `TripCancelBatch`, `TripStatusBatch` (`Database.Batchable<SObject>`) |
| Schedulers | `TripCancelScheduler`, `TripStatusScheduler` (`Schedulable`, cron quotidien) |

Toutes les classes sont `with sharing`, bulkifiées (aucune SOQL/DML dans une boucle), et vérifient les permissions CRUD avant les DML.

---

## Règles métier

### GGT-01 — Modèle de données
Création de l'objet `Trip__c`, de ses champs et des 4 champs custom sur `Opportunity`.

### GGT-02 — Création automatique d'un Trip__c sur Closed Won
Lorsqu'une `Opportunity` passe au stage **Closed Won** (transition uniquement, pas chaque update), un `Trip__c` est créé et rattaché à l'`Account` de l'opportunité, avec le mapping suivant :

| Champ Trip__c | Source |
|---|---|
| `Status__c` | `'A venir'` (valeur par défaut) |
| `Destination__c` | `Opportunity.Destination__c` |
| `Start_Date__c` | `Opportunity.Start_Date__c` |
| `End_Date__c` | `Opportunity.End_Date__c` |
| `Number_of_Participants__c` | `Opportunity.Number_of_Participants__c` |
| `Total_Cost__c` | `Opportunity.Amount` |
| `Account__c` | `Opportunity.AccountId` |
| `Opportunity__c` | `Opportunity.Id` |

Une `Opportunity` Closed Won sans `Account` est ignorée silencieusement.

### GGT-03 — Validation de la cohérence des dates
À l'insert et l'update d'un `Trip__c`, si les deux dates sont renseignées et que `End_Date__c <= Start_Date__c`, l'enregistrement est bloqué avec le message :
> *La date de fin doit être postérieure à la date de début.*

Comparaison stricte (un voyage de durée 0 est invalide).

### GGT-04 — Annulation automatique (batch quotidien à 02:00)
Chaque jour, les `Trip__c` dont :
- `Start_Date__c` est exactement à **J+7**,
- `Status__c = 'A venir'`,
- `Number_of_Participants__c` est renseigné **et** strictement inférieur à **10**,

passent automatiquement à `Status__c = 'Annulé'`.

### GGT-05 — Mise à jour automatique du statut (batch quotidien à 03:00)
Chaque jour, le `Status__c` des `Trip__c` est recalculé selon les dates (les voyages déjà `Annulé` ou avec une date null sont ignorés) :

| Condition | Status__c |
|---|---|
| `today < Start_Date__c` | `A venir` |
| `Start_Date__c <= today <= End_Date__c` | `En cours` |
| `today > End_Date__c` | `Terminé` |

Optimisation : seuls les Trip__c dont le statut calculé diffère du statut courant sont mis à jour (aucune DML inutile).

---

## Modèle de données

### Champs custom sur Opportunity

| Champ | Type |
|---|---|
| `Number_of_Participants__c` | Number(18,0) |
| `Destination__c` | Text(255) |
| `Start_Date__c` | Date |
| `End_Date__c` | Date |

### Objet Trip__c

| Champ | Type | Notes |
|---|---|---|
| `Name` | AutoNumber `T-{0000}` | Auto-généré |
| `Status__c` | Picklist (restreinte) | A venir, En cours, Terminé, Annulé |
| `Destination__c` | Text(255) | |
| `Start_Date__c` | Date | |
| `End_Date__c` | Date | |
| `Number_of_Participants__c` | Number(18,0) | |
| `Total_Cost__c` | Currency(16,2) | |
| `Account__c` | Lookup → Account, requis | `Restrict` on delete |
| `Opportunity__c` | Lookup → Opportunity | `SetNull` on delete |

---

## Installation et déploiement

### Prérequis

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) installé
- Une org cible (Developer Edition, sandbox, scratch org…) authentifiée

### Authentification de l'org

```bash
sf org login web --alias ggt
```

### Déploiement complet

```bash
sf project deploy start --source-dir force-app/main/default --target-org ggt --wait 10
```

### Vérification

```bash
sf org display --target-org ggt
```

---

## Activation des batchs planifiés

Les classes `Schedulable` sont déployées mais le cron n'est créé qu'après exécution des scripts anonymes (une seule fois par org) :

```bash
sf apex run --target-org ggt --file scripts/apex/schedule-cancel-batch.apex
sf apex run --target-org ggt --file scripts/apex/schedule-status-batch.apex
```

Vérifier que les jobs sont planifiés :

```bash
sf data query --target-org ggt --query "SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE 'GGT-%'"
```

Pour annuler une planification :

```apex
System.abortJob('<jobId>');
```

---

## Tests

### Lancer toute la suite

```bash
sf apex run test --target-org ggt --code-coverage --result-format human --wait 10
```

### Résultats

| Classe testée | Couverture | Nombre de tests |
|---|---|---|
| `OpportunityTrigger` | 100 % | inclus ci-dessous |
| `OpportunityTriggerHandler` | 96 % | 6 |
| `TripTrigger` | 100 % | inclus ci-dessous |
| `TripTriggerHandler` | 100 % | 8 |
| `TripCancelBatch` | 93 % | inclus ci-dessous |
| `TripCancelScheduler` | 100 % | 9 (batch + scheduler) |
| `TripStatusBatch` | 96 % | inclus ci-dessous |
| `TripStatusScheduler` | 100 % | 9 (batch + scheduler) |
| **Couverture globale org** | **96 %** | **37 tests, 100 % pass** |

Chaque classe de test utilise `@testSetup` pour préparer les données et `Test.startTest()` / `Test.stopTest()` pour isoler les limites de gouverneur. Les batchs sont testés en exécution directe (`Database.executeBatch`) ; les schedulers sont vérifiés via la création d'un `CronTrigger`.

---

## Conventions de code

- Pattern **un trigger / un handler** par objet.
- `with sharing` sur toutes les classes.
- Aucune SOQL/DML dans une boucle (bulkification systématique).
- Vérifications CRUD via `Schema.sObjectType.<Object>.isCreateable()` / `isUpdateable()` avant les DML.
- **Aucun commentaire dans le code Apex** : les noms d'identifiants doivent être suffisamment explicites. Les `description` dans les XML metadata (visibles dans Setup) restent.
- Messages d'erreur en français.
- Branches feature isolées (`feature/GGT-XX-*`), commits préfixés `GGT-XX : …`, une PR par règle.

---

## Structure du dépôt

```
force-app/main/default/
├── classes/
│   ├── OpportunityTriggerHandler.cls
│   ├── OpportunityTriggerHandlerTest.cls
│   ├── TripTriggerHandler.cls
│   ├── TripTriggerHandlerTest.cls
│   ├── TripCancelBatch.cls
│   ├── TripCancelScheduler.cls
│   ├── TripCancelBatchTest.cls
│   ├── TripStatusBatch.cls
│   ├── TripStatusScheduler.cls
│   └── TripStatusBatchTest.cls
├── triggers/
│   ├── OpportunityTrigger.trigger
│   └── TripTrigger.trigger
└── objects/
    ├── Opportunity/fields/   (4 champs custom)
    └── Trip__c/              (objet + 8 champs)

scripts/apex/
├── schedule-cancel-batch.apex   (GGT-04 — 02:00)
└── schedule-status-batch.apex   (GGT-05 — 03:00)
```
