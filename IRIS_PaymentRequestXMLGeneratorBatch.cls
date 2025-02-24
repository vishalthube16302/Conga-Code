/**
====================================================================================================

  File Name     :     IRIS_PaymentRequestXMLGeneratorBatch
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This Batch class generates an XML file for PaymentRequest records, processes the 
                      records in batches, and saves the generated XML file as an attachment.

  CHANGE HISTORY: 
      Vishal Thube :   Initial implementation to generate and save XML for PaymentRequest records.
 
====================================================================================================
*/

global class IRIS_PaymentRequestXMLGeneratorBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Id recordId;
    global AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
    private IRIS_PaymentRequestXMLGenerator xmlGenerator = new IRIS_PaymentRequestXMLGenerator();

    // Constructor accepts an optional recordId
    global IRIS_PaymentRequestXMLGeneratorBatch (Id recordId) {
        this.recordId = recordId;
    }

    global IRIS_PaymentRequestXMLGeneratorBatch () {
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query;
        if (recordId != null) {
            query = 'SELECT Id, AL_xmlFileStatus__c, (SELECT Id FROM AwardFundingAccounts__r) ' +
                    'FROM PaymentRequest__c WHERE Id = \'' +recordId + '\'';
        } else {
            query = 'SELECT Id, AL_xmlFileStatus__c, (SELECT Id FROM AwardFundingAccounts__r) ' +
                    'FROM PaymentRequest__c WHERE AL_xmlFileStatus__c = \'Ready for Generate\' AND Status__c = \'Approved\'';
        }
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
    
    
    IntegrationHeader__c iHeader = new IntegrationHeader__c();
        iHeader.Status__c = 'New';
        iHeader.Direction__c = 'From EGMS';
        iHeader.FileName__c = 'IRISFIN.CEDGMS.GRNTPYMT.' + Datetime.now().format('yyyyMMdd-HH-mm-ss');
    insert iHeader;
                
        List<PaymentRequest__c> payList = (List<PaymentRequest__c>)scope;
        notifyDetails.totalRecords = payList.size();
        try{    
            
            
            xmlGenerator.processPaymentRequests(payList, iHeader );
            
            iHeader.Status__c = 'Ready for Processing';
            
            Update iHeader;
            
            
        }catch (Exception e) {
            String errorMessage = AWS_Utility.getErrorMessage(e);

            for (PaymentRequest__c payReq: payList ) {
                if (payReq.AL_xmlFileStatus__c != 'Generated') {
                    payReq.AL_xmlFileStatus__c = 'Failed';
                    //payReq.AL_xmlFileLog__c= errorMessage;
                    notifyDetails.totalFailedRecords++;
                }
            }
            if (!payList.isEmpty()) {
                update payList ;
            }
            
            iHeader.Status__c = 'Failed';
            iHeader.Log__c = errorMessage;
            Update iHeader;

            notifyDetails.processingLog = 'XML File Generation batch has been failed' + errorMessage;
            AWS_Utility.sendEmail('XML File Generation batch has been failed', payList , notifyDetails);
          
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Batch process completed.');
    }
}