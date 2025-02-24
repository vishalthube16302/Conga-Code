/**
====================================================================================================

  File Name     :     IRIS_AwardXMLGeneratorBatch
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This Batch class generates an XML file for Award records, processes the 
                      records in batches, and saves the generated XML file as an attachment.

  CHANGE HISTORY: 
      Vishal Thube :   Initial implementation to generate and save XML for Award records.
 
====================================================================================================
*/

global class IRIS_AwardXMLGeneratorBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Id recordId;
    global AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
    private IRIS_AwardXMLGenerator xmlGenerator = new IRIS_AwardXMLGenerator();

    // Constructor accepts an optional recordId
    global IRIS_AwardXMLGeneratorBatch(Id recordId) {
        this.recordId = recordId;
    }

    global IRIS_AwardXMLGeneratorBatch() {
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query;
        if (recordId != null) {
            query = 'SELECT Id, AL_xmlFileStatus__c, (SELECT Id FROM AwardFundingAccounts__r) ' +
                    'FROM Award__c WHERE Id = \'' + recordId + '\'';
        } else {
            query = 'SELECT Id, AL_xmlFileStatus__c, (SELECT Id FROM AwardFundingAccounts__r) ' +
                    'FROM Award__c WHERE AL_xmlFileStatus__c = \'Ready for Generate\' AND Status__c = \'Activated\'';
        }
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        IntegrationHeader__c iHeader = new IntegrationHeader__c();
        iHeader.Status__c = 'New';
        iHeader.Direction__c = 'From EGMS';
        iHeader.FileName__c = 'IRISFIN.CEDGMS.AWARD.' + Datetime.now().format('yyyyMMdd-HH-mm-ss');
        insert iHeader;

        List<Award__c> awardList = (List<Award__c>)scope;
        notifyDetails.totalRecords = awardList.size();
        try {
            xmlGenerator.processAwards(awardList, iHeader);

            iHeader.Status__c = 'Ready for Processing';
            update iHeader;

        } catch (Exception e) {
            String errorMessage = AWS_Utility.getErrorMessage(e);

            for (Award__c award : awardList) {
                if (award.AL_xmlFileStatus__c != 'Generated') {
                    award.AL_xmlFileStatus__c = 'Failed';
                    //award.AL_xmlFileLog__c = errorMessage;
                    notifyDetails.totalFailedRecords++;
                }
            }
            if (!awardList.isEmpty()) {
                update awardList;
            }

            iHeader.Status__c = 'Failed';
            iHeader.Log__c = errorMessage;
            update iHeader;

            notifyDetails.processingLog = 'XML File Generation batch has been failed: ' + errorMessage;
            AWS_Utility.sendEmail('XML File Generation batch has been failed', awardList, notifyDetails);
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Batch process completed.');
    }
}